# 01 · Files & Directories

> **Level:** Intermediate · **Sections:** §1–§7
>
> Build the lab workspace from nothing: directories, empty files, heredoc-written files and scripts, then read, move, list and debug them. Ends with a real case study of a directory name hiding a trailing space.

[🏠 Home](../README.md) · [Command Anatomy & I/O Streams →](02-command-anatomy-and-io.md)

---

## Contents

- **§1** — [Building the Lab Structure (`mkdir -p`, brace expansion, `tree`)](#1-building-the-lab-structure)
- **§2** — [Creating Empty Files (`touch`)](#2-creating-empty-files-touch)
- **§3** — [Writing Files with Heredocs (`cat << 'EOF'`)](#3-writing-files-with-heredocs)
- **§4** — [Reading Files (`cat`, `head`, `tail`, `wc`, `column`)](#4-reading-files)
- **§5** — [Moving, Renaming & Deleting (`mv`, `rm`, `rmdir`)](#5-moving-renaming--deleting)
- **§6** — [Listing in Detail (`ls` flags incl. `ls -lb`, `ls -Q`)](#6-listing-in-detail-ls)
- **§7** — [Exposing Hidden Characters (`cat -vet`) — Case Study](#7-exposing-hidden-characters--case-study)

---

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

> ⚠️ If you run the `>>` block twice, the rows are appended twice. Check with `cat -n` ([§4](#4-reading-files)).

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
| `"$archive"` | Quoted so a path with spaces stays one argument. That is the same trailing-space problem from [§7](#7-exposing-hidden-characters--case-study). |

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

Make both scripts executable and run them (permissions are covered in [§18](../advanced/05-permissions-and-ownership.md#18-chmod--changing-permissions)):

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
| `cat -A file` | Show all hidden characters (same as `-vET`, see [§7](#7-exposing-hidden-characters--case-study)). |
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

Why `rm scripts` and `rm -r scripts` said `No such file or directory` instead of `Is a directory`: no entry named exactly `scripts` existed. See [§7](#7-exposing-hidden-characters--case-study).

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

[🏠 Home](../README.md) · [Command Anatomy & I/O Streams →](02-command-anatomy-and-io.md)
