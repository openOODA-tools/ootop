# AGENTS.md - openOODA House Laws (v1)

> **The laws of this codebase are absolute.** Every agent operating on `ootop` MUST comply with these rules.

---

## 1. Zero Ambient Authority & Capability Discipline

- **No ambient I/O.** Code MUST NOT read files, inspect environment variables, execute processes, or query system clocks without explicit capability tokens passed from callers.
- **Allowed capabilities:**
  - `&FsReadCap`: for virtual procfs inspection (`/proc/stat`, `/proc/meminfo`, `/proc/diskstats`, `/proc/net/dev`, `/proc/[pid]`).
  - `&EnvCap`: for terminal geometry (`COLUMNS`, `LINES`) and theme discovery (`OODA_THEME`).
  - `&TimeCap`: for sampling cadence and refresh intervals via `chrono_sleep_ms` or `sleep_ms`.
- **Forbidden:** Ambient filesystem, ambient clock, ambient networking, ambient process execution, ambient mutation.
- **Forbidden:** `/bin/sh -c` invocations. Pure native logic only.

---

## 2. Page Rule & Sizing Law

- **Every `.oo` and `.oot` page MUST be between 16 and 256 lines.**
- **Floor (16 lines):** Shims that only import and re-export are exempt from the floor. All logic pages must meet or exceed 16 lines.
- **Ceiling (256 lines):** Hard limit. Any file exceeding 256 lines is a build violation and will fail verification.
- **Directory Density:** At most **8 pages per directory**. Decompose into subdomains when density exceeds 8.

---

## 3. Four-Element Academy Header

Every `.oo` file MUST begin with the canonical 4-element Academy header in its first 7 lines:

```openooda
// # Name - Subtitle
//
// Logline: Single-sentence summary of the page's purpose.
//
// Setup: Preconditions, capability requirements, and dependencies.
//
// Beats:
//   1. First major step or responsibility.
//   2. Second major step or responsibility.
//   3. Third major step or responsibility.
```

---

## 4. Systemd-Native Citizenship

This repository adheres to the organization's pure systemd-native architectural pattern:
- **Slice Awareness:** First-class awareness of systemd slices (`system.slice`, `user.slice`, `app.slice`) via cgroup v2.
- **Drop-in Overrides:** System services use `/etc/systemd/system/`.
- **Declarative Accounts:** `systemd-sysusers` in `/etc/sysusers.d/*.conf`.
- **Declarative Tmpfiles:** `systemd-tmpfiles` in `/etc/tmpfiles.d/*.conf`.
- **Journal Integration:** Structured logging for systemd journald.

---

## 5. Tri-Distribution Packaging Parity

Packaging parity is maintained across:
- **Fedora / RHEL / CentOS:** RPM spec (`packaging/ootop.spec`).
- **Arch Linux:** PKGBUILD (`packaging/arch/PKGBUILD` and `packaging/PKGBUILD`) producing `.pkg.tar.zst`.
- **Debian / Ubuntu:** Packaging directory (`packaging/debian/`) with `control.binary`, `control`, `changelog`, `copyright`, `rules`.
- **Universal Installer:** `install.sh` supporting `--dnf`, `--deb`, `--arch`, `--dry-run`, and `--uninstall`.
- **Clean Uninstaller:** Companion `uninstall.sh` and `<tool>-uninstall` script.

---

## 6. Domain Architecture & Responsibilities

Work lands in exactly one domain at a time:

| Domain | Responsibility | Does NOT Do |
|---|---|---|
| `proc/` | Parses `/proc/stat`, `/proc/meminfo`, `/proc/diskstats`, `/proc/net/dev`, `/proc/[pid]` | Layout dashboard or handle ANSI formatting |
| `systemd/` | Inspects cgroup slice boundaries (`system.slice`, `user.slice`, `app.slice`) | Read raw proc files or format CLI flags |
| `ui/` | Renders ASCII sparklines, meter bars, emotional mascot moods, and layout grid | Handle file parsing or IPC |
| `render/` | Theme resolution via `oote`, terminal ANSI escapes, cursor positioning | Direct OS queries |
| `ipc/` | Flag parsing (`-b`, `-d`, `-n`, `--mcp`) and MCP stdio server (`system_metrics`, etc.) | Direct dashboard layout |

---

## 7. Verification & QA Gate

Before any commit or release is certified, the entire codebase must pass the automated verification gate:

1. **`make line-cap`**: Hard verification of 16-256 lines per file.
2. **`make file-law`**: Rejection of forbidden file extensions and stray documents.
3. **`make academy`**: Verification of the 4-element Academy header in the first 7 lines.
4. **`make density`**: Verification of $\le 8$ pages per directory.
5. **`make check`**: Full syntax and semantic verification via `oodac check` across all pages.
6. **`make verify`**: Orchestrates all verification checks. Red pages fail the build.
