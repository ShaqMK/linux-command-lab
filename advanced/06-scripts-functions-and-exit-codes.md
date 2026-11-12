# 06 · Scripts, Functions, Logging & Exit Codes

> **Level:** Advanced · **Sections:** §23–§27
>
> From one-off commands to reusable shell code: writing and running a script, defining functions with arguments and `local` variables, building a timestamped `log` function with `tee`, and reading exit codes with `$?`. Ends with a step-by-step case study of six broken attempts at the `log` function.

[← Permissions & Ownership](05-permissions-and-ownership.md) · [🏠 Home](../README.md) · [Data Validation & ETL Pipelines →](07-data-validation-and-etl-pipelines.md)

---

## Contents

- **§23** — [Writing and Running a Script (`hello_pipeline.sh`, `$(...)`, `chmod 755`)](#23-writing-and-running-a-script)
- **§24** — [Shell Functions (`name() { ... }`, `$1`, `local`, `count_records`, `count_columns`)](#24-shell-functions)
- **§25** — [A Reusable `log` Function (`date`, `tee -a`, log levels)](#25-a-reusable-log-function)
- **§26** — [Exit Status & Error Codes (`$?`, `PIPESTATUS`, `pipefail`, `return`, `exit`)](#26-exit-status--error-codes)
- **§27** — [Case Study: Debugging the `log` Function](#27-case-study-debugging-the-log-function)

---

## 23. Writing and Running a Script

### Step 1: write the script with a heredoc

```bash
cat > scripts/hello_pipeline.sh << 'EOF'
#!/usr/bin/env bash
echo "Starting data pipeline"
echo "Current user: $(whoami)"
echo "Current date: $(date)"
echo "Working directory: $(pwd)"
echo "Pipeline completed"
EOF
```

`cat > file << 'EOF'` and `cat << 'EOF' > file` are the same command. Redirections can go anywhere on the line ([§3](../intermediate/01-files-and-directories.md#3-writing-files-with-heredocs)).

| Part | Meaning |
|---|---|
| `#!/usr/bin/env bash` | **Shebang**. Must be the very first line. Tells the kernel which interpreter runs the file. |
| `$(whoami)` | **Command substitution**. Bash runs `whoami` and puts its output into the string. |
| `$(date)` | Current date and time in the default format, e.g. `Wed Nov 11 11:02:39 EAT 2026`. |
| `$(pwd)` | **p**rint **w**orking **d**irectory: where the script was *started from*, not where the script file lives. |
| `'EOF'` (quoted) | Keeps `$(...)` literal while writing the file, so it runs each time the script runs. With an unquoted `EOF`, the date would be frozen at the moment you created the file. |

### Step 2: make it executable, then run it

```bash
chmod 755 scripts/hello_pipeline.sh
./scripts/hello_pipeline.sh
```

```
Starting data pipeline
Current user: shaq
Current date: Wed Nov 11 11:02:39 EAT 2026
Working directory: /home/shaq/linux-command-lab
Pipeline completed
```

| Part | Meaning |
|---|---|
| `chmod 755` | `rwxr-xr-x`: owner can edit and run it; everyone else can read and run it ([§18](05-permissions-and-ownership.md#18-chmod--changing-permissions)). |
| `./` | Run the file **at this path**. Bash doesn't search the current directory for commands, so `hello_pipeline.sh` alone gives `command not found` (exit code 127, [§26](#26-exit-status--error-codes)). |

Ways to run a script:

| Command | Needs `x` bit? | Runs in |
|---|---|---|
| `./scripts/hello_pipeline.sh` | ✅ yes | a new process (uses the shebang) |
| `bash scripts/hello_pipeline.sh` | ❌ no | a new process (ignores the shebang) |
| `source scripts/hello_pipeline.sh` (or `. file`) | ❌ no | **the current shell**. Variables and functions it defines stay after it finishes. |

Without the `x` bit, `./script.sh` fails with `Permission denied` and exit code **126**.

### Choosing the right mode: scripts vs data files

From the session:

```bash
chmod 744 data/raw/students,csv     # typo: comma instead of dot
# chmod: cannot access 'data/raw/students,csv': No such file or directory
chmod 744 data/raw/students.csv     # works, but gives a CSV an execute bit
chmod 644 data/raw/students.csv     # correct for a data file
```

| Mode | String | Right for |
|---|---|---|
| `755` | `rwxr-xr-x` | Scripts you want to run |
| `744` | `rwxr--r--` | Scripts only the owner should run |
| `644` | `rw-r--r--` | Data and config files: CSVs, `.conf`, logs |

A CSV is never "run", so it shouldn't have `x`. `ls -l` shows the result. `tree` doesn't show permissions, which is why it looked the same after every `chmod`. Use `tree -p` if you want them.

> 💡 Tab-completion prevents typos like `students,csv`: type `data/raw/stu` + `Tab`.

---

## 24. Shell Functions

A **function** is a named block of commands you can call like a command. It's the same idea as a small script, but it lives inside the current shell.

### Syntax

```bash
count_records() {
  local file="$1"
  awk 'END {print NR-1}' "$file"
}

count_records data/raw/students.csv
# 4
```

| Part | Meaning |
|---|---|
| `count_records()` | Function name followed by `()`. The parentheses are **always empty**: bash functions don't declare parameters. |
| `{ ... }` | The body. A space is required after `{`, and `}` must start a new command (see the one-line rule below). |
| `$1`, `$2`, … | **Positional parameters**: the 1st, 2nd, … argument passed when the function is called. `$#` is the count; `"$@"` is all of them. |
| `local file="$1"` | Creates a variable that exists **only inside this function**. Without `local`, `file` would overwrite any `file` variable in your shell. |
| `"$file"` | Always quote variables. A path containing a space stays one argument ([§7](../intermediate/01-files-and-directories.md#7-exposing-hidden-characters--case-study)). |

> 📝 `4` was correct for the file at the time of the session (a header plus 4 rows). A workspace built with [`rebuild-lab.sh`](../reference/rebuild-lab.sh) has 6 rows, so it prints `6`.

### The one-line rule: `;` before `}`

```bash
count_records() { local file="$1"; awk 'END {print NR-1}' "$file"; }   # ✅
count_columns() { local file="$1"; awk -F',' '...' "$file" }           # ❌ shows a > prompt
```

`{` and `}` are **reserved words**, not punctuation. Bash only recognises `}` as "end of function" when it appears where a new command could start: after a newline or a `;`. In the broken version, `}` is just another argument to `awk`, so bash keeps waiting for the real closing brace and shows the `>` continuation prompt. Press `Ctrl+C` and retype it with `; }`.

Every command on one line needs its own `;` as well. A missing `;` between two commands joins them into one, with confusing results ([§27](#27-case-study-debugging-the-log-function), attempt 4).

### `NR` vs `NF`: counting rows vs counting columns

The session tried several versions. The difference between them is the whole lesson:

| Function body | Output | Why |
|---|---|---|
| `awk 'END {print NR-1}' "$file"` | `4` | ✅ `NR` in `END` = total lines read. Minus 1 for the header = **number of records**. |
| `awk 'END {print NF}' "$file"` | `5` | ❌ `NF` in `END` = fields on the **last line only**. No `-F`, so awk split `4, Alice, Data science, 23` on whitespace: `4,` `Alice,` `Data` `science,` `23` = 5. |
| `awk -F',' 'NF==1 {print NF; exit}' "$file"` | *(nothing)* | ❌ The pattern means "lines with exactly 1 field". Every line has 4, so the action never runs. There's no error, just no output. |
| `awk -F',' 'NR==1 {print NF; exit}' "$file"` | `4` | ✅ On **line 1** (the header), print its field count, then stop reading. This is the **number of columns**. |

`NF==1` vs `NR==1` is one letter apart. `NR` is the line number; `NF` is the number of fields on the current line ([§12](03-text-processing.md#12-awk-fundamentals)). `exit` inside awk stops early, so a million-line file is just as fast as a 5-line one.

The working pair:

```bash
count_records() {
  local file="$1"
  awk 'END {print NR-1}' "$file"
}

count_columns() {
  local file="$1"
  awk -F',' 'NR==1 {print NF; exit}' "$file"
}

count_records data/raw/students.csv    # 4
count_columns data/raw/students.csv    # 4
count_columns data/raw/payments.csv    # 3
```

> ⚠️ `count_records` counts **lines**. A trailing blank line or a missing final newline changes the result. `wc -l` counts newline characters, so it can disagree by one on a file without a final newline.

### Managing functions

| Command | What it does |
|---|---|
| `type count_records` | Show whether a name is a function, builtin, alias or file, and print a function's body |
| `declare -f count_records` | Print the function's definition |
| `declare -F` | List the names of all defined functions |
| `unset -f count_records` | Delete the function |

Redefining a function just replaces it. That's why each new `count_records()` in the session took over from the previous one.

### Making functions permanent

Functions typed at the prompt **disappear when the terminal closes**. Two ways to keep them:

| Where | Loaded | Good for |
|---|---|---|
| A project file, e.g. `scripts/functions.sh`, loaded with `source scripts/functions.sh` | When you or a script sources it | Project helpers (`log`, `count_records`) |
| `~/.bashrc` | Every new interactive shell | Personal helpers you want everywhere |

[`rebuild-lab.sh`](../reference/rebuild-lab.sh) now creates `scripts/functions.sh` containing the final versions from §24–§26. A script loads it like this:

```bash
#!/usr/bin/env bash
set -euo pipefail
source scripts/functions.sh

log INFO "Pipeline started"
log INFO "students.csv: $(count_records data/raw/students.csv) records, $(count_columns data/raw/students.csv) columns"
```

---

## 25. A Reusable `log` Function

### The working version from the session

```bash
log() {
  local level="$1"
  local message="$2"
  echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $message" | tee -a logs/pipeline.log
}
```

```bash
log INFO  "Pipeline Started"                  # 2026-11-11 12:44:27 [INFO] Pipeline Started
log WARN  "Checking for duplicate records"    # 2026-11-11 12:44:36 [WARN] Checking for duplicate records
log ERROR "The actual error"                  # 2026-11-11 12:44:43 [ERROR] The actual error
```

| Part | Meaning |
|---|---|
| `local level="$1"` | First argument: the **log level**. |
| `local message="$2"` | Second argument: the text. It must be quoted when calling (`"Pipeline Started"`), or `Started` becomes `$3` and is lost. |
| `date '+%Y-%m-%d %H:%M:%S'` | Custom format. `+` starts the format string; `%Y` year, `%m` month, `%d` day, `%H:%M:%S` 24-hour time. Quoted because the format contains a space. |
| `[$level]` | Literal brackets around the level. Inside double quotes, `[` and `]` are plain text. |
| `\| tee -a logs/pipeline.log` | `tee` writes its input to the screen **and** to a file. `-a` **a**ppends; without it, every call would wipe the log ([§10](../intermediate/02-command-anatomy-and-io.md#10-redirection)). |

Why `YYYY-MM-DD HH:MM:SS`? It sorts correctly as plain text (`sort` puts lines in time order), it's unambiguous across countries, and it matches the format already used in `logs/application.log`.

### Log levels

| Level | Use for | Example |
|---|---|---|
| `DEBUG` | Detail only needed while developing | `Read 4 lines from students.csv` |
| `INFO` | Normal progress | `Pipeline Started` |
| `WARN` | Something odd, but the run continues | `Inconsistent course name: "Data science"` |
| `ERROR` | A step failed | `payments.csv not found` |

A consistent `[LEVEL]` tag makes the log easy to search with the tools from earlier lessons:

```bash
grep '\[ERROR\]' logs/pipeline.log                       # errors only (\[ escapes the bracket in a regex)
awk '{print $3}' logs/pipeline.log | sort | uniq -c      # count lines per level
tail -f logs/pipeline.log                                # watch a running pipeline
```

### Improved version: errors go to stderr

The session version sends every message to **stdout**, including errors. Normally error messages go to **stderr** ([§9](../intermediate/02-command-anatomy-and-io.md#9-standard-streams-stdin-stdout-stderr)), so that `2>` can separate them and so they still show up when stdout is piped somewhere else.

```bash
PIPELINE_LOG="${PIPELINE_LOG:-logs/pipeline.log}"

log() {
  local level="$1"
  local message="$2"
  local line
  line="$(date '+%Y-%m-%d %H:%M:%S') [$level] $message"

  if [[ "$level" == "ERROR" ]]; then
    echo "$line" | tee -a "$PIPELINE_LOG" >&2   # screen via stderr, plus the file
  else
    echo "$line" | tee -a "$PIPELINE_LOG"       # screen via stdout, plus the file
  fi
}
```

| New piece | Meaning |
|---|---|
| `"${PIPELINE_LOG:-logs/pipeline.log}"` | Use `$PIPELINE_LOG` if it's set, otherwise default to `logs/pipeline.log`. One place to change the log path. |
| `local line` then `line="$(...)"` | Declared and assigned separately on purpose. `local line="$(cmd)"` always returns 0, which hides `cmd`'s exit code ([§26](#26-exit-status--error-codes)). |
| `[[ "$level" == "ERROR" ]]` | Bash test. `[[ ]]` is safer than `[ ]` (no word splitting inside it). |
| `>&2` | Send `tee`'s screen copy to stderr (fd 2) instead of stdout. |

> ⚠️ `tee -a logs/pipeline.log` fails with `tee: logs/pipeline.log: No such file or directory` if `logs/` doesn't exist. The message still prints to the screen, but nothing is saved. Run `mkdir -p logs` first.

---

## 26. Exit Status & Error Codes

Every command finishes with an **exit status** (also called *exit code* or *return code*): a number from **0 to 255**.

- **`0` = success.**
- **Anything else = failure.** The number tells you what kind.

This is the opposite of most programming languages, where 0 means false. In the shell, **0 is the "true"/OK value**.

### Reading it with `$?`

```bash
ls data/raw/students.csv
echo $?     # 0   (success)

ls data/raw/missing.csv
echo $?     # 2   (ls: serious trouble, e.g. file not found)

echo $?     # 0   ← this is now the exit code of the previous echo!
```

`$?` holds the exit code of the **most recent command only**. Every command overwrites it, including `echo`. To use it more than once, save it first:

```bash
ls data/raw/missing.csv 2>/dev/null
rc=$?
echo "ls finished with code $rc"
```

### Common exit codes

| Code | Meaning | Example |
|---|---|---|
| `0` | Success | Any command that worked |
| `1` | General error / "false" | `grep` found no match, `false`, `[[ 1 == 2 ]]` |
| `2` | Misuse: bad option, syntax error, serious trouble | `ls missing_file`, `grep` couldn't read a file, `bash -n` on a broken script |
| `126` | Found, but **not executable** | `./script.sh` without `chmod +x` |
| `127` | **Command not found** | Typo in a command name; running `script.sh` without `./` |
| `128+N` | Killed by signal *N* | `130` = `Ctrl+C` (SIGINT = 2), `137` = `kill -9` (SIGKILL), `143` = `kill` (SIGTERM = 15) |
| `255` | Exit status out of range | `exit -1` (values wrap around modulo 256, so `exit 300` gives `44`) |

Each command documents its own codes under **EXIT STATUS** in its man page. For example, `grep` uses 0 for a match, 1 for no match, and 2 for an error, so "found nothing" and "something broke" can be told apart.

### ⚠️ A pipeline returns the exit code of its **last** command

This is why `echo $?` printed `0` at the end of the session, and why it would have printed `0` even during the broken attempts:

```bash
log ERROR "The actual error"
echo $?
# 0
```

The last command inside `log` is `tee`. `tee` succeeded in writing the line, so the whole function returned 0. The word "ERROR" in a message is just text: **it doesn't change the exit code**.

The same thing happens with real failures:

```bash
false | true
echo $?                  # 0  ← the failure of `false` is hidden

false | true
echo "${PIPESTATUS[@]}"  # 1 0  ← the exit code of every command in the last pipeline

set -o pipefail
false | true
echo $?                  # 1  ← now any failing part fails the pipeline
```

| Tool | Effect |
|---|---|
| `${PIPESTATUS[@]}` | Bash array holding each command's exit code from the most recent pipeline. |
| `set -o pipefail` | The pipeline's exit code becomes that of the last command that **failed**, or 0 if all succeeded. |

This is why every script in the lab starts with `set -euo pipefail` ([§3](../intermediate/01-files-and-directories.md#3-writing-files-with-heredocs)).

### Setting exit codes yourself: `return` and `exit`

| Keyword | Used in | Effect |
|---|---|---|
| `return N` | a **function** | Ends the function with code `N`. Without it, the function returns the code of its last command. |
| `exit N` | a **script** | Ends the whole script with code `N`. |

> ⚠️ Never use `exit` inside a function that you call from your interactive shell. It closes the terminal. Use `return`.

```bash
require_file() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    log ERROR "Missing file: $file"
    return 1
  fi
}

require_file data/raw/students.csv && echo "ok"      # ok
require_file data/raw/nope.csv     || echo "failed"  # [ERROR] Missing file … then: failed
```

### Acting on exit codes

```bash
# if: runs the then-branch when the command's exit code is 0
if grep -q "ERROR" logs/application.log; then
  echo "Errors found"
fi

# && runs the next command only on success; || only on failure
mkdir -p backups && echo "backups/ ready"
cp missing.csv backups/ 2>/dev/null || log WARN "Nothing to back up"

# Inside a script: stop with a meaningful code
[[ -f data/raw/payments.csv ]] || { log ERROR "payments.csv missing"; exit 1; }
```

| Pattern | Meaning |
|---|---|
| `grep -q` | **q**uiet: print nothing, just set the exit code. Made for `if`. |
| `cmd1 && cmd2` | Run `cmd2` only if `cmd1` returned 0. |
| `cmd1 \|\| cmd2` | Run `cmd2` only if `cmd1` failed. |
| `{ a; b; }` | Group commands so `\|\|` runs both. Same `;`-before-`}` rule as functions ([§24](#24-shell-functions)). |

> ⚠️ `a && b || c` is **not** if/else. If `a` succeeds but `b` fails, `c` runs too. Use a real `if` when that matters.

---

## 27. Case Study: Debugging the `log` Function

It took six attempts to get from the first try to the working `log` function in [§25](#25-a-reusable-log-function). Each one failed for a different reason, and together they cover the most common bash syntax mistakes.

### First: read the `>` prompt

When bash shows `>` instead of your normal `$` prompt, it is saying **"this command isn't finished yet"**. This is the *continuation prompt* (`$PS2`). Common causes:

| Unfinished thing | Example |
|---|---|
| An open quote `"` or `'` | `local level=$1"` |
| An open `{`, `(`, `if`, `for`, `while` | `f() { echo hi }` (no `;` before `}`) |
| A line ending in `\`, `\|`, `&&` or `\|\|` | `echo hi \|` |
| An open heredoc | `cat << 'EOF'` with no `EOF` line yet |

If you didn't expect the `>`, press **`Ctrl+C`** and retype the command. Typing more lines rarely fixes it.

### Attempt 1: unbalanced quote

```bash
log(){
> local level=$1"
```

**What happened:** endless `>` prompts. Even typing `log(){ ...` again at the `>` prompt didn't help.

**Why:** `$1"` opens a double quote that's never closed. Bash treats everything after it, across lines, as one string, and waits for the matching `"`.

**Fix:** `local level="$1"`, with quotes on **both** sides.

### Attempt 2: the message line was never closed

```bash
echo "$(date '+%Y-%m-%d %H:%M:%S') [$level} \ | tee -a logs/pipeline.log
```

**Why:** same as attempt 1. There's an opening `"` before `$(date` and no closing one. `$message"` was also missing.

### Attempt 3: it "worked", with two hidden bugs

```bash
echo "$(date '+%Y-%m-%d %H:%M:%S') [$level} $message" \ | tee -a logs/pipeline.log
```

```
2026-11-11 12:32:46 [INFO} Pipeline Started
```

| Bug | Cause |
|---|---|
| `[INFO}` | Bracket typo: `[` opened, `}` closed. Inside double quotes both are plain text, so bash printed exactly what was typed. |
| `\ ` (backslash-space) | Probably meant as a line continuation. A continuation is `\` **immediately followed by Enter**. `\ ` means "a literal space character", so `echo` receives one extra argument and every log line gets **two invisible trailing spaces**. `cat -A logs/pipeline.log` shows them as `Started  $` ([§7](../intermediate/01-files-and-directories.md#7-exposing-hidden-characters--case-study)). |

**Fix:** `[$level]`, and either remove the `\` or put the pipe on the next line:

```bash
echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $message" \
  | tee -a logs/pipeline.log
```

### Attempt 4: missing `;` in a one-liner

```bash
log(){ local level="$1"; local message="$2" echo "$(date '+%Y-%m-%d %H:%M:%S') [$level]} $message" \ | tee -a logs/pipeline.log; }
log ERROR "The actual error"
```

```
-bash: local: `2026-11-11 12:39:19 [ERROR]} ': not a valid identifier
-bash: local: ` ': not a valid identifier
```

**Why:** there's no `;` after `local message="$2"`, so bash reads the rest of the line as **more arguments to `local`**:

```
local  message="$2"  echo  "2026-11-11 12:39:19 [ERROR]} "  " "
```

| Argument | What `local` did with it |
|---|---|
| `message="$2"` | Declared a variable. Fine. |
| `echo` | Declared an empty variable named `echo`. No error, because `echo` is a valid name. |
| `"2026-… [ERROR]} "` | Not a valid variable name → **first error** |
| `" "` (from `\ `) | Not a valid variable name → **second error** |

Two more clues are in the error itself:
- **The message is empty** (`[ERROR]} ` with nothing after it). Bash expands every argument *before* running `local`, and at that moment `$message` hadn't been assigned yet.
- **Nothing reached `pipeline.log`**. `local` prints nothing to stdout (its errors go to stderr), so `tee` received empty input.

**Fix:** a `;` after every command: `local message="$2"; echo ...`

### Attempt 5: missing `;` before `}`

```bash
log(){ local level="$1"; local message="$2" echo "..." \ | tee -a logs/pipeline.log }
>
```

**Why:** the `}` is an argument to `tee` instead of closing the function, so bash waits for one ([§24](#24-shell-functions), "The one-line rule").

### Attempt 6: pasting terminal output back into the terminal

The function was copied from the scroll-back **with the `> ` prompts still on each line**. Later the `shaq@shaq:~/linux-command-lab$ ` prompt was included too:

```
log(){
> local level="$1"
> local message="$2"
>
> echo "$(date '+%Y-%m-%d %H:%M:%S') [$level]} $message" \ | tee -a logs/pipeline.log
> }
```

```
-bash: syntax error near unexpected token `newline'
2026-11-11 12:41:09 []} : command not found
```

Bash doesn't know the `>` characters were prompts. It reads each one as an **output redirection**:

| Pasted line | How bash read it | Result |
|---|---|---|
| `> local level="$1"` | "run `level=""`, sending output to a file named `local`" | Valid syntax, so the definition continued |
| `>` (alone) | "redirect output to…" with no filename | **`syntax error near unexpected token 'newline'`**. The whole definition was thrown away. |
| `> echo "…" \ \| tee -a …` | "send output to a file named **`echo`**; the command is the string `2026-11-11 12:41:09 []} `" | **`command not found`** (exit 127). The date expanded, but `$level` and `$message` were empty because no function was running. |
| `> }` | "create an empty file named **`}`**" | No message at all |
| `shaq@shaq:~/linux-command-lab$ log(){` | a word, then `log(` | **`syntax error near unexpected token '('`** |

> 🧹 **Side effect:** these attempts left **empty files named `echo`, `local` and `}`** in `~/linux-command-lab`. They showed up in `tree` the next day. Check and remove them:
> ```bash
> ls -l | cat -vet            # look for "echo", "local" and "}"
> rm -i -- echo local '}'     # -- ends options; quotes stop } being special
> ```

**Fix:** copy only the commands, never the prompts. To keep a working function, save it in a file and `source` it ([§24](#24-shell-functions)), instead of copying it out of the terminal.

### Attempt 7: working ✅

```bash
log(){
  local level="$1"
  local message="$2"
  echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $message" | tee -a logs/pipeline.log
}
```

### Lessons

| Rule | Prevents |
|---|---|
| Every opening `"` `'` `(` `{` `[` needs its matching closer | Attempts 1, 2, 3 |
| `\` continues a line only when it's the **last character** | Attempt 3 (trailing spaces) |
| On one line, separate commands with `;` and end functions with `; }` | Attempts 4, 5 |
| An unexpected `>` prompt means "unfinished": press `Ctrl+C` | Attempts 1, 2, 5 |
| Never paste prompts (`$`, `>`) back into the shell | Attempt 6 |
| Check results with `cat -A`, not only by eye | Attempt 3 |
| Test syntax without running anything: `bash -n script.sh` | All of the above, in script files |

---

[← Permissions & Ownership](05-permissions-and-ownership.md) · [🏠 Home](../README.md) · [Data Validation & ETL Pipelines →](07-data-validation-and-etl-pipelines.md)
