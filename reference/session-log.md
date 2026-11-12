# Session Log & Roadmap

> What was covered in each session, and what's planned next.

[← Error Log](error-log.md) · [🏠 Home](../README.md)

---

## Sessions

| Date | Topics | Notes |
|---|---|---|
| Mon 2026-11-09 | `mkdir -p`, `touch`, heredocs (`>` / `>>`), `tree`, `mv`, `rm -r`, `ls -lb`, `cat -vet`, `groupadd`, `getent`, `usermod -aG`, `chmod`, `chgrp` | Hit the trailing-space directory bug and the macOS `dseditgroup` mix-up. Both are fixed and documented above. |
| Tue 2026-11-10 | Short vs long flags; stdin/stdout/stderr; `>`, `>>`, `2>`, `2>&1`; separators & delimiters; `awk` (`$0`, `$N`, `NR`, `-F`, regex FS, `tolower`, patterns); `sort -t -k2,2nr` | Debugged an empty awk result caused by leading spaces, a missing space before the filename, `-k2, 2nr`, and `2>$1`. Also found a hidden string-vs-number comparison bug. Sections 8–14 added; users/groups and permissions renumbered to 15–22. |
| Wed 2026-11-11 | Writing and running a script (`hello_pipeline.sh`, `$(whoami)`, `$(date)`, `$(pwd)`); `chmod 755` / `744` / `644`; shell functions (`name() { }`, `$1`, `local`); `count_records` / `count_columns` with awk `NR` vs `NF`; a timestamped `log` function with `tee -a` and log levels; exit codes (`$?`, 126/127/130, `PIPESTATUS`, `pipefail`, `return` vs `exit`) | Six failed attempts at the `log` function: unbalanced quotes, `[...}` typo, backslash-space, missing `;`, missing `; }`, and pasting `>` prompts back into bash (which created stray files `echo` and `}`). Found that `echo $?` returned 0 after `log ERROR` because the pipeline's last command, `tee`, succeeded. Sections 23–27 added as lesson 06; errors 15–24 logged. |
| Thu 2026-11-12 | Appending test rows with `cat << 'EOF' >>`; duplicate detection with `seen[key]++`; range checks (`\|\|` vs `&&`); `if`/`else`/`fi` and `[[ -f ]]` / `-s` tests; `check_file` function and `check_data.sh` exit codes; two pipelines: `etl_pipeline.sh` (stop on first error: `for` loops, awk `exit` codes, `mktemp -d`, `trap ... EXIT`, two-file `FNR==NR` lookup, publish with `mv`) and `payments_pipeline.sh` (set bad rows aside: `awk -v`, `print >> file`, `: >`, `grep -c \|\| true`) | `cat file << EOF` ignored the heredoc; `- F','` and inner `'` quotes broke awk; `$4` on a 3-column file flagged every row; a missing `;` after `local` broke four one-liners; Tab at the `>` prompt listed files instead of indenting; a 150-line paste garbled the terminal. `etl_pipeline.sh` correctly stopped on a data contract mismatch. Found a string-comparison bug that flagged 7000 and 6000 as "> 50000". Sections 28–33 added as lesson 07; errors 25–37 logged; scripts saved to `reference/scripts/`. |
| Fri 2026-11-13 | *(next session)* | |

## Roadmap

- [x] ~~awk, sort, redirection~~ (Tue)
- [x] ~~Scripts, functions, logging, exit codes~~ (Wed)
- [x] ~~Conditionals, file tests, `for` loops, data validation, ETL pipelines~~ (Thu)
- [ ] Align the data: shared plain-number IDs and a `status` column so `etl_pipeline.sh` passes on real lab data
- [ ] Script arguments: `$#`, `"$@"`, `shift`, `getopts`, `case`, usage messages
- [ ] More loops: `while read -r` over CSV rows, `IFS=,`
- [ ] Error handling in depth: `trap ... ERR`, logging the failing line number
- [ ] More text processing: `grep -E`, `sed`, `cut`, `uniq`, `join` (join `students.csv` ↔ `payments.csv` after aligning the IDs)
- [ ] Finding things: `find` (by name/size/time/perm), `xargs`, `locate`
- [ ] Archives & compression: `tar`, `gzip`, `zip`, verifying backups
- [ ] Access Control Lists: `setfacl`, `getfacl` (finer control than chmod)
- [ ] Processes: `ps`, `top`/`htop`, `kill`, `jobs`, `bg`/`fg`, `nohup`
- [ ] Scheduling: `cron`/`crontab -e` to run `backup.sh` automatically
- [ ] Services & logs: `systemctl`, `journalctl`
- [ ] Networking: `ss`, `curl`, `ping`, `ssh`, `scp`/`rsync`
- [ ] Disk: `df -h`, `du -sh`, `lsblk`, `mount`
