# Linux Command Lab — Intermediate → Advanced Notes

> A working notebook built from real terminal sessions inside `~/linux-command-lab`.
> Each section covers **the command → what every part means → what output to expect → what goes wrong**.
> The file moves from intermediate to advanced and is updated throughout the week (see the [Session Log](#session-log) at the bottom).

---

## Table of Contents

**Part 1 — Intermediate: Files & Directories**
1. [Building the Lab Structure (`mkdir -p`, brace expansion, `tree`)](#1-building-the-lab-structure)
2. [Creating Empty Files (`touch`)](#2-creating-empty-files-touch)
3. [Writing Files with Heredocs (`cat << 'EOF'`)](#3-writing-files-with-heredocs)
4. [Reading Files (`cat`, `cat -n`, `head`, `tail`, `wc`)](#4-reading-files)
5. [Moving, Renaming & Deleting (`mv`, `rm`, `rm -r`, `rmdir`)](#5-moving-renaming--deleting)
6. [Listing in Detail (`ls` flags incl. `ls -lb`)](#6-listing-in-detail-ls)
7. [Exposing Hidden Characters (`cat -vet`) — Case Study](#7-exposing-hidden-characters--case-study)

**Part 2 — Intermediate: Command Anatomy & I/O Streams**

8. [Short and Long Flags](#8-short-and-long-flags)
9. [Standard Streams: stdin, stdout, stderr](#9-standard-streams-stdin-stdout-stderr)
10. [Redirection (`>`, `>>`, `2>`, `2>&1`, `&>`, `<`, `|`, `tee`)](#10-redirection)

**Part 3 — Upper Intermediate: Text Processing**

11. [Separators & Delimiters](#11-separators--delimiters)
12. [`awk` Fundamentals](#12-awk-fundamentals)
13. [`sort` with Keys (`-t`, `-k`, `n`, `r`)](#13-sort-with-keys)
14. [Case Study: Filtering "Data Science" Students](#14-case-study-filtering-data-science-students)

**Part 4 — Upper Intermediate: Users & Groups**

15. [Creating and Inspecting Groups (`groupadd`, `getent`)](#15-creating-and-inspecting-groups)
16. [Adding Users to Groups (`usermod -aG`)](#16-adding-users-to-groups-usermod--ag)

**Part 5 — Advanced: Permissions & Ownership**

17. [Reading the Permission String](#17-reading-the-permission-string)
18. [`chmod` — Numeric (e.g. `655`) and Symbolic Modes](#18-chmod--changing-permissions)
19. [`chgrp` and `chown` — Changing Ownership](#19-chgrp-and-chown--changing-ownership)
20. [Handing a Directory to a Group (shared directory + setgid)](#20-handing-a-directory-to-a-group-shared-directory)
21. [Special Bits: setuid, setgid, sticky](#21-special-bits-setuid-setgid-sticky)
22. [`umask` — Default Permissions](#22-umask--default-permissions)

**Reference**
- [Error Log & Fixes](#error-log--fixes)
- [Full Rebuild Script](#full-rebuild-script-recreate-the-lab-from-scratch)
- [Session Log](#session-log)

---

# PART 1 — INTERMEDIATE: FILES & DIRECTORIES

## 1. Building the Lab Structure

### Target layout

```
linux-command-lab/
├── backups
├── config
│   └── app.conf
├── data
│   ├── archived
│   ├── processed
│   └── raw
│       ├── payments.csv
│       └── students.csv
├── logs
│   └── application.log
├── reports
└── scripts
    ├── analyze.sh
    └── backup.sh
```

### Step 1: create the parent directory with `-p`

```bash
mkdir -p ~/linux-command-lab
cd ~/linux-command-lab
```

| Part | Meaning |
|---|---|
| `mkdir` | **m**a**k**e **dir**ectory. |
| `-p` | **p**arents. Creates every missing directory in the path, and **does not error if the directory already exists**. Without `-p`, `mkdir a/b/c` fails if `a/b` doesn't exist, and `mkdir existing_dir` fails with `File exists`. |
| `~` | Shorthand for your home directory (`/home/shaq`). |
| `cd` | **c**hange **d**irectory. Every relative path after this starts from `~/linux-command-lab`. |

### Step 2: create all subdirectories at once with brace expansion

```bash
mkdir -p backups config data/{raw,processed,archived} logs reports scripts
```

| Part | Meaning |
|---|---|
| `data/{raw,processed,archived}` | **Brace expansion**. Bash expands this to `data/raw data/processed data/archived` *before* `mkdir` runs. `mkdir` never sees the braces. |
| `-p` here | Needed because `data/` doesn't exist yet when `data/raw` is created. |

> ⚠️ **No spaces inside braces.** `{raw, processed}` breaks the expansion: bash sees `data/{raw,` and `processed}` as two separate words and creates oddly named folders.

Preview what an expansion produces without running anything:

```bash
echo data/{raw,processed,archived}
# data/raw data/processed data/archived
```

### Step 3: verify with `tree`

```bash
tree            # whole structure
tree -d         # directories only
tree -L 1       # only 1 level deep
tree -a         # include hidden (dot) files
```

The last line, `9 directories, 6 files`, is a quick summary to compare against what you expect.
Install `tree` if it's missing: `sudo apt install tree`.

---

## 2. Creating Empty Files (`touch`)

```bash
touch config/app.conf logs/application.log data/raw/students.csv data/raw/payments.csv
touch scripts/analyze.sh scripts/backup.sh
```

| Part | Meaning |
|---|---|
| `touch` | Updates a file's timestamps; **if the file doesn't exist, creates it empty**. Creating files is a side effect of that. |
| Multiple arguments | One `touch` can create many files. |

**Important:** `touch` does **not** create directories. If the parent directory is missing, you get:

```
touch: cannot touch 'scripts/analyze.sh': No such file or directory
```

The message refers to the **path** (`scripts/`), not the file. See [Case Study §7](#7-exposing-hidden-characters--case-study). This is the exact error from the session.

---

## 3. Writing Files with Heredocs

A **heredoc** ("here document") feeds a block of text into a command until it reaches a closing marker.

### General shape

```bash
cat << 'EOF' > path/to/file
line 1
line 2
EOF
```

| Part | Meaning |
|---|---|
| `cat` | Reads its input and prints it out. Here its input is the heredoc text. |
| `<<` | Heredoc operator: "the input comes from the lines below." |
| `'EOF'` | The **delimiter**. Any word works (`EOF`, `END`, `DATA`). Input stops at the first line containing *only* that word. |
| `>` | **Overwrite** redirect. Sends `cat`'s output into the file and **replaces all existing content**. Creates the file if missing. |
| `>>` | **Append** redirect. Adds to the **end** of the file and keeps existing content. |
| closing `EOF` | Must be on its own line with **no leading or trailing spaces** (unless you use `<<-`, see below). |

### Quoted vs unquoted delimiter (a key distinction)

| Form | Behaviour | Use for |
|---|---|---|
| `<< 'EOF'` (quoted) | Text is written **literally**. `$HOME`, `$(date)`, and `$1` stay as typed. | **Scripts**, where variables must expand when the script *runs*, not when the file is written. |
| `<< EOF` (unquoted) | Bash **expands** variables and `$(...)` *while writing*. | Templates where you want the current values baked in. |

```bash
cat << EOF
Today is $(date +%F)     # → Today is 2026-11-10
EOF

cat << 'EOF'
Today is $(date +%F)     # → Today is $(date +%F)
EOF
```

`<<-EOF` strips leading **tab** characters (not spaces) from each line. This is useful for indented heredocs inside scripts.

### 3.1 `data/raw/students.csv`

Initial write (overwrite with `>`):

```bash
cat << 'EOF' > data/raw/students.csv
student_id,name,course,age
1,John,Data Science,23
2,Mary,Data Engineering,25
3,Mike,Data Science,30
4,Alice,Data Science,23
EOF
```

Append two more rows (`>>`, the command from the session):

```bash
cat << 'EOF' >> data/raw/students.csv
5,Bob,Data Engineering,28
6,Sarah,Machine Learning,24
EOF
```

> 📝 **Data hygiene notes on the original file:**
> - The session version used `", "` (comma + space) as the separator. The space becomes part of each value (`" John"`), which breaks exact matching in `grep`, `awk`, `cut`, and pandas. Use plain commas.
> - Row 4 had `Data science` (lowercase *s*) while others have `Data Science`. Tools treat these as **two different courses** when grouping.
>
> Clean an existing file in place:
> ```bash
> sed -i 's/, /,/g; s/Data science/Data Science/g' data/raw/students.csv
> ```
> `sed -i` = edit **i**n place; `s/old/new/g` = substitute every (**g**lobal) match per line; `;` chains two substitutions.

> ⚠️ If you run the `>>` block twice, the rows are appended twice. Check with `cat -n` (§4).

### 3.2 `data/raw/payments.csv`

```bash
cat << 'EOF' > data/raw/payments.csv
payment_id,student_id,amount
P01,1,10000
P02,2,5000
P03,3,3000
P04,4,7000
EOF
```

> 📝 In the session, `payments.csv` used `ST01, ST02…` while `students.csv` used `1, 2…`. Foreign keys must match their primary keys, or a later join (`join`, SQL, pandas `merge`) will return nothing. Pick one format for both files. This version uses plain integers.

### 3.3 `config/app.conf`

```bash
cat << 'EOF' > config/app.conf
# Application configuration
APP_NAME=linux-command-lab
ENVIRONMENT=development
DATA_DIR=data/raw
BACKUP_DIR=backups
LOG_FILE=logs/application.log
LOG_LEVEL=INFO
EOF
```

`KEY=VALUE` with no spaces around `=` means a bash script can load this file directly with `source config/app.conf`.

### 3.4 `logs/application.log`

```bash
cat << 'EOF' > logs/application.log
2026-11-09 08:00:01 INFO  Application started
2026-11-09 08:00:05 INFO  Loaded students.csv (6 rows)
2026-11-09 08:00:06 WARN  Inconsistent course name: "Data science"
2026-11-09 08:01:12 ERROR Failed to open scripts/analyze.sh: No such file or directory
2026-11-09 08:02:30 INFO  Backup completed
EOF
```

You'll use this later for `grep`, `awk`, `cut`, and `sort | uniq -c` practice.

### 3.5 `scripts/backup.sh`

The **quoted** `'EOF'` matters here. Without it, `$(date ...)` would be evaluated once when writing the file, and every backup would get the same timestamp.

```bash
cat << 'EOF' > scripts/backup.sh
#!/usr/bin/env bash
# Backs up data/raw into a timestamped tar.gz in backups/
set -euo pipefail

source config/app.conf

timestamp=$(date +%Y%m%d_%H%M%S)
archive="${BACKUP_DIR}/raw_${timestamp}.tar.gz"

tar -czf "$archive" "$DATA_DIR"
echo "$(date '+%F %T') INFO  Backup created: $archive" >> "$LOG_FILE"
echo "Backup created: $archive"
EOF
```

| Line | Meaning |
|---|---|
| `#!/usr/bin/env bash` | **Shebang**. Tells the kernel to run this file with `bash`. `env` finds bash wherever it lives on `$PATH`. |
| `set -euo pipefail` | Safety mode. `-e` exits on any error; `-u` errors on unset variables; `-o pipefail` makes a pipeline fail if *any* part fails, not just the last. |
| `source config/app.conf` | Loads the config variables into this script. |
| `tar -czf` | **c**reate an archive, g**z**ip-compress it, write to **f**ile `$archive`. |
| `"$archive"` | Quoted so a path with spaces stays one argument. That is the same trailing-space problem from §7. |

### 3.6 `scripts/analyze.sh`

```bash
cat << 'EOF' > scripts/analyze.sh
#!/usr/bin/env bash
# Prints student counts per course and total payments
set -euo pipefail

echo "== Students per course =="
tail -n +2 data/raw/students.csv | cut -d',' -f3 | sort | uniq -c | sort -rn

echo
echo "== Total payments =="
awk -F',' 'NR > 1 { total += $3 } END { print total }' data/raw/payments.csv
EOF
```

| Piece | Meaning |
|---|---|
| `tail -n +2` | Print from line 2 onward, which skips the CSV header. |
| `cut -d',' -f3` | Split each line on `,` (**d**elimiter) and keep **f**ield 3 (course). |
| `sort \| uniq -c` | `uniq` only merges *adjacent* duplicates, so sort first. `-c` prefixes each line with its count. |
| `sort -rn` | Sort **n**umerically, **r**everse (largest first). |
| `awk -F','` | awk with comma as field separator. |
| `NR > 1` | **N**umber of **R**ecord (line number) > 1, which skips the header. |
| `total += $3` | Add column 3 (amount) to a running total. |
| `END { print total }` | Runs once after the last line. |

Make both scripts executable and run them (permissions are covered in §18):

```bash
chmod +x scripts/*.sh
./scripts/analyze.sh
./scripts/backup.sh
```

---

## 4. Reading Files

| Command | What it does |
|---|---|
| `cat file` | Print the whole file. |
| `cat -n file` | Print with **line numbers**. Good for spotting duplicate appended rows. |
| `cat -A file` | Show all hidden characters (same as `-vET`, see §7). |
| `head -n 3 file` | First 3 lines (default 10). |
| `tail -n 3 file` | Last 3 lines. |
| `tail -f logs/application.log` | **f**ollow. Keeps printing new lines as they're written. Stop with `Ctrl+C`. |
| `wc -l file` | Count **l**ines (`-w` words, `-c` bytes). |
| `less file` | Scroll page by page (`q` quits, `/word` searches). |
| `column -s, -t < file.csv` | Show a CSV as an aligned table: `-s,` sets the separator, `-t` builds a table. |

```bash
column -s, -t < data/raw/students.csv
# student_id  name   course            age
# 1           John   Data Science      23
# ...
```

---

## 5. Moving, Renaming & Deleting

### `mv` — move or rename

```bash
mv scripts/analyze.sh scripts/backup.sh backups/    # move two files INTO backups/
mv backups/analyze.sh backups/backup.sh scripts/    # move them back
mv old_name new_name                                # rename (same directory)
```

| Rule | Meaning |
|---|---|
| Last argument = destination | With multiple sources, the last argument **must be an existing directory**. |
| `mv a b` where `b` doesn't exist | Renames `a` to `b`. |
| `mv a b` where `b` is a file | **Silently overwrites `b`.** Use `mv -i` (**i**nteractive, asks first) or `mv -n` (**n**o-clobber). |
| `mv -v` | **v**erbose. Prints each move. |

> In the session, `mv scripts/analyze.sh scripts/backup.sh backups/` is most likely how the two scripts ended up in `backups/` instead of `scripts/`.

### `rm` — remove

| Command | Effect |
|---|---|
| `rm file` | Delete a file. **No recycle bin.** |
| `rm -i file` | Ask before each deletion. |
| `rm dir` | **Fails** with `rm: cannot remove 'dir': Is a directory`. |
| `rm -r dir` | **r**ecursive. Deletes the directory and everything inside. |
| `rm -rf dir` | Recursive and **f**orce: no prompts, no error if missing. **Double-check the path first.** |
| `rmdir dir` | Delete a directory **only if it's empty**. A safe choice. |

Why `rm scripts` and `rm -r scripts` said `No such file or directory` instead of `Is a directory`: no entry named exactly `scripts` existed. See §7.

---

## 6. Listing in Detail (`ls`)

| Flag | Meaning |
|---|---|
| `ls -l` | **l**ong format: permissions, links, owner, group, size, date, name. |
| `ls -a` | **a**ll, including hidden dot-files (`.bashrc`, `.git`). |
| `ls -h` | **h**uman sizes (`4.0K`, `1.2M`). Use with `-l`. |
| `ls -t` | Sort by modification **t**ime, newest first. |
| `ls -r` | **r**everse the sort. |
| `ls -R` | **R**ecursive listing. |
| `ls -d dir` | Show the directory itself, not its contents. |
| `ls -i` | Show **i**node numbers. |
| **`ls -b`** | **Print C-style escapes for unusual characters.** Spaces show as `\ `, tabs as `\t`, newlines as `\n`. |
| `ls -Q` | **Q**uote every name in `"..."`, which makes leading/trailing spaces visible. |

### How to use `ls -lb`

```bash
ls -lb
```

This gives the long listing (`-l`) with escaped names (`-b`). A directory with a trailing space shows up like this:

```
drwxrwxr-x 2 shaq shaq 4096 Nov  9 10:12 backups
drwxrwxr-x 2 shaq shaq 4096 Nov  9 10:10 scripts\ 
```

The `\ ` at the end is the giveaway. A plain `ls` shows `scripts`, which looks identical to a normal name.

`ls -Q` is often clearer:

```
"backups"  "config"  "data"  "logs"  "reports"  "scripts "
```

---

## 7. Exposing Hidden Characters — Case Study

### The problem (from the session)

```
$ tree
.
├── scripts          ← listed FIRST, out of alphabetical order
├── backups
...
$ touch scripts/analyze.sh
touch: cannot touch 'scripts/analyze.sh': No such file or directory
$ rm -r scripts
rm: cannot remove 'scripts': No such file or directory
```

`tree` shows `scripts`, but every command says it doesn't exist.

### The diagnosis: `ls | cat -vet`

```
$ ls | cat -vet
backups$
config$
data$
logs$
reports$
scripts $        ← space before the $
```

| Part | Meaning |
|---|---|
| `ls \|` | Pipe the list of names (one per line when piped) into the next command. |
| `cat -v` | Show non-printing characters visibly (`^M` for Windows carriage returns, `M-` for high bytes). |
| `cat -e` | Mark each **end of line** with `$`. |
| `cat -t` | Show **tabs** as `^I`. |
| `-vet` | All three combined (same as `cat -A`). |

The `$` marks exactly where each name ends. `scripts $` means the name is **`scripts␣`**, with a trailing space. It was probably created by something like `mkdir "scripts "` or a stray space before a closing quote or backslash.

So `scripts/analyze.sh` pointed to a directory named `scripts`, which didn't exist. The real directory was `scripts ` (with the space).

### The fix

The name contains a space, so you have to **quote it** (or escape the space):

```bash
# Option A — rename it (keeps any contents)
mv "scripts " scripts

# Option B — delete it and recreate it
rm -r "scripts "        # or: rm -r scripts\ 
mkdir scripts

# Then:
touch scripts/analyze.sh scripts/backup.sh
ls | cat -vet           # confirm: scripts$
tree
```

**Tab-completion** is the easiest way to avoid this. Type `rm -r scr` + `Tab` and bash fills in `scripts\ ` with the correct escaping.

### Other hidden characters `cat -vet` catches

| You see | Meaning | Typical cause |
|---|---|---|
| `^M$` at line ends | Windows line ending (`\r\n`) | File edited on Windows. Scripts fail with `/bin/bash^M: bad interpreter`. Fix: `sed -i 's/\r$//' file` or `dos2unix file`. |
| `^I` | Tab | Mixed tabs/spaces in TSV or Makefiles. |
| ` $` | Trailing space | Copy-paste, typing mistakes. |
| `M-BM-` | Non-breaking space (UTF-8 `C2 A0`) | Pasted from a web page or Word. |

---

# PART 2 — INTERMEDIATE: COMMAND ANATOMY & I/O STREAMS

## 8. Short and Long Flags

Flags (also called *options* or *switches*) change how a command behaves. Most commands accept two styles:

| Style | Looks like | Example | Notes |
|---|---|---|---|
| **Short** | one dash + one letter | `-r` | Fast to type. |
| **Long** | two dashes + a word | `--reverse` | Self-documenting. Best in scripts. |

```bash
sort -r file          # short
sort --reverse file   # long, same thing
```

### Rules that trip people up

| Rule | Example | Meaning |
|---|---|---|
| Short flags can be **combined** | `ls -lah` = `ls -l -a -h` | Works only for flags that take no value. |
| A short flag's **value** follows it, with or without a space | `sort -t',' -k2` or `sort -t ',' -k 2` | Both are fine. |
| A long flag's value uses `=` or a space | `sort --field-separator=, --key=2,2` | |
| Long flags **can't be combined** | `--reverse--numeric` ❌ | Write each one separately. |
| `--` means **end of flags** | `rm -- -weird-name.txt` | Everything after `--` is treated as a filename, even if it starts with `-`. |
| Letters are **case-sensitive** | `ls -r` (reverse) vs `ls -R` (recursive) | Different flags. |
| Meanings differ **per command** | `-r` = reverse in `sort`, recursive in `rm`/`cp` | Always check the command's manual. |

### Where to look flags up

```bash
sort --help     # quick summary
man sort        # full manual (q to quit, /word to search)
man -k sort     # search all manuals for "sort"
```

---

## 9. Standard Streams: stdin, stdout, stderr

Every process starts with three open channels, each identified by a **file descriptor (fd)** number:

| fd | Name | Default | Used for |
|---|---|---|---|
| `0` | **stdin** (standard input) | keyboard | Data coming **in** |
| `1` | **stdout** (standard output) | terminal | Normal results |
| `2` | **stderr** (standard error) | terminal | Error and warning messages |

stdout and stderr both appear on screen by default, so they *look* the same. They are **separate streams**, which is why you can send them to different places:

```bash
cat data/raw/students.csv missing_file.csv > out.txt
# The error still appears on screen, because > only captured fd 1.
# out.txt holds the CSV contents only.
```

Commands like `awk`, `sort`, `cut`, and `cat` read from **stdin when no filename is given**. That's what makes pipes work:

```bash
cat data/raw/students.csv | awk '{print $1}'   # awk reads stdin
awk '{print $1}' data/raw/students.csv         # awk reads the file directly (better, one less process)
```

---

## 10. Redirection

### Output redirection (from today's class)

```bash
echo "Data Engineering" > output.txt     # create/overwrite
echo "Pipeline Started" >> output.txt    # append
cat output.txt
# Data Engineering
# Pipeline Started
```

```bash
cat missing_file.csv 2> logs/errors.log  # send ONLY errors to a file
cat logs/errors.log
# cat: missing_file.csv: No such file or directory
```

```bash
ls data/raw/missing_folder > reports/check.txt 2>&1   # stdout AND stderr into one file
```

### Full reference

| Syntax | Meaning |
|---|---|
| `cmd > file` | stdout → file (overwrite). Same as `1>`. |
| `cmd >> file` | stdout → file (append). |
| `cmd 2> file` | stderr → file (overwrite). |
| `cmd 2>> file` | stderr → file (append). Good for a running error log. |
| `cmd > file 2>&1` | stdout → file, then stderr → **wherever stdout currently points** (the same file). |
| `cmd &> file` | Bash shorthand for the line above. |
| `cmd &>> file` | Both streams, append. |
| `cmd > out.txt 2> err.txt` | Each stream to its own file. |
| `cmd 2> /dev/null` | Throw errors away. `/dev/null` discards anything written to it. |
| `cmd < file` | stdin ← file. |
| `cmd1 \| cmd2` | **Pipe**: stdout of `cmd1` → stdin of `cmd2`. stderr is **not** piped. |
| `cmd1 2>&1 \| cmd2` | Pipe both streams. Bash also has `\|&` for this. |
| `cmd \| tee file` | Show output on screen **and** save to file (`tee -a` appends). |
| `cmd <<< "text"` | **Here-string**. Feeds one string to stdin. |
| `cmd << 'EOF'` | **Heredoc**. Feeds a block to stdin (§3). |

### Reading `2>&1` piece by piece

| Piece | Meaning |
|---|---|
| `2` | the stderr file descriptor |
| `>` | redirect it |
| `&1` | to **file descriptor 1**. The `&` is what makes `1` mean "fd 1" rather than "a file named `1`". |

Without the `&`, `2>1` creates a file literally named `1`.

### Order matters

Redirections are processed **left to right**:

```bash
ls missing > c.txt 2>&1    # ✅ stdout→c.txt, then stderr→(where stdout is now)=c.txt
ls missing 2>&1 > c.txt    # ❌ stderr→terminal (where stdout was), then stdout→c.txt
                           #    The error still appears on screen and c.txt is empty.
```

### Today's error: `2>$1`

```
$ ls data/raw/missing_folder > reports/check.txt 2>$1
-bash: $1: ambiguous redirect
```

`$` and `&` were mixed up. `$1` is a **variable**: the first argument passed to a script. In an interactive shell it's empty, so bash was told "redirect stderr to *nothing*" and refused ("ambiguous redirect"). The fix is `2>&1`.

> `ambiguous redirect` almost always means the target after `>` expanded to **nothing** or to **several words**, e.g. `> $file` where `$file` is unset or contains spaces. Quote variables: `> "$file"`.

### Practical patterns

```bash
./scripts/backup.sh >> logs/application.log 2>> logs/errors.log   # split logs
./scripts/analyze.sh | tee reports/summary.txt                    # watch and save
grep -r "ERROR" . 2>/dev/null                                     # hide "Permission denied" noise
wc -l < data/raw/students.csv                                     # count without printing the filename
```

---

# PART 3 — UPPER INTERMEDIATE: TEXT PROCESSING

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

**There must be a space between the closing `'` and the filename.** See Error #10 in the [Error Log](#error-log--fixes).

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

With `-F','`, field 3 is `" Data Science"`, which has a **leading space** (see the §11 table). `" Data Science" == "Data Science"` is false on every line, so nothing printed. There was no error, just no output, which makes this the hardest kind of bug to spot.

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
| sort `invalid number after ','` | `-k2, 2nr` has a space inside the key (§13). |

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

# PART 4 — UPPER INTERMEDIATE: USERS & GROUPS

## 15. Creating and Inspecting Groups

### The error from the session

```
$ sudo dseditgroup -o create dataengineers
sudo: dseditgroup: command not found
```

`dseditgroup` is a **macOS** command (part of Directory Services). It doesn't exist on Linux. The Linux equivalents are below.

| Task | macOS | Linux |
|---|---|---|
| Create group | `dseditgroup -o create g` | `groupadd g` |
| Add user to group | `dseditgroup -o edit -a u -t user g` | `usermod -aG g u` / `gpasswd -a u g` |
| Delete group | `dseditgroup -o delete g` | `groupdel g` |

### Create the group

```bash
sudo groupadd dataengineers
```

| Part | Meaning |
|---|---|
| `sudo` | Run as root. Creating groups changes system files (`/etc/group`, `/etc/gshadow`). |
| `groupadd` | Creates a new group with the next free **GID** (group ID). |
| `-g 1500` (optional) | Choose a specific GID. |

If the group already exists: `groupadd: group 'dataengineers' already exists`. `groupadd -f` makes that a silent success.

### Verify it exists

```bash
getent group dataengineers
# dataengineers:x:1001:
```

`getent` (**get ent**ries) queries system databases (`group`, `passwd`, `hosts`). It also checks network sources like LDAP, so it's more reliable than `grep dataengineers /etc/group`.

The output fields are separated by `:`:

| Field | Value | Meaning |
|---|---|---|
| 1 | `dataengineers` | Group name |
| 2 | `x` | Password placeholder (real data in `/etc/gshadow`) |
| 3 | `1001` | GID |
| 4 | *(empty)* | Comma-separated list of **supplementary members**. Empty means nobody has been added yet. |

Other group commands:

```bash
groupmod -n data_eng dataengineers   # rename a group
sudo groupdel dataengineers          # delete a group
cat /etc/group                       # all groups
```

---

## 16. Adding Users to Groups (`usermod -aG`)

```bash
sudo usermod -aG dataengineers shaq
```

| Part | Meaning |
|---|---|
| `usermod` | **mod**ify a **user** account. |
| `-G dataengineers` | Set the user's **supplementary** groups to this list (comma-separated for several: `-G g1,g2`). |
| `-a` | **a**ppend. Add to the existing groups instead of replacing them. **Only valid together with `-G`.** |
| `shaq` | The username, which always comes last. |

> ⚠️ **Never run `usermod -G` without `-a`.** `sudo usermod -G dataengineers shaq` *replaces* all of shaq's supplementary groups, removing him from `sudo`. You can lose admin rights on your own machine.

Alternative with the same effect: `sudo gpasswd -a shaq dataengineers` (remove with `gpasswd -d shaq dataengineers`).

### Verify membership

```bash
getent group dataengineers   # dataengineers:x:1001:shaq
id shaq                      # uid=1000(shaq) gid=1000(shaq) groups=1000(shaq),27(sudo),1001(dataengineers)
groups shaq                  # shaq : shaq sudo dataengineers
```

### Why `groups` (no username) doesn't show it yet

Group membership is loaded **at login**. Your current shell still has the old list:

```bash
groups          # → shaq sudo         (current session, outdated)
groups shaq     # → shaq sudo dataengineers   (reads the database)
```

To make it take effect:

| Method | Effect |
|---|---|
| Log out and log back in | Cleanest. Applies everywhere. |
| `newgrp dataengineers` | Opens a **new subshell** with the group active. `exit` returns to the old shell. |
| `su - shaq` | Fresh login shell. |

### Primary vs supplementary groups

- **Primary group** (`gid=` in `id`): assigned to new files you create. Usually a group with your own name. Change it with `usermod -g`.
- **Supplementary groups** (`groups=`): extra memberships that grant access. `-aG` changes these.

---

# PART 5 — ADVANCED: PERMISSIONS & OWNERSHIP

## 17. Reading the Permission String

```
$ ls -l scripts/backup.sh
-rwxr-xr-x 1 shaq dataengineers 312 Nov  9 10:20 scripts/backup.sh
```

```
-  rwx  r-x  r-x   1  shaq  dataengineers
│  │    │    │     │  │     └─ group owner
│  │    │    │     │  └─ user owner
│  │    │    │     └─ hard link count
│  │    │    └─ others (everyone else)
│  │    └─ group
│  └─ user (owner)
└─ type: - file, d directory, l symlink
```

### What `r`, `w`, `x` mean (different for files vs directories)

| Bit | On a **file** | On a **directory** |
|---|---|---|
| `r` (read) | View contents | **List** names inside (`ls`) |
| `w` (write) | Modify contents | **Create, delete, rename** entries inside |
| `x` (execute) | Run as a program/script | **Enter** it (`cd`) and access items inside |

> Deleting a file depends on **write permission on the directory**, not on the file itself.

---

## 18. `chmod` — Changing Permissions

### Numeric (octal) mode

Each permission has a value. Add them up per class:

| r | w | x |
|---|---|---|
| 4 | 2 | 1 |

| Digit | Bits | Meaning |
|---|---|---|
| 7 | `rwx` | 4+2+1 |
| 6 | `rw-` | 4+2 |
| 5 | `r-x` | 4+1 |
| 4 | `r--` | 4 |
| 0 | `---` | none |

Three digits = **user, group, others**, in that order.

#### Breaking down `chmod 655`

```bash
chmod 655 config/app.conf
```

| Class | Digit | Bits | Meaning |
|---|---|---|---|
| user | 6 | `rw-` | owner can read & write, **not execute** |
| group | 5 | `r-x` | group can read & execute |
| others | 5 | `r-x` | everyone can read & execute |

Result: `-rw-r-xr-x`. This is a valid but **unusual** mode, because the owner has *less* execute permission than strangers do. It makes a good exercise. In practice you'll mostly use:

| Mode | String | Typical use |
|---|---|---|
| `644` | `rw-r--r--` | Regular files (configs, CSVs) |
| `600` | `rw-------` | Secrets (SSH keys, `.env`) |
| `755` | `rwxr-xr-x` | Scripts and directories |
| `750` | `rwxr-x---` | Group-only scripts/dirs |
| `770` | `rwxrwx---` | Shared group workspaces |
| `775` | `rwxrwxr-x` | Shared dirs, readable by all |

### Symbolic mode

```
chmod [who][operator][permissions] file
```

| who | | operator | | perms |
|---|---|---|---|---|
| `u` user | | `+` add | | `r` `w` `x` |
| `g` group | | `-` remove | | `X` (see below) |
| `o` others | | `=` set exactly | | `s` setuid/setgid, `t` sticky |
| `a` all | | | | |

```bash
chmod +x scripts/*.sh             # add execute for everyone (respects umask)
chmod u+x,g+x scripts/backup.sh   # add execute for user and group
chmod o-rwx data/raw/*.csv        # remove all perms from others
chmod g=rw config/app.conf        # group gets exactly rw-
chmod -R g+rwX data/              # recursive; X = execute only on dirs (and files already executable)
```

`X` (capital) is safer than `x` with `-R`: directories get `x` so they can be entered, while CSVs don't become "executable".

Check permissions numerically:

```bash
stat -c '%a %A %U:%G %n' scripts/*.sh
# 755 -rwxr-xr-x shaq:dataengineers scripts/analyze.sh
```

---

## 19. `chgrp` and `chown` — Changing Ownership

### `chgrp` — change group owner

```bash
sudo chgrp dataengineers data/raw/students.csv
sudo chgrp -R dataengineers ~/linux-command-lab/data
```

| Part | Meaning |
|---|---|
| `chgrp` | **ch**ange **gr**ou**p**. |
| `-R` | Recursive. Applies to the directory and everything inside. |
| `sudo` | Not needed if you own the file **and** are a member of the target group. Otherwise required. |

### `chown` — change user (and optionally group) owner

```bash
sudo chown shaq file                     # user only
sudo chown shaq:dataengineers file       # user and group
sudo chown :dataengineers file           # group only (same as chgrp)
sudo chown -R shaq:dataengineers data/   # recursive
```

Only root can give a file to another **user**, which is why `chown` almost always needs `sudo`.

---

## 20. Handing a Directory to a Group (Shared Directory)

Goal: make `data/` a workspace where every member of `dataengineers` can read and write, and where **new files automatically belong to the group**.

```bash
# 1. Give the directory tree to the group
sudo chgrp -R dataengineers ~/linux-command-lab/data

# 2. Owner + group full access, others none
chmod -R 770 ~/linux-command-lab/data

# 3. Set the setgid bit on directories so new files inherit the group
find ~/linux-command-lab/data -type d -exec chmod g+s {} +

# 4. Verify
ls -ld ~/linux-command-lab/data
# drwxrws--- 5 shaq dataengineers 4096 Nov 10 09:00 data
#       ^ 's' in the group execute slot = setgid is on
```

| Piece | Meaning |
|---|---|
| `chmod 770` | `rwxrwx---` |
| `g+s` on a directory | **setgid**. New files/subdirs inherit the **directory's group** instead of the creator's primary group. Without it, a file Mary creates would belong to group `mary`, and others couldn't edit it. |
| `find … -type d -exec chmod g+s {} +` | Apply only to **d**irectories. `{}` is replaced by the found paths; `+` batches them into few `chmod` calls. |
| `chmod 2770` | Same as `770` + `g+s` in one step. The leading `2` is the setgid digit (§21). |

Test it:

```bash
touch data/processed/test.csv
ls -l data/processed/test.csv     # group should be dataengineers
```

> For a real team workspace, people usually put this outside a home directory, e.g. `/srv/dataengineers`. Home directories are often `750`, which blocks other users from reaching anything inside.

---

## 21. Special Bits: setuid, setgid, sticky

A **fourth (leading) digit** in `chmod` sets special bits:

| Digit | Bit | On files | On directories | Shows as |
|---|---|---|---|---|
| 4 | **setuid** | Runs as the file's **owner** (e.g. `/usr/bin/passwd` runs as root) | (ignored) | `s` in user-x slot |
| 2 | **setgid** | Runs with the file's group | New items inherit the dir's group (§20) | `s` in group-x slot |
| 1 | **sticky** | (ignored) | Only a file's **owner** can delete it, even if others have `w` on the dir (e.g. `/tmp`) | `t` in others-x slot |

```bash
ls -ld /tmp                 # drwxrwxrwt  ← sticky
ls -l /usr/bin/passwd       # -rwsr-xr-x  ← setuid
chmod 3770 shared_dir       # setgid + sticky + rwxrwx---
```

A capital `S` or `T` means the special bit is set but the underlying `x` is **not**. That's usually a mistake.

---

## 22. `umask` — Default Permissions

`umask` decides permissions for **newly created** files and directories by *removing* bits from a maximum:

- Files start at `666` (`rw-rw-rw-`). Execute is never given by default.
- Directories start at `777`.

```bash
umask          # e.g. 0002
umask -S       # u=rwx,g=rwx,o=rx
```

| umask | New file | New dir | Typical for |
|---|---|---|---|
| `022` | `644` | `755` | Most servers |
| `002` | `664` | `775` | Ubuntu desktops (users have private groups) |
| `077` | `600` | `700` | Privacy-focused setups |

`umask 002` works well with the shared directory in §20: new files are group-writable automatically. Set it per-session with `umask 002`, or permanently in `~/.bashrc`.

---

# REFERENCE

## Error Log & Fixes

| # | Error | Cause | Fix |
|---|---|---|---|
| 1 | `touch: cannot touch 'scripts/analyze.sh': No such file or directory` | Parent dir was named `scripts ` (trailing space), so `scripts/` didn't exist | `mv "scripts " scripts` (§7) |
| 2 | `rm: cannot remove 'scripts': No such file or directory` | Same, wrong name | `rm -r "scripts "` or tab-complete |
| 3 | `tree` listed `scripts` out of order | Trailing space changed sort order | Diagnose with `ls \| cat -vet` or `ls -Q` |
| 4 | `analyze.sh`/`backup.sh` were in `backups/` | Earlier `mv scripts/*.sh backups/` | `mv backups/*.sh scripts/` |
| 5 | `sudo: dseditgroup: command not found` | `dseditgroup` is macOS-only | `sudo groupadd dataengineers` (§15) |
| 6 | (Potential) CSV values with leading spaces | `, ` used as separator | `sed -i 's/, /,/g' file` (§3.1) |
| 7 | (Potential) `groups` doesn't show a new group | Membership is loaded at login | Log out/in or `newgrp` (§16) |
| 8 | `rm: cannot remove 'x': Is a directory` | `rm` without `-r` | `rm -r x` or `rmdir x` |
| 9 | awk filter `$3 == "Data Science"` printed **nothing** | `-F','` left a leading space in each field | Regex separator `-F'[[:space:]]*,[[:space:]]*'` (§11, §14) |
| 10 | `awk: cmd. line:1: ... ^ syntax error` | No space between closing `'` and the filename | `'{...}' data/raw/students.csv` (§14) |
| 11 | `sort: invalid number after ',': invalid count at start of ''` | Space inside key spec: `-k2, 2nr` | `-k2,2nr` (§13) |
| 12 | `-bash: $1: ambiguous redirect` | Typed `2>$1` (a variable) instead of `2>&1` (a file descriptor) | `> file 2>&1` (§10) |
| 13 | (Silent) `tolower($4) > 25` | `tolower` returns a string, so the comparison is alphabetical | Use `$4 > 25` on numeric fields (§12) |
| 14 | (Silent) error still on screen with `2>&1 > file` | Redirections run left to right | Put `2>&1` **after** `> file` (§10) |

---

## Full Rebuild Script (Recreate the Lab from Scratch)

Paste this to rebuild everything from Part 1 in one go. It's safe to re-run: it overwrites the files with `>`.

```bash
mkdir -p ~/linux-command-lab && cd ~/linux-command-lab
[ -d "scripts " ] && mv "scripts " scripts        # repair the trailing-space folder if present
mkdir -p backups config data/{raw,processed,archived} logs reports scripts
rm -f backups/analyze.sh backups/backup.sh

cat << 'EOF' > data/raw/students.csv
student_id,name,course,age
1,John,Data Science,23
2,Mary,Data Engineering,25
3,Mike,Data Science,30
4,Alice,Data Science,23
5,Bob,Data Engineering,28
6,Sarah,Machine Learning,24
EOF

cat << 'EOF' > data/raw/payments.csv
payment_id,student_id,amount
P01,1,10000
P02,2,5000
P03,3,3000
P04,4,7000
EOF

cat << 'EOF' > config/app.conf
APP_NAME=linux-command-lab
ENVIRONMENT=development
DATA_DIR=data/raw
BACKUP_DIR=backups
LOG_FILE=logs/application.log
LOG_LEVEL=INFO
EOF

cat << 'EOF' > logs/application.log
2026-11-09 08:00:01 INFO  Application started
2026-11-09 08:00:05 INFO  Loaded students.csv (6 rows)
2026-11-09 08:00:06 WARN  Inconsistent course name: "Data science"
2026-11-09 08:01:12 ERROR Failed to open scripts/analyze.sh: No such file or directory
2026-11-09 08:02:30 INFO  Backup completed
EOF

cat << 'EOF' > scripts/backup.sh
#!/usr/bin/env bash
set -euo pipefail
source config/app.conf
timestamp=$(date +%Y%m%d_%H%M%S)
archive="${BACKUP_DIR}/raw_${timestamp}.tar.gz"
tar -czf "$archive" "$DATA_DIR"
echo "$(date '+%F %T') INFO  Backup created: $archive" >> "$LOG_FILE"
echo "Backup created: $archive"
EOF

cat << 'EOF' > scripts/analyze.sh
#!/usr/bin/env bash
set -euo pipefail
echo "== Students per course =="
tail -n +2 data/raw/students.csv | cut -d',' -f3 | sort | uniq -c | sort -rn
echo
echo "== Total payments =="
awk -F',' 'NR > 1 { total += $3 } END { print total }' data/raw/payments.csv
EOF

chmod +x scripts/*.sh
tree
ls | cat -vet
```

Expected `analyze.sh` output:

```
== Students per course ==
      3 Data Science
      2 Data Engineering
      1 Machine Learning

== Total payments ==
25000
```

---

## Session Log

| Date | Topics | Notes |
|---|---|---|
| Mon 2026-11-09 | `mkdir -p`, `touch`, heredocs (`>` / `>>`), `tree`, `mv`, `rm -r`, `ls -lb`, `cat -vet`, `groupadd`, `getent`, `usermod -aG`, `chmod`, `chgrp` | Hit the trailing-space directory bug and the macOS `dseditgroup` mix-up. Both are fixed and documented above. |
| Tue 2026-11-10 | Short vs long flags; stdin/stdout/stderr; `>`, `>>`, `2>`, `2>&1`; separators & delimiters; `awk` (`$0`, `$N`, `NR`, `-F`, regex FS, `tolower`, patterns); `sort -t -k2,2nr` | Debugged an empty awk result caused by leading spaces, a missing space before the filename, `-k2, 2nr`, and `2>$1`. Also found a hidden string-vs-number comparison bug. Sections 8–14 added; users/groups and permissions renumbered to 15–22. |
| Wed 2026-11-11 | *(next session)* | |

### Coming up (suggested order for the rest of the week)

- [x] ~~awk, sort, redirection~~ (Tue)
- [ ] More text processing: `grep -E`, `sed`, `cut`, `uniq`, `join` (join `students.csv` ↔ `payments.csv` after aligning the IDs)
- [ ] Finding things: `find` (by name/size/time/perm), `xargs`, `locate`
- [ ] Archives & compression: `tar`, `gzip`, `zip`, verifying backups
- [ ] Access Control Lists: `setfacl`, `getfacl` (finer control than chmod)
- [ ] Processes: `ps`, `top`/`htop`, `kill`, `jobs`, `bg`/`fg`, `nohup`
- [ ] Scheduling: `cron`/`crontab -e` to run `backup.sh` automatically
- [ ] Services & logs: `systemctl`, `journalctl`
- [ ] Networking: `ss`, `curl`, `ping`, `ssh`, `scp`/`rsync`
- [ ] Disk: `df -h`, `du -sh`, `lsblk`, `mount`
