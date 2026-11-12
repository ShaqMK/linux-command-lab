# 07 · Data Validation & ETL Pipelines

> **Level:** Advanced · **Sections:** §28–§33
>
> Turning the lab into a small data pipeline: appending test rows, finding duplicates and out-of-range values with `awk`, `if`/`[[ ]]` conditionals and file tests, then two complete pipeline scripts. One stops at the first bad file; the other sets bad rows aside and reports them. Ends with habits for working safely at the prompt.

[← Scripts, Functions, Logging & Exit Codes](06-scripts-functions-and-exit-codes.md) · [🏠 Home](../README.md) · [Error Log →](../reference/error-log.md)

---

## Contents

- **§28** — [Appending Rows with Heredocs (`cat << 'EOF' >> file`)](#28-appending-rows-with-heredocs)
- **§29** — [Data Quality Checks with `awk` (duplicates, ranges, wrong fields)](#29-data-quality-checks-with-awk)
- **§30** — [Conditionals and File Tests (`if`, `[[ -f ]]`, `check_file`, `check_data.sh`)](#30-conditionals-and-file-tests)
- **§31** — [Anatomy of an ETL Pipeline (`etl_pipeline.sh`)](#31-anatomy-of-an-etl-pipeline)
- **§32** — [Validate and Quarantine Bad Rows (`payments_pipeline.sh`)](#32-validate-and-quarantine-bad-rows)
- **§33** — [Working Safely at the Prompt (Tab, pasting, `set -e`)](#33-working-safely-at-the-prompt)

The finished scripts are in [`reference/scripts/`](../reference/scripts/).

---

## 28. Appending Rows with Heredocs

### ❌ Attempt 1: a filename *and* a heredoc

```bash
cat data/raw/students.csv << 'EOF'
5, Rose, Data Engineering, 30
...
EOF
```

**What happened:** it printed the existing file and **added nothing**.

**Why:** the heredoc feeds **stdin**. `cat` reads stdin only when it gets **no filename** (or the filename `-`). Here it was given `data/raw/students.csv`, so it printed that file and ignored stdin. Nothing was redirected either, so nothing was written.

### ✅ Attempt 2: no filename for `cat`, append with `>>`

```bash
cat << 'EOF' >> data/raw/students.csv
5, Rose, Data Engineering, 30
6, Mike, Data Science, 30
7, David, Data Engineering, 27
8, Harriet, Data Science, 32
9, Mary, Data Engineering, 29
10, John, Data Science, 27
EOF
```

| Part | Role |
|---|---|
| `cat` (no file) | Reads stdin, which is the heredoc |
| `<< 'EOF'` | The rows typed below, up to the line `EOF` |
| `>> data/raw/students.csv` | **Append** `cat`'s output to the file. A single `>` would replace the whole file, header included. |

Another attempt in the session was cancelled with `Ctrl+C` after a row with a leading space (` 6, Mike…`). **Cancelling a heredoc writes nothing**: bash collects the whole heredoc first and runs `cat` only after the closing `EOF`. `Ctrl+C` before then aborts the entire command.

> 📝 The appended rows are deliberate test data for the checks in §29: duplicate names (Mike, Mary, John) and later an out-of-range age (`11, Imani, Data Engineering, 90`).

Always check the result: `cat -n data/raw/students.csv` (line numbers show accidental double appends, [§4](../intermediate/01-files-and-directories.md#4-reading-files)).

---

## 29. Data Quality Checks with `awk`

### Finding duplicates: the `seen[key]++` idiom

```bash
awk -F', ' 'NR > 1 { if (seen[$2]++) print "DuplicateID found: " $1 " (Name: " $2 ")" }' data/raw/students.csv
```

```
DuplicateID found: 6 (Name: Mike)
DuplicateID found: 9 (Name: Mary)
DuplicateID found: 10 (Name: John)
```

| Part | Meaning |
|---|---|
| `seen[$2]` | An array entry keyed by the name. It starts empty (0). |
| `seen[$2]++` | **Post-increment**: returns the *old* value, then adds 1. The first time a name appears it returns `0` (false); every later time it returns 1, 2, … (true). |
| `if (seen[$2]++)` | True only from the **second** occurrence onwards, so the first row is never reported. |

How it plays out for `Mike`:

| Row | `seen["Mike"]` before | Returned | Printed? |
|---|---|---|---|
| 3, Mike | 0 | 0 (false) | no |
| 6, Mike | 1 | 1 (true) | ✅ yes |

Related one-liners:

```bash
awk '!seen[$0]++' file                       # remove duplicate lines, keep the first, keep the order
awk -F', ' 'NR>1 && seen[$1]++' file         # duplicate IDs (the primary key)
awk -F', ' 'NR>1 {c[$2]++} END {for (n in c) if (c[n]>1) print n, c[n]}' file   # names with counts
```

> ⚠️ **Choose the right key.** The message says "DuplicateID", but the key is `$2`, the **name**. Two different people can share a name: Mary (id 2, age 25) and Mary (id 9, age 29) are probably different students. Mike (3) and Mike (6) match on name, course *and* age (`Data Science, 30`), so that pair is the likely real duplicate. Check the **ID** for primary-key duplicates. To find the same person entered twice, use every column except the ID:
> ```bash
> awk -F', ' 'NR>1 { key = $2 FS $3 FS $4; if (seen[key]++) print "Possible duplicate: id " $1 " (" key ")" }' data/raw/students.csv
> # Possible duplicate: id 6 (Mike, Data Science, 30)
> ```

### Range checks: `||` vs `&&`

```bash
awk -F',' 'NR > 1 {
  if ($4 < 18 || $4 > 60) {
    print "Out of range age: " $2 " -> " $4
  }
}' data/raw/students.csv
# Out of range age:  Imani ->  90
```

| Want | Condition |
|---|---|
| Value **outside** a range (invalid) | `x < low \|\| x > high` |
| Value **inside** a range (valid) | `x >= low && x <= high` |

Changing `||` to `&&` (as was tried on the payments check) makes the condition **impossible**: no number is below 0 *and* above 50000 at the same time. The output goes quiet, which looks like "no problems", but the check can never fire.

The double spaces in `Imani ->  90` are the leading spaces left by `-F','` on a `", "` file ([§11](03-text-processing.md#11-separators--delimiters)). Use `-F'[[:space:]]*,[[:space:]]*'` or trim the fields first.

### ❌ Wrong field number: every row "invalid"

```bash
awk -F',' 'NR > 1 { if ($4 < 0 || $4 > 50000) { print "Invalid amount: " $2 " -> " $4 } }' data/raw/payments.csv
```

```
Invalid amount:  ST01 ->
Invalid amount:  ST02 ->
...                          (all 7 rows, with an empty amount)
```

**Why:** `payments.csv` has **3** columns, so the amount is `$3`. `$4` doesn't exist, and awk **doesn't report an error** for a missing field. It quietly returns an empty string `""`. Comparing `"" < 0` falls back to a **string comparison**, `"" < "0"`, which is true, so every row matched. The empty `->` at the end of each line was the clue.

**Fix:**

```bash
awk -F'[[:space:]]*,[[:space:]]*' 'NR > 1 && ($3 < 0 || $3 > 50000) { print "Invalid amount: " $1 " -> " $3 }' data/raw/payments.csv
# Invalid amount: PO5 -> 150000
# Invalid amount: P07 -> -17000
```

> 💡 Check the column count before writing field numbers: `head -1 file` or `count_columns file` ([§24](06-scripts-functions-and-exit-codes.md#24-shell-functions)).

### ❌ Two typos that broke the awk command

```bash
awk - F',' 'NR > 1 {
if ($4 < 18 || $4 > 60) {
    print "Out of range age: ' $2 ' -> '$4'"
}
}' data/raw/students.csv
```

```
awk: cmd. line:2: -
awk: cmd. line:2:  ^ unexpected newline or end of string
```

| Bug | What awk received | Fix |
|---|---|---|
| `- F','` (space after the dash) | Two words, `-` and `F,`. A lone `-` isn't the `-F` option, so awk took `-` as **its program**: a minus sign with nothing after it. | `-F','`, with no space ([§8](../intermediate/02-command-anatomy-and-io.md#8-short-and-long-flags)) |
| `'...: ' $2 ' -> '$4'"'` | Each inner `'` **closes** the awk program. `$2` and `$4` were then expanded by **bash** (empty at the prompt), and the program was cut into pieces. | Inside a single-quoted awk program use only `"` and concatenate: `"Out of range age: " $2 " -> " $4` |

Rule: the whole awk program is **one** single-quoted string. It can't contain a `'`. Use `"` for awk strings. If you need a shell value inside awk, pass it in with `-v` ([§32](#32-validate-and-quarantine-bad-rows)).

---

## 30. Conditionals and File Tests

### `if` syntax

```bash
if COMMAND; then
  ...            # runs when COMMAND exits with 0
elif OTHER; then
  ...
else
  ...
fi               # "if" backwards: closes the block
```

`if` doesn't evaluate true/false values. It runs a **command** and checks its **exit code** ([§26](06-scripts-functions-and-exit-codes.md#26-exit-status--error-codes)). `[[ ... ]]` is just a command that exits 0 when its test is true.

### File and string tests

| Test | True when |
|---|---|
| `[[ -e path ]]` | path **e**xists (any type) |
| `[[ -f path ]]` | it's a regular **f**ile |
| `[[ -d path ]]` | it's a **d**irectory |
| `[[ -s path ]]` | it exists and its **s**ize is > 0 (not empty) |
| `[[ -r / -w / -x path ]]` | you can **r**ead / **w**rite / e**x**ecute it |
| `[[ -z "$var" ]]` | the string is empty (**z**ero length) |
| `[[ -n "$var" ]]` | the string is **n**ot empty |
| `[[ "$a" == "$b" ]]` / `!=` | strings are equal / differ |
| `[[ $n -lt 18 ]]` | numeric comparison: `-eq -ne -lt -le -gt -ge` |
| `[[ ! ... ]]` | negation |

### The `check_file` function

```bash
check_file() {
  local file="$1"
  if [[ -f "$file" ]]; then
    return 0
  else
    return 1
  fi
}

if check_file data/raw/students.csv; then
  echo "file exists"
else
  echo "File does not exist"
fi
# file exists
```

The function sets an exit code with `return`, and the calling `if` tests it. A function's exit code is that of its last command, so the whole body can be shortened to `[[ -f "$1" ]]`.

### ❌ The one-liners: `syntax error near unexpected token 'then'`

Four one-line attempts all failed with the same error:

```bash
check_file(){ local file="$1" if [[ -f "$file" ]]; then return 0; else return 1; fi; }
# -bash: syntax error near unexpected token `then'
```

The **only** missing `;` is after `local file="$1"`. Without it, `if` and `[[ -f "$file" ]]` become arguments to `local`, just like `echo` did in [§27](06-scripts-functions-and-exit-codes.md#27-case-study-debugging-the-log-function) attempt 4. When bash reaches `then`, no `if` is open, so `then` is "unexpected".

The working one-liner has a `;` after **every** command, and after `fi`:

```bash
check_file(){ local file="$1"; if [[ -f "$file" ]]; then return 0; else return 1; fi; }
```

The other attempts also had `else return 1 fi}` (missing `;` before `fi`, and `fi}` glued together). Fixing only that wouldn't have helped while the first `;` was still missing. Bash reports the **first** error it hits.

> 💡 In the session the long one-liners wrapped onto the next screen line (`th` / `en`). That's only how the terminal displays a long line; the command is still one line. Use multi-line form for anything with `if`. It's easier to read, and the newlines replace most `;`s.

### `scripts/check_data.sh`: a script that sets an exit code

```bash
cat > scripts/check_data.sh << 'EOF'
#!/usr/bin/env bash

if [[ ! -f data/raw/students.csv ]]; then
  echo "ERROR: Students dataset missing" >&2
  exit 1
fi

echo "Dataset available"
exit 0
EOF
chmod 755 scripts/check_data.sh
./scripts/check_data.sh && echo "safe to continue"
```

| Session mistake | Result |
|---|---|
| `cat > script/check_data.sh` | `No such file or directory`: the folder is `scripts/`. `>` creates **files**, never missing directories ([§2](../intermediate/01-files-and-directories.md#2-creating-empty-files-touch)). |
| `if [[ ... ]] then` (no `;`) | Works in bash by luck: `[[ ]]` is a bash keyword, so `then` can follow it directly. With `[ ... ] then` (the `test` command) it's a syntax error, because `then` becomes an argument to `[`. **Always write `; then`.** |
| Error message to stdout | Better on stderr: `echo "ERROR: ..." >&2` ([§25](06-scripts-functions-and-exit-codes.md#25-a-reusable-log-function)). |

---

## 31. Anatomy of an ETL Pipeline

**ETL** = **E**xtract (read raw data) → **T**ransform (clean and validate) → **L**oad (write the cleaned output). [`etl_pipeline.sh`](../reference/scripts/etl_pipeline.sh) does this for both CSVs in nine steps. The building blocks are worth learning one by one.

### Setup: run from anywhere, fail fast

```bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p "$PROCESSED_DIR" "$REPORT_DIR" "$LOG_DIR" "$BACKUP_DIR"
```

| Line | Meaning |
|---|---|
| `set -euo pipefail` | Exit on any failing command, any unset variable, or any failing part of a pipeline ([§26](06-scripts-functions-and-exit-codes.md#26-exit-status--error-codes)). |
| `$0` | The path used to run the script, e.g. `./scripts/etl_pipeline.sh`. |
| `dirname "$0"` | Its folder: `./scripts`. |
| `cd "$(dirname "$0")/.."` | Go to the folder **above** the script, which is the project root. Relative paths like `data/raw` then work wherever you start the script from. |

### Steps 1–3: validate before touching anything

```bash
for file in "$RAW_DIR/students.csv" "$RAW_DIR/payments.csv"
do
    if [[ ! -s "$file" ]]; then
        log ERROR "Missing or empty file: $file"
        exit 1
    fi
done

if ! awk -F',' 'NF != 4 {bad=1} END {exit bad}' "$file"; then ...

students_header=$(head -n 1 "$RAW_DIR/students.csv" | tr -d '[:space:]')
```

| Piece | Meaning |
|---|---|
| `for file in A B; do ... done` | Run the body once per item, with `$file` set to each in turn. |
| `[[ ! -s "$file" ]]` | Missing **or** empty ([§30](#30-conditionals-and-file-tests)). |
| `awk '... {bad=1} END {exit bad}'` | **awk as a validator.** awk's `exit N` becomes its exit code. Uninitialised `bad` is 0 (pass); any bad line sets it to 1 (fail), so `if !` can test it. |
| `tr -d '[:space:]'` | **tr**anslate/**d**elete every whitespace character, so `student_id, name, course, age` becomes `student_id,name,course,age` and the header comparison ignores spacing. |

### Steps 4–5: back up, and get a private scratch folder

```bash
tar -czf "$BACKUP_DIR/raw_$(date +%Y%m%d_%H%M%S).tar.gz" "$RAW_DIR"

TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/etl.XXXXXX")
trap 'rm -rf "$TMP_DIR"' EXIT
```

| Piece | Meaning |
|---|---|
| `mktemp -d` | Create a new, uniquely named **d**irectory. Each `X` becomes a random character, so two runs never collide. |
| `trap 'cmd' EXIT` | Run `cmd` whenever the script ends: success, `exit 1`, or a `set -e` failure. The temp folder is always cleaned up. |

### Steps 6–7: transform with awk

```bash
awk -F',' '
BEGIN {OFS=","}
NR == 1 { print "student_id","name","course","age"; next }
{
    for (i=1; i<=4; i++) gsub(/^[[:space:]]+|[[:space:]]+$/, "", $i)   # trim every field
    if ($1 !~ /^[0-9]+$/ || $2 == "" || $3 == "" || $4 !~ /^[0-9]+$/) { bad=1; next }
    course = tolower($3)
    if (course == "data science")          $3 = "Data Science"           # fixes "Data science"
    else if (course == "data engineering") $3 = "Data Engineering"
    print $1,$2,$3,$4
}
END {exit bad}
' "$RAW_DIR/students.csv" > "$TMP_DIR/students_clean.csv" || { log ERROR "Student transformation failed"; exit 1; }
```

| Piece | Meaning |
|---|---|
| `gsub(/^[[:space:]]+\|[[:space:]]+$/, "", $i)` | **g**lobal **sub**stitute: delete leading (`^…+`) **or** trailing (`…+$`) whitespace in field `i`. This is awk's "trim". |
| `$1 !~ /^[0-9]+$/` | Field 1 does **not** match "digits only, start to end". |
| `next` | Skip the rest of the program for this line and move to the next line. |
| Assigning to `$3` | Rebuilds the line using `OFS`, so output is clean `a,b,c,d`. |
| `cmd \|\| { ...; exit 1; }` | Custom error handling. `set -e` doesn't stop the script on a command that's part of a `\|\|` list, so the log message is written before the deliberate `exit 1`. |

Step 7 uses the **two-file idiom** to check that every payment belongs to a known student:

```bash
awk -F',' '
FNR==NR { if (FNR>1) students[$1]=1; next }   # 1st file: remember every student_id
...     !($2 in students) { bad=1; next }      # 2nd file: reject unknown student_id
' "$TMP_DIR/students_clean.csv" "$RAW_DIR/payments.csv"
```

`NR` counts lines across **all** files; `FNR` restarts at 1 for **each** file. They're equal only while reading the first file. This is awk's version of a SQL join or lookup.

### Steps 8–9: report, then publish

```bash
{
    echo "DAY 4 ETL REPORT"
    echo "Students processed: $STUDENT_COUNT"
    ...
} > "$TMP_DIR/etl_summary.txt"

mv "$TMP_DIR/students_clean.csv" "$PROCESSED_DIR/students_clean.csv"
```

`{ ...; } > file` sends the output of the whole group into one file with one redirect. Everything is built in `$TMP_DIR` and moved into place only at the end. If any step fails, the old outputs in `data/processed/` stay untouched, and nobody sees a half-written report.

### The run: the validator did its job

```bash
chmod 750 scripts/etl_pipeline.sh     # rwxr-x---: owner and group can run it, others can't
bash -n scripts/etl_pipeline.sh       # syntax OK (no output)
./scripts/etl_pipeline.sh
```

```
2026-11-12 12:38:46 [INFO] Pipeline started
2026-11-12 12:38:46 [ERROR] Invalid column count in data/raw/payments.csv
```

`ls -lh backups/` showed `total 0`. The pipeline stopped at step 2, **before** the backup in step 4. That's correct fail-fast behaviour: nothing runs on data that failed validation.

The script expects a different `payments.csv` from the one in the lab. This is a **data contract** mismatch:

| Rule in `etl_pipeline.sh` | Actual `payments.csv` |
|---|---|
| 4 columns (step 2) | 3 columns |
| Header `payment_id,student_id,amount,status` | `payment_id,student_id,amount`, with no `status` |
| `payment_id` digits only, `^[0-9]+$` | `P01`, `P02`, … |
| `student_id` digits only, and present in `students.csv` | `ST01`, `ST02`, …, while `students.csv` uses `1`, `2`, … |
| `status` is `completed`, `pending` or `failed`; revenue counts only `completed` | (missing) |

Two ways to make it pass:
1. **Change the data to match the contract**: add a `status` column and use the same plain-number IDs in both files (the same foreign-key point as [§3.1](../intermediate/01-files-and-directories.md#31-datarawstudentscsv)).
2. **Change the contract to match the data**: expect 3 columns per file, update the header string, check `^P[0-9]+$` / `^ST[0-9]+$`, and map `ST01` → `1` before the student lookup.

Option 1 tested with a `payments.csv` that follows the contract:

```
payment_id,student_id,amount,status
1,1,10000,completed
2,2,5000,completed
3,3,3000,pending
4,4,7000,completed
```

```
[INFO] Pipeline started
[INFO] Backup created
[INFO] Students processed: 11
[INFO] Completed revenue: KSh 22000.00          ← 10000 + 5000 + 7000; the pending 3000 is excluded
[INFO] Pipeline completed successfully
```

`reports/etl_summary.txt` then shows `Data Science 6`. Alice's `Data science` row was merged in by the `tolower` step instead of being counted as a separate course.

> 💡 `bash -n` passing only means the **syntax** is valid. Logic and data problems show up only when the script runs. Use both.

---

## 32. Validate and Quarantine Bad Rows

[`payments_pipeline.sh`](../reference/scripts/payments_pipeline.sh) takes the other approach. Instead of stopping at the first problem, it **sets bad rows aside** in an error file, keeps processing the good ones, and reports both.

```
2026-11-12 12:50:50 [INFO] Starting student payments pipeline...
STUDENT PAYMENTS SUMMARY
========================
Valid transactions   : 5
Rejected records     : 2
Total valid revenue  : KSh 31000.00
Average payment      : KSh 6200.00
2026-11-12 12:50:50 [WARN] Issues logged in logs/errors.log:
Line 5 [WARNING - High amount > 50000]: P04,ST04,7000          ← wrong! (see below)
Line 6 [Invalid payment_id]: PO5,ST05,150000
Line 7 [WARNING - High amount > 50000]: P05,ST06,6000          ← wrong!
Line 8 [Invalid or negative amount]: P07,ST07,-17000
```

| Approach | Stop on first error (§31) | Set bad rows aside (§32) |
|---|---|---|
| A bad row… | fails the whole run | goes to an error file; the run continues |
| Good for | inputs that must be all-or-nothing | daily feeds where a few bad rows shouldn't block the rest |
| Risk | one typo blocks everything | errors pile up if nobody reads the report |

### New techniques

| Piece | Meaning |
|---|---|
| `: > "$ERROR_FILE"` | `:` is the do-nothing command. Redirecting it **truncates** the file to 0 bytes (or creates it). This gives a fresh error file each run. |
| `awk -v err_file="$ERROR_FILE"` | Pass a shell variable **into** awk as the awk variable `err_file`. This is the safe alternative to the broken `'...' $2 '...'` quoting in §29. |
| `print "..." >> err_file` | awk's **own** redirection: this line goes to the error file, while plain `print` still goes to stdout (the clean CSV). One pass, two outputs. |
| Rules + `next` | Checked in order. The first rule a row fails sends it to the error file and skips to the next row, so each row gets exactly one rejection reason. |
| `$1 !~ /^P[0-9]+$/` | Must be `P` followed by digits. This caught `PO5`, which has the **letter O** instead of zero. |
| `grep -vc "WARNING" file \|\| true` | Count lines **not** containing `WARNING` (`-v` inverts, `-c` counts). When the count is 0, `grep` exits with **1**, and `set -e` would end the script, so `\|\| true` ignores that. |
| `if (n>0) ... else print "0.00"` | Avoids dividing by zero when there are no valid rows. |

### ⚠️ Bug: `7000 > 50000` came out true

The warning fired for `P04` (7000) and `P05` (6000), but not for `P01` (10000). This is the same trap as `tolower($4) > 25` in [§12](03-text-processing.md#12-awk-fundamentals):

1. `gsub(..., $i)` **modifies** each field. A modified field is a plain **string** and loses its "looks like a number" status.
2. `$3 > 50000` therefore compares as **text**, character by character: `"7000"` vs `"50000"` → `"7"` > `"5"` → true. `"10000"` → `"1"` < `"5"` → false.

| `$3` | Text comparison with `"50000"` | Flagged? | Numeric truth |
|---|---|---|---|
| 10000 | `"1"` < `"5"` | no | correct |
| 7000 | `"7"` > `"5"` | **yes** ❌ | 7000 < 50000 |
| 6000 | `"6"` > `"5"` | **yes** ❌ | 6000 < 50000 |
| 5000, 3000 | `"5000"` is a prefix of `"50000"` / `"3"` < `"5"` | no | correct |

**Fix:** force a numeric comparison with `+ 0`:

```bash
if ($3 + 0 <= 0) ...      # Rule 5
if ($3 + 0 > 50000) ...   # high-amount warning
```

The copy in [`reference/scripts/payments_pipeline.sh`](../reference/scripts/payments_pipeline.sh) has this fix. With it, the two false warnings disappear. `PO5` (150000) is already rejected by the `payment_id` rule before the amount is checked, which shows that **rule order decides which reason a row gets**.

> ⚠️ `: > logs/errors.log` empties a file that earlier lessons also write to (`2>> logs/errors.log`, [§10](../intermediate/02-command-anatomy-and-io.md#10-redirection)). Each run of this pipeline erases those older entries. Give the pipeline its own file, e.g. `ERROR_FILE="logs/payments_rejects.log"`.

> 📝 This pipeline checks that `student_id` has the right format (`ST01`), but not that the student exists. Adding the two-file lookup from §31 would need the `ST01` ↔ `1` IDs to match first.

---

## 33. Working Safely at the Prompt

### Tab means "complete", not "indent"

While typing a multi-line awk program at the `>` prompt, the session showed this several times:

```
> if ($4 < 0 || $4 > 50000)
>
backups/    data/       local       output.txt  scripts/
config/     echo        logs/       reports/    }
```

Pressing **Tab** at an interactive prompt asks bash to **complete a filename**. Pressing it twice lists the candidates, which is the folder listing above. It doesn't insert a tab character. At the prompt, indent with **spaces**, or write the program in a file.

> 🧹 That listing also shows three stray files left over from lesson 06: **`echo`**, **`local`** and **`}`** ([§27](06-scripts-functions-and-exit-codes.md#27-case-study-debugging-the-log-function), attempt 6). Remove them with `rm -i -- echo local '}'`.

### Don't paste long scripts into the terminal

The first attempts to create `etl_pipeline.sh` by pasting a 150-line heredoc came out garbled: lines overwrote each other, prompts repeated, and the terminal had to be reopened. Pasting large blocks is fragile:

| Risk | What happens |
|---|---|
| A line that is exactly `EOF` appears early | The heredoc ends there, and **every remaining line runs as a command in your shell** |
| Paste is cut off or redrawn | You can't tell from the screen what actually went into the file |
| Lines run directly in your shell | `set -euo pipefail` then applies to **your terminal**: the next failing command (e.g. `cd "$(dirname "$0")/.."`, where `$0` is `-bash`) **closes the terminal**. This is likely why the session restarted at `shaq@shaq:~$`. |

Safer ways to create a long script:

```bash
nano scripts/etl_pipeline.sh       # paste into an editor, Ctrl+O to save, Ctrl+X to quit
# or write it in VS Code, then copy it to the Linux machine (scp / a shared folder / git pull)
```

Then always verify:

```bash
bash -n scripts/etl_pipeline.sh    # syntax check, runs nothing
head -5 scripts/etl_pipeline.sh    # starts with the shebang?
tail -5 scripts/etl_pipeline.sh    # ends where you expect, with no stray "EOF"?
cat -A scripts/etl_pipeline.sh | grep -c '\^M'   # 0 = no Windows line endings (§7)
```

### Checklist before running a pipeline

1. `bash -n script.sh`: syntax is valid
2. `head -1` each input and `count_columns`: the data matches the script's expected columns and header
3. Run it, then `echo $?`: 0 means success
4. Read the log (`cat logs/etl.log`) and the reject file, not only the screen
5. Check the outputs exist: `ls -l data/processed reports backups`

---

[← Scripts, Functions, Logging & Exit Codes](06-scripts-functions-and-exit-codes.md) · [🏠 Home](../README.md) · [Error Log →](../reference/error-log.md)
