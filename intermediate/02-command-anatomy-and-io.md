# 02 · Command Anatomy & I/O Streams

> **Level:** Intermediate · **Sections:** §8–§10
>
> How a command line is put together (short vs long flags, `--`) and how data flows through it: the three standard streams, every redirection operator, pipes and `tee`.

[← Files & Directories](01-files-and-directories.md) · [🏠 Home](../README.md) · [Text Processing →](../advanced/03-text-processing.md)

---

## Contents

- **§8** — [Short and Long Flags](#8-short-and-long-flags)
- **§9** — [Standard Streams: stdin, stdout, stderr](#9-standard-streams-stdin-stdout-stderr)
- **§10** — [Redirection (`>`, `>>`, `2>`, `2>&1`, `&>`, `<`, `|`, `tee`)](#10-redirection)

---

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
| `cmd << 'EOF'` | **Heredoc**. Feeds a block to stdin ([§3](01-files-and-directories.md#3-writing-files-with-heredocs)). |

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

[← Files & Directories](01-files-and-directories.md) · [🏠 Home](../README.md) · [Text Processing →](../advanced/03-text-processing.md)
