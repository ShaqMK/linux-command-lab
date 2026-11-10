# 04 · Users & Groups

> **Level:** Advanced · **Sections:** §15–§16
>
> System administration with `sudo`: creating and inspecting groups, adding users safely with `usermod -aG`, and why new memberships don't show up until the next login.

[← Text Processing](03-text-processing.md) · [🏠 Home](../README.md) · [Permissions & Ownership →](05-permissions-and-ownership.md)

---

## Contents

- **§15** — [Creating and Inspecting Groups (`groupadd`, `getent`)](#15-creating-and-inspecting-groups)
- **§16** — [Adding Users to Groups (`usermod -aG`)](#16-adding-users-to-groups-usermod--ag)

---

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
sudo groupmod -n data_eng dataengineers   # rename a group
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

> ⚠️ **Never run `usermod -G` without `-a`.** `sudo usermod -G dataengineers shaq` *replaces* all of shaq's supplementary groups, removing that account from `sudo`. You can lose admin rights on your own machine.

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

[← Text Processing](03-text-processing.md) · [🏠 Home](../README.md) · [Permissions & Ownership →](05-permissions-and-ownership.md)
