# 03 · Text Processing

> **Level:** Advanced · **Sections:** §11–§14
>
> Field-based processing of CSV data: delimiters and regex field separators, the `awk` language (patterns, built-ins, arrays, the string-vs-number trap) and multi-key `sort`. Ends with a step-by-step debugging case study.

[← Command Anatomy & I/O Streams](../intermediate/02-command-anatomy-and-io.md) · [🏠 Home](../README.md) · [Users & Groups →](04-users-and-groups.md)

---

## Contents

- **§11** — [Separators & Delimiters (incl. POSIX classes, `OFS`)](#11-separators--delimiters)
- **§12** — [`awk` Fundamentals](#12-awk-fundamentals)
- **§13** — [`sort` with Keys (`-t`, `-k`, `n`, `r`)](#13-sort-with-keys)
- **§14** — [Case Study: Filtering "Data Science" Students](#14-case-study-filtering-data-science-students)

---

## 11. Separators & Delimiters

A **delimiter** (or *separator*) is the character that splits a line into **fields** (columns). Each tool has its own flag to set it:

| Tool | Default delimiter | Flag | Regex allowed? |
|---|---|---|---|
| `awk` | runs of spaces/tabs (leading/trailing ignored) | `-F` (or `FS=` in `BEGIN`) | ✅ yes |
| `cut` | tab | `-d` | ❌ single character only |
| `sort` | transition from non-blank to blank | `-t` | ❌ single character only |
| `join` | whitespace | `-t` | ❌ |
| `paste` | tab | `-d` | ❌ |
| bash `read` | `$IFS` (space, tab, newline) | `IFS=,` | ❌ |

### Why the separator matters: your CSV

The class file uses **comma + space** (`", "`) between values:

```
1, John, Data Science, 23
```

| Separator used | `$1` | `$2` | `$3` | `$4` |
|---|---|---|---|---|
| default (whitespace) | `1,` | `John,` | `Data` | `Science,` |
| `-F','` | `1` | ` John` | ` Data Science` | ` 23` |
| `-F', '` | `1` | `John` | `Data Science` | `23` |
| `-F'[[:space:]]*,[[:space:]]*'` | `1` | `John` | `Data Science` | `23` |

This explains today's outputs:
- `awk '{print $1}'` gave `student_id,` and `1,`. With no `-F`, awk split on **spaces**, so the comma stayed attached to the first field.
- `awk '{print $2}'` gave `John,`, for the same reason. In `Data Science`, `$3` would be just `Data`.

### The regex separator, piece by piece

```
-F'[[:space:]]*,[[:space:]]*'
```

| Piece | Meaning |
|---|---|
| `[[:space:]]` | A **POSIX character class**: any whitespace (space, tab). The outer `[ ]` is the bracket expression; `[:space:]` is the class name inside it. |
| `*` | Zero or more of the previous item. |
| `,` | A literal comma. |
| Whole pattern | "a comma, with any amount of whitespace (including none) on either side". It works on `a,b`, `a, b`, and `a ,  b`. |

Other useful classes: `[[:digit:]]`, `[[:alpha:]]`, `[[:upper:]]`, `[[:lower:]]`, `[[:alnum:]]`, `[[:punct:]]`.

### Output separator (`OFS`)

`-F` controls how awk **reads** input. `OFS` controls what awk puts **between fields** when you write `print $2, $4` (with a comma):

```bash
awk -F'[[:space:]]*,[[:space:]]*' 'BEGIN{OFS=","} NR>1 {print $2, $4}' data/raw/students.csv
# John,23
```

`print $2 "," $4` (what you used in class) does the same thing by gluing a literal `","` between the values. Juxtaposed values with no comma are **concatenated** in awk.

> 💡 The cleanest long-term fix is to clean the file once (`sed -i 's/[[:space:]]*,[[:space:]]*/,/g' data/raw/students.csv`) and then use plain `-F','` everywhere.

---

## 12. `awk` Fundamentals

### Program structure

```
awk [flags] 'pattern { action }' file
```

| Part | Meaning |
|---|---|
| `'...'` | The awk program, in **single quotes** so bash doesn't touch `$1`, `$2`, etc. |
| `pattern` | A condition. The action runs only on lines where it's true. If omitted, it applies to every line. |
| `{ action }` | What to do. If omitted, the default is `{print $0}`. |
| file | Input. If omitted, awk reads stdin. |

**There must be a space between the closing `'` and the filename.** See Error #10 in the [Error Log](../reference/error-log.md).

### Built-in variables

| Variable | Meaning | Example |
|---|---|---|
| `$0` | The entire current line (record) | `awk '{print $0}' f` = `cat f` |
| `$1`, `$2`, … | Field 1, field 2, … | `{print $2}` |
| `$NF` | **Last** field | `{print $NF}` → age |
| `NF` | **N**umber of **F**ields on this line | `{print NF}` → `4` |
| `NR` | **N**umber of the current **R**ecord (line number) | `NR > 1` skips the header |
| `FS` | Input **F**ield **S**eparator (same as `-F`) | `BEGIN{FS=","}` |
| `OFS` | **O**utput **F**ield **S**eparator | `BEGIN{OFS="\t"}` |
| `FILENAME` | Current input file name | |

### Patterns and operators

| Operator | Meaning | Example |
|---|---|---|
| `==`, `!=` | equal / not equal | `$3 == "Data Science"` |
| `>`, `<`, `>=`, `<=` | comparison | `$4 > 25` |
| `&&`, `\|\|`, `!` | AND, OR, NOT | `NR > 1 && $4 > 25` |
| `~`, `!~` | **matches** / doesn't match a regex | `$3 ~ /[Ss]cience/` |
| `/regex/` alone | line matches regex | `awk '/ERROR/' logs/application.log` |

### Special blocks

```bash
awk 'BEGIN { print "Report" } { ... } END { print "Done" }' file
```

| Block | Runs |
|---|---|
| `BEGIN { }` | Once, **before** reading any input. Set `FS`/`OFS` and print headers here. |
| `END { }` | Once, **after** the last line. Print totals here. |

### Useful functions

| Function | Does | Example |
|---|---|---|
| `tolower(s)` / `toupper(s)` | Change case | `tolower($3) == "data science"` |
| `length(s)` | String length | `length($2) > 4` |
| `substr(s, start, len)` | Substring | `substr($2,1,1)` → `J` |
| `printf` | Formatted print, no automatic newline | `printf "%-6s %3d\n", $2, $4` |

### ⚠️ Gotcha: numbers vs strings (found in today's commands)

```bash
awk -F'...' 'NR > 1 && tolower($4) > 25 {print $2}'   # used in class
awk -F'...' 'NR > 1 && $4 > 25 {print $2}'            # correct
```

Both printed `Mike`, but only the second is reliable. `tolower()` always returns a **string**, so awk compares `"30" > "25"` **alphabetically**, character by character, not numerically. It happened to work today. It breaks as soon as an age has a different number of digits:

```bash
echo "x,100" | awk -F, '{print (tolower($2) > 25), ($2 > 25)}'
# 0 1      ← as a string, "100" < "25" because "1" < "2"
```

Rule: use `tolower`/`toupper` **only on text columns**. Leave numeric fields bare (`$4 > 25`). If a value might be a string, force it to a number with `$4 + 0 > 25`.

### Aggregation with arrays

```bash
awk -F'[[:space:]]*,[[:space:]]*' 'NR > 1 { count[tolower($3)]++ }
  END { for (c in count) print c ": " count[c] }' data/raw/students.csv
# data engineering: 1
# data science: 3
```

`count[key]++` creates an entry per unique course and increments it. This is awk's version of SQL `GROUP BY ... COUNT(*)`.

---

## 13. `sort` with Keys

```bash
sort -t',' -k2,2nr
```

| Part | Meaning |
|---|---|
| `-t','` | Field separator for `sort` is a comma. |
| `-k2,2` | Sort **key** starts at field 2 **and ends at field 2**. |
| `n` (attached to the key) | Compare this key **numerically** (`9 < 10`). Without it, `10 < 9` alphabetically. |
| `r` (attached to the key) | **Reverse** this key (largest first). |

### `-k START,END`: why the end matters

| Key | Sorts on |
|---|---|
| `-k2` | from field 2 **to the end of the line** (usually not what you want) |
| `-k2,2` | **only** field 2 |
| `-k3,3 -k2,2n` | by field 3, then ties broken by field 2 numerically |

### Today's error: `-k2, 2nr`

```
$ ... | sort -t',' -k2, 2nr
sort: invalid number after ',': invalid count at start of ‘’
```

The space after the comma splits it into **two arguments**: `-k2,` (key with a missing end, so `sort` complains about the empty `''` after the comma) and `2nr` (which `sort` would treat as a filename). A key spec must be one unbroken word: `-k2,2nr`.

### Ties and stability

```
Mike,30
Alice,23
John,23
```

Alice and John tie on 23. When keys tie, GNU `sort` falls back to comparing the **whole line** (ascending), so `Alice` comes before `John`. Add `-s` (**s**table) to keep ties in their original input order instead.

### Short ↔ long flags for sort

| Short | Long | Meaning |
|---|---|---|
| `-t` | `--field-separator` | delimiter |
| `-k` | `--key` | sort key |
| `-n` | `--numeric-sort` | numeric |
| `-r` | `--reverse` | descending |
| `-u` | `--unique` | drop duplicates |
| `-s` | `--stable` | keep tie order |
| `-h` | `--human-numeric-sort` | `2K < 1M` (use with `du -h`) |
| `-o file` | `--output=file` | write result to file (safe to use on the input file itself) |

### `sort` with single-column input

In class, `sort -t',' -k2` was piped output that was just names (`Mike`). With only one column there **is no field 2**, so `-t` and `-k` do nothing and the lines are compared whole. For one column, plain `sort` (or `sort -r`) is enough.

---

## 14. Case Study: Filtering "Data Science" Students

**Goal:** print `name,age` for every Data Science student, oldest first.

### Attempt 1: no output

```bash
awk -F',' 'NR > 1 && $3 == "Data Science" {print $2 "," $4}' data/raw/students.csv
# (nothing)
```

With `-F','`, field 3 is `" Data Science"`, which has a **leading space** (see the [§11](#11-separators--delimiters) table). `" Data Science" == "Data Science"` is false on every line, so nothing printed. There was no error, just no output, which makes this the hardest kind of bug to spot.

Debug trick: wrap the field in brackets to see its exact contents:

```bash
awk -F',' 'NR > 1 {print "[" $3 "]"}' data/raw/students.csv
# [ Data Science]    ← the space is now visible
```

### Attempt 2: fix the separator and the case

```bash
awk -F'[[:space:]]*,[[:space:]]*' 'NR > 1 && tolower($3) == "data science" {print $2 "," $4}'
```

- The regex separator removes the spaces around commas.
- `tolower($3)` makes `Data science` (Alice's row) match too.

### Attempt 3: two typos, two errors

```bash
... {print $2 "," $4}'data/raw/students.csv | sort -t',' -k2, 2nr
```

```
awk: cmd. line:1: NR > 1 && ... {print $2 "," $4}data/raw/students.csv
awk: cmd. line:1:                                                    ^ syntax error
sort: invalid number after ',': invalid count at start of ‘’
```

| Error | Cause |
|---|---|
| awk `syntax error` | No space between `'` and `data/...`. Bash joined them into **one argument**, so the filename became part of the awk program. The `^` points exactly where the program stopped making sense. |
| sort `invalid number after ','` | `-k2, 2nr` has a space inside the key ([§13](#13-sort-with-keys)). |

Both commands in a pipeline run **at the same time**, so their error messages can appear in any order.

### Final working command ✅

```bash
awk -F'[[:space:]]*,[[:space:]]*' \
    'NR > 1 && tolower($3) == "data science" {print $2 "," $4}' \
    data/raw/students.csv | sort -t',' -k2,2nr
```

```
Mike,30
Alice,23
John,23
```

(`\` at the end of a line continues the command on the next line, which makes long commands readable.)

### Variations practised

```bash
# Students older than 25 (names only)
awk -F'[[:space:]]*,[[:space:]]*' 'NR > 1 && $4 > 25 {print $2}' data/raw/students.csv
# Mike

# Same, using the exact ", " separator and keeping the age
awk -F', ' 'NR > 1 && $4 > 25 {print $2 ", " $4}' data/raw/students.csv | sort -t',' -k2,2nr
# Mike, 30

# Save the result as a report, and capture any errors
awk -F'[[:space:]]*,[[:space:]]*' 'NR > 1 && tolower($3) == "data science" {print $2 "," $4}' \
    data/raw/students.csv 2>> logs/errors.log | sort -t',' -k2,2nr > reports/data_science_students.csv
```

> Note: `-F', '` works only because every comma in this file is followed by **exactly one** space. The regex version keeps working if the spacing is inconsistent.

---

[← Command Anatomy & I/O Streams](../intermediate/02-command-anatomy-and-io.md) · [🏠 Home](../README.md) · [Users & Groups →](04-users-and-groups.md)
