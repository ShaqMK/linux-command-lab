# Error Log & Fixes

> Every error hit during the lab sessions: the exact message, the root cause and the fix, with a link to the section that explains it.
> Rows marked *(Potential)* or *(Silent)* produced no error message but would cause wrong results.

[🏠 Home](../README.md) · [Session Log →](session-log.md)

---

| # | Error | Cause | Fix |
|---|---|---|---|
| 1 | `touch: cannot touch 'scripts/analyze.sh': No such file or directory` | Parent dir was named `scripts ` (trailing space), so `scripts/` didn't exist | `mv "scripts " scripts` ([§7](../intermediate/01-files-and-directories.md#7-exposing-hidden-characters--case-study)) |
| 2 | `rm: cannot remove 'scripts': No such file or directory` | Same, wrong name | `rm -r "scripts "` or tab-complete |
| 3 | `tree` listed `scripts` out of order | Trailing space changed sort order | Diagnose with `ls \| cat -vet` or `ls -Q` |
| 4 | `analyze.sh`/`backup.sh` were in `backups/` | Earlier `mv scripts/*.sh backups/` | `mv backups/*.sh scripts/` |
| 5 | `sudo: dseditgroup: command not found` | `dseditgroup` is macOS-only | `sudo groupadd dataengineers` ([§15](../advanced/04-users-and-groups.md#15-creating-and-inspecting-groups)) |
| 6 | (Potential) CSV values with leading spaces | `, ` used as separator | `sed -i 's/, /,/g' file` ([§3.1](../intermediate/01-files-and-directories.md#31-datarawstudentscsv)) |
| 7 | (Potential) `groups` doesn't show a new group | Membership is loaded at login | Log out/in or `newgrp` ([§16](../advanced/04-users-and-groups.md#16-adding-users-to-groups-usermod--ag)) |
| 8 | `rm: cannot remove 'x': Is a directory` | `rm` without `-r` | `rm -r x` or `rmdir x` |
| 9 | awk filter `$3 == "Data Science"` printed **nothing** | `-F','` left a leading space in each field | Regex separator `-F'[[:space:]]*,[[:space:]]*'` ([§11](../advanced/03-text-processing.md#11-separators--delimiters), [§14](../advanced/03-text-processing.md#14-case-study-filtering-data-science-students)) |
| 10 | `awk: cmd. line:1: ... ^ syntax error` | No space between closing `'` and the filename | `'{...}' data/raw/students.csv` ([§14](../advanced/03-text-processing.md#14-case-study-filtering-data-science-students)) |
| 11 | `sort: invalid number after ',': invalid count at start of ''` | Space inside key spec: `-k2, 2nr` | `-k2,2nr` ([§13](../advanced/03-text-processing.md#13-sort-with-keys)) |
| 12 | `-bash: $1: ambiguous redirect` | Typed `2>$1` (a variable) instead of `2>&1` (a file descriptor) | `> file 2>&1` ([§10](../intermediate/02-command-anatomy-and-io.md#10-redirection)) |
| 13 | (Silent) `tolower($4) > 25` | `tolower` returns a string, so the comparison is alphabetical | Use `$4 > 25` on numeric fields ([§12](../advanced/03-text-processing.md#12-awk-fundamentals)) |
| 14 | (Silent) error still on screen with `2>&1 > file` | Redirections run left to right | Put `2>&1` **after** `> file` ([§10](../intermediate/02-command-anatomy-and-io.md#10-redirection)) |
| 15 | `chmod: cannot access 'data/raw/students,csv': No such file or directory` | Typo: `,` instead of `.` in the filename | `chmod 644 data/raw/students.csv`; tab-complete paths ([§23](../advanced/06-scripts-functions-and-exit-codes.md#23-writing-and-running-a-script)) |
| 16 | (Silent) `chmod 744` on a CSV | Gives a data file an execute bit it never needs | `644` for data/config, `755` for scripts ([§23](../advanced/06-scripts-functions-and-exit-codes.md#23-writing-and-running-a-script)) |
| 17 | (Silent) `count_records` printed `5` instead of the row count | `awk 'END {print NF}'` counts fields on the last line (whitespace-split), not lines | `awk 'END {print NR-1}'` ([§24](../advanced/06-scripts-functions-and-exit-codes.md#24-shell-functions)) |
| 18 | (Silent) `count_columns` printed nothing | `NF==1` matches lines with one field; every line has 4 | `awk -F',' 'NR==1 {print NF; exit}'` ([§24](../advanced/06-scripts-functions-and-exit-codes.md#24-shell-functions)) |
| 19 | Endless `>` prompts while defining a function | Unclosed `"` (`local level=$1"`), or no `;` before `}` in a one-liner | `Ctrl+C`, then balance quotes and use `; }` ([§27](../advanced/06-scripts-functions-and-exit-codes.md#27-case-study-debugging-the-log-function)) |
| 20 | (Silent) log shows `[INFO}` and has trailing spaces | Bracket typo `[...}`; `\ ` (backslash-space) passes a literal space to `echo` | `[$level]`; `\` must be the last character on the line ([§27](../advanced/06-scripts-functions-and-exit-codes.md#27-case-study-debugging-the-log-function)) |
| 21 | ``local: `2026-11-11 12:39:19 [ERROR]} ': not a valid identifier`` | Missing `;` after `local message="$2"`, so `echo` and the string became arguments to `local` | `local message="$2"; echo ...` ([§27](../advanced/06-scripts-functions-and-exit-codes.md#27-case-study-debugging-the-log-function)) |
| 22 | ``syntax error near unexpected token `newline'`` then `2026-11-11 12:41:09 []} : command not found` | Pasted terminal output including the `> ` prompts; bash read each `>` as a redirection and created empty files `echo` and `}` | Paste commands only; `rm -i -- echo '}'` ([§27](../advanced/06-scripts-functions-and-exit-codes.md#27-case-study-debugging-the-log-function)) |
| 23 | ``syntax error near unexpected token `('`` | Pasted the `shaq@shaq:~/linux-command-lab$` prompt along with the command | Paste commands only ([§27](../advanced/06-scripts-functions-and-exit-codes.md#27-case-study-debugging-the-log-function)) |
| 24 | (Silent) `log ERROR ...` then `echo $?` gives `0` | A pipeline's exit code is its last command's (`tee`), and the word "ERROR" is just text | `return 1` explicitly; `set -o pipefail`; `${PIPESTATUS[@]}` ([§26](../advanced/06-scripts-functions-and-exit-codes.md#26-exit-status--error-codes)) |
| 25 | (Silent) `cat data/raw/students.csv << 'EOF'` printed the file and appended nothing | With a filename, `cat` ignores stdin (the heredoc); there was no `>>` either | `cat << 'EOF' >> data/raw/students.csv` ([§28](../advanced/07-data-validation-and-etl-pipelines.md#28-appending-rows-with-heredocs)) |
| 26 | (Silent) "DuplicateID found" listed Mary and John, who are probably different people | Duplicates checked on `$2` (name), which isn't a unique key | Check the ID for key duplicates, or all columns except the ID for repeated records ([§29](../advanced/07-data-validation-and-etl-pipelines.md#29-data-quality-checks-with-awk)) |
| 27 | `awk: cmd. line:2: -` / `^ unexpected newline or end of string` | `- F','` (space after the dash): awk read the lone `-` as its program. Inner `'` quotes also cut the program apart. | `-F','`; use only `"` inside the awk program ([§29](../advanced/07-data-validation-and-etl-pipelines.md#29-data-quality-checks-with-awk)) |
| 28 | (Silent) every payment printed as `Invalid amount: ST01 ->` | `$4` on a 3-column file is `""`, and `"" < 0` compares as text, so it's true | Use `$3` for the amount; check the column count first ([§29](../advanced/07-data-validation-and-etl-pipelines.md#29-data-quality-checks-with-awk)) |
| 29 | (Silent) switching `\|\|` to `&&` made the amount check print nothing | `x < 0 && x > 50000` can never be true | Outside a range = `\|\|`; inside a range = `&&` ([§29](../advanced/07-data-validation-and-etl-pipelines.md#29-data-quality-checks-with-awk)) |
| 30 | ``syntax error near unexpected token `then'`` in a one-line `check_file` | No `;` after `local file="$1"`, so `if` became an argument to `local` | `;` after every command, or use multi-line form ([§30](../advanced/07-data-validation-and-etl-pipelines.md#30-conditionals-and-file-tests)) |
| 31 | `-bash: script/check_data.sh: No such file or directory` | Folder typo: `script/` vs `scripts/` | `cat > scripts/check_data.sh` ([§30](../advanced/07-data-validation-and-etl-pipelines.md#30-conditionals-and-file-tests)) |
| 32 | (Potential) `if [[ ... ]] then` with no `;` | Works with `[[ ]]` by luck; with `[ ]` it's a syntax error | Always write `; then` ([§30](../advanced/07-data-validation-and-etl-pipelines.md#30-conditionals-and-file-tests)) |
| 33 | Tab at the `>` prompt printed a file listing instead of indenting | At the prompt, Tab means filename completion | Indent with spaces, or write the code in a file ([§33](../advanced/07-data-validation-and-etl-pipelines.md#33-working-safely-at-the-prompt)) |
| 34 | Garbled terminal and a closed session while pasting `etl_pipeline.sh` | Pasting a 150-line heredoc is fragile; lines that run in your shell apply `set -e` to it | Create long scripts in `nano`/an editor; check with `bash -n`, `head`, `tail` ([§33](../advanced/07-data-validation-and-etl-pipelines.md#33-working-safely-at-the-prompt)) |
| 35 | `[ERROR] Invalid column count in data/raw/payments.csv` (and `backups/` empty) | Data contract mismatch: the script expects 4 columns with `status` and numeric IDs. It stopped before the backup step, as designed. | Make the data match the contract, or change the contract ([§31](../advanced/07-data-validation-and-etl-pipelines.md#31-anatomy-of-an-etl-pipeline)) |
| 36 | (Silent) `[WARNING - High amount > 50000]` on 7000 and 6000 | After `gsub`, `$3` is a string, so `"7000" > 50000` compares as text (`"7"` > `"5"`) | `$3 + 0 > 50000` ([§32](../advanced/07-data-validation-and-etl-pipelines.md#32-validate-and-quarantine-bad-rows)) |
| 37 | (Potential) `: > logs/errors.log` erases older error entries | The pipeline shares `errors.log` with earlier lessons and truncates it on every run | Give the pipeline its own reject file ([§32](../advanced/07-data-validation-and-etl-pipelines.md#32-validate-and-quarantine-bad-rows)) |

---

## Debugging checklist

When a command fails or prints nothing, check these first — they cover every row above:

1. **Hidden characters in names or data?** `ls | cat -vet`, `ls -Q`, `cat -A file`
2. **Field contents exactly what you think?** `awk -F',' '{print "[" $3 "]"}' file`
3. **Arguments split where you intended?** Spaces inside `-k2, 2nr` or missing before a filename change the argument list.
4. **Right OS / distro?** `uname -a`, `cat /etc/os-release` (e.g. `dseditgroup` is macOS-only).
5. **Redirection order and syntax?** `> file 2>&1`, never `2>&1 > file` or `2>$1`.
6. **Session state stale?** Group changes need a new login (`newgrp`, log out/in).
7. **Unexpected `>` prompt?** Bash thinks the command is unfinished (open quote, `{`, trailing `\` or `|`). Press `Ctrl+C` and retype.
8. **Did it actually succeed?** `echo $?` right after the command (0 = success); for pipelines, `echo "${PIPESTATUS[@]}"`.
9. **Pasted from the terminal?** Remove any `$` or `>` prompts first. They are read as part of the command.
10. **Syntax check a script without running it:** `bash -n script.sh`
