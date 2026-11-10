<div align="center">

# 🐧 Linux Command Lab

**Hands-on notes for intermediate and advanced Linux command-line work, written from real terminal sessions.**

![Shell: Bash](https://img.shields.io/badge/shell-bash-4EAA25?logo=gnubash&logoColor=white)
![Platform: Linux](https://img.shields.io/badge/platform-linux-FCC624?logo=linux&logoColor=black)
![Level: Intermediate → Advanced](https://img.shields.io/badge/level-intermediate%20→%20advanced-blue)
![Status: Active](https://img.shields.io/badge/status-in%20progress-orange)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)

</div>

---

## About

This repository is a working notebook kept while learning the Linux command line beyond the basics. Every topic was practised in a real terminal inside a small sandbox project (`~/linux-command-lab`) with CSV data, a config file, a log file and two bash scripts.

The notes are not a copy of the man pages. Each section follows the same pattern:

1. **The command**, exactly as typed
2. **What every part means**, flag by flag
3. **What output to expect**
4. **What goes wrong**: the real errors hit during practice, their root cause, and the fix

The mistakes are kept on purpose. A trailing space in a directory name, a macOS-only command run on Linux, `2>$1` typed instead of `2>&1`: debugging these taught more than the commands that worked first time.

---

## Learning Path

The 22 sections are split into two levels and numbered continuously (§1–§22), so a cross-reference like "see §13" always points to one place.

### 🟢 Intermediate

| # | Lesson | Sections | Key commands |
|---|---|---|---|
| 01 | [Files & Directories](intermediate/01-files-and-directories.md) | §1–§7 | `mkdir -p`, brace expansion, `touch`, heredocs, `cat`, `head`, `tail`, `wc`, `mv`, `rm`, `ls -lb`, `cat -vet` |
| 02 | [Command Anatomy & I/O Streams](intermediate/02-command-anatomy-and-io.md) | §8–§10 | short/long flags, `--`, stdin/stdout/stderr, `>`, `>>`, `2>`, `2>&1`, `&>`, `\|`, `tee`, here-strings |

### 🔴 Advanced

| # | Lesson | Sections | Key commands |
|---|---|---|---|
| 03 | [Text Processing](advanced/03-text-processing.md) | §11–§14 | delimiters, POSIX classes, `awk` (`-F`, `NR`, `NF`, `OFS`, arrays), `sort -t -k2,2nr` |
| 04 | [Users & Groups](advanced/04-users-and-groups.md) | §15–§16 | `groupadd`, `getent`, `usermod -aG`, `gpasswd`, `id`, `newgrp` |
| 05 | [Permissions & Ownership](advanced/05-permissions-and-ownership.md) | §17–§22 | `chmod` (octal & symbolic), `chown`, `chgrp`, setgid shared dirs, setuid, sticky bit, `umask` |

### 📚 Reference

| Resource | Description |
|---|---|
| [Error Log & Fixes](reference/error-log.md) | 14 real errors: message, cause, fix, plus a debugging checklist |
| [Session Log & Roadmap](reference/session-log.md) | What was covered each day and what comes next |
| [`rebuild-lab.sh`](reference/rebuild-lab.sh) | One script that recreates the whole practice workspace |

---

## Repository Structure

```
linux-command-lab/
├── README.md
├── intermediate/
│   ├── 01-files-and-directories.md
│   └── 02-command-anatomy-and-io.md
├── advanced/
│   ├── 03-text-processing.md
│   ├── 04-users-and-groups.md
│   └── 05-permissions-and-ownership.md
├── reference/
│   ├── error-log.md
│   ├── session-log.md
│   └── rebuild-lab.sh
└── LICENSE
```

---

## Quick Start

You need a Linux machine, VM or WSL with **bash**. The examples were written on an Ubuntu/Debian-based system (`apt`); most commands work the same on any distribution.

```bash
# 1. Clone the notes
git clone https://github.com/ShaqMK/linux-command-lab.git
cd linux-command-lab

# 2. Build the practice workspace (defaults to ~/linux-command-lab)
bash reference/rebuild-lab.sh
#    or choose another location:
LAB_DIR=~/lab-sandbox bash reference/rebuild-lab.sh

# 3. Try the sample scripts
cd ~/linux-command-lab
./scripts/analyze.sh
```

Expected output of `analyze.sh`:

```
== Students per course ==
      3 Data Science
      2 Data Engineering
      1 Machine Learning

== Total payments ==
25000
```

The workspace it builds:

```
linux-command-lab/
├── backups/
├── config/app.conf
├── data/
│   ├── archived/
│   ├── processed/
│   └── raw/{students.csv, payments.csv}
├── logs/application.log
├── reports/
└── scripts/{analyze.sh, backup.sh}
```

> 💡 The user/group and permission lessons (§15–§22) use `sudo` and change system state, such as creating the `dataengineers` group. Run them in a VM or on a machine you control.

---

## Highlights

A few lessons worth reading even if you skip the rest:

| Topic | Takeaway | Section |
|---|---|---|
| Invisible trailing space | `tree` shows `scripts` but every command says it doesn't exist. `ls \| cat -vet` reveals `scripts $`. | [§7](intermediate/01-files-and-directories.md#7-exposing-hidden-characters--case-study) |
| Redirection order | `> file 2>&1` captures both streams; `2>&1 > file` does not. | [§10](intermediate/02-command-anatomy-and-io.md#10-redirection) |
| Silent awk failure | `-F','` leaves a leading space, so `$3 == "Data Science"` never matches and nothing prints. | [§14](advanced/03-text-processing.md#14-case-study-filtering-data-science-students) |
| String vs number | `tolower($4) > 25` compares text alphabetically, so `"100" < "25"`. | [§12](advanced/03-text-processing.md#12-awk-fundamentals) |
| `usermod -G` without `-a` | Replaces all supplementary groups and can remove your own `sudo` access. | [§16](advanced/04-users-and-groups.md#16-adding-users-to-groups-usermod--ag) |
| Team directories | `chmod 2770` + setgid makes new files inherit the group automatically. | [§20](advanced/05-permissions-and-ownership.md#20-handing-a-directory-to-a-group-shared-directory) |

---

## Conventions

| Marker | Meaning |
|---|---|
| `§N` | Section number, unique across all lessons |
| ⚠️ | A common mistake or a dangerous command |
| 📝 | Data-quality or background note |
| 💡 | Tip or better alternative |
| ✅ / ❌ | Working vs broken version of a command |
| `# → output` | Expected output shown as a comment |

---

## Roadmap

- [x] Files, directories, heredocs, hidden characters
- [x] Flags, standard streams, redirection
- [x] `awk`, delimiters, `sort` keys
- [x] Users, groups, permissions, ownership, `umask`
- [ ] More text processing: `grep -E`, `sed`, `cut`, `uniq`, `join`
- [ ] Finding things: `find`, `xargs`, `locate`
- [ ] Archives & compression: `tar`, `gzip`, `zip`
- [ ] Access Control Lists: `setfacl`, `getfacl`
- [ ] Processes & jobs: `ps`, `top`, `kill`, `bg`/`fg`, `nohup`
- [ ] Scheduling: `cron` / `crontab`
- [ ] Services & logs: `systemctl`, `journalctl`
- [ ] Networking: `ss`, `curl`, `ssh`, `scp`, `rsync`
- [ ] Disks: `df`, `du`, `lsblk`, `mount`

Day-by-day progress is in the [Session Log](reference/session-log.md).

---

## Feedback

Spotted a mistake or have a better way to do something? [Open an issue](https://github.com/ShaqMK/linux-command-lab/issues). Corrections are welcome.

---

## License

Released under the [MIT License](LICENSE). You're free to use, copy, modify and share these notes and scripts, as long as the copyright notice is kept.

<div align="center">

Maintained by [@ShaqMK](https://github.com/ShaqMK)

</div>
