# 05 · Permissions & Ownership

> **Level:** Advanced · **Sections:** §17–§22
>
> The Linux permission model end to end: reading `rwx` strings, numeric and symbolic `chmod`, `chown`/`chgrp`, building a group-shared directory with setgid, the special bits and `umask`.

[← Users & Groups](04-users-and-groups.md) · [🏠 Home](../README.md) · [Scripts, Functions, Logging & Exit Codes →](06-scripts-functions-and-exit-codes.md)

---

## Contents

- **§17** — [Reading the Permission String](#17-reading-the-permission-string)
- **§18** — [`chmod` — Numeric (e.g. `655`) and Symbolic Modes](#18-chmod--changing-permissions)
- **§19** — [`chgrp` and `chown` — Changing Ownership](#19-chgrp-and-chown--changing-ownership)
- **§20** — [Handing a Directory to a Group (shared directory + setgid)](#20-handing-a-directory-to-a-group-shared-directory)
- **§21** — [Special Bits: setuid, setgid, sticky](#21-special-bits-setuid-setgid-sticky)
- **§22** — [`umask` — Default Permissions](#22-umask--default-permissions)

---

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
| `chmod 2770` | Same as `770` + `g+s` in one step. The leading `2` is the setgid digit ([§21](#21-special-bits-setuid-setgid-sticky)). |

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
| 2 | **setgid** | Runs with the file's group | New items inherit the dir's group ([§20](#20-handing-a-directory-to-a-group-shared-directory)) | `s` in group-x slot |
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

`umask 002` works well with the shared directory in [§20](#20-handing-a-directory-to-a-group-shared-directory): new files are group-writable automatically. Set it per-session with `umask 002`, or permanently in `~/.bashrc`.

---

[← Users & Groups](04-users-and-groups.md) · [🏠 Home](../README.md) · [Scripts, Functions, Logging & Exit Codes →](06-scripts-functions-and-exit-codes.md)
