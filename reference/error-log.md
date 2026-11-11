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
