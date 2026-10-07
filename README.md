# ootop

> **Sovereign real-time system monitor and dashboard for the openOODA era.**  
> *A drop-in `btop` / `top` replacement written in pure openOODA, featuring negative-trust capability security, systemd slice resource aggregation (`app.slice`, `system.slice`, `user.slice`), ASCII meters, dynamic emotional mascot moods, and a first-class Model Context Protocol (MCP) surface.*

Part of [openOODA-tools](https://github.com/openOODA-tools).

---

## 1. Installation

`ootop` has zero runtime dependencies. It compiles to a standalone native binary linked directly with libc.

### Universal Web Installer
Installs the standalone native binary to `/usr/local/bin` (or `~/.local/bin`):

```bash
curl -fsSL https://openooda-tools.github.io/ootop/install.sh | bash
```

### Debian / Ubuntu (APT)
```bash
# Automated via installer
curl -fsSL https://openooda-tools.github.io/ootop/install.sh | bash -s -- --apt

# Or manual package install
sudo dpkg -i ootop_0.1.0-1_amd64.deb
```

### Fedora / RHEL / CentOS (DNF)
```bash
# Automated via installer
curl -fsSL https://openooda-tools.github.io/ootop/install.sh | bash -s -- --dnf

# Or manual RPM install
sudo dnf install ./ootop-0.1.0-1.x86_64.rpm
```

### Arch Linux (PKGBUILD)
```bash
# Automated via installer
curl -fsSL https://openooda-tools.github.io/ootop/install.sh | bash -s -- --arch

# Or manual build via packaging/PKGBUILD
cd packaging && makepkg -si
```

### Clean Uninstaller
To cleanly remove `ootop` and any installed package manager entries:

```bash
# Automated via standalone uninstaller
curl -fsSL https://openooda-tools.github.io/ootop/uninstall.sh | bash

# Or via installer flag
curl -fsSL https://openooda-tools.github.io/ootop/install.sh | bash -s -- --uninstall

# Or preview removal without making changes (dry-run)
curl -fsSL https://openooda-tools.github.io/ootop/uninstall.sh | bash -s -- --dry-run
```

---

## 2. CLI Usage

```
usage: ootop [options]

Real-time TUI dashboard and system monitor with systemd slice grouping.

Options:
  -b, --batch              run in batch mode (single-shot or iteration-bounded)
  -d, --delay <SEC>        refresh delay in seconds [default: 2]
  -n, --iterations <NUM>   number of refresh cycles before exiting
  -t, --theme <NAME>       override active oote theme palette
      --no-color           disable ANSI color escapes
      --mcp                run as Model Context Protocol stdio server
  -h, --help               display this help and exit
  -v, --version            output version information and exit
```

### Common Examples

```bash
# Launch interactive real-time dashboard
ootop

# Fast 1-second refresh cadence
ootop -d 1

# Batch single-shot output for terminal logging or scripting
ootop -b

# Batch 5 iterations with 2-second delay
ootop -b -n 5 -d 2

# Override active theme
ootop -t dracula
```

---

## 3. Systemd Slice Citizenship

`ootop` natively inspects Linux cgroup v2 hierarchies to aggregate resource footprints by systemd slice:
- **`system.slice`**: System daemons and root system services
- **`user.slice`**: User sessions, interactive shells, and desktop applications
- **`app.slice`**: Containerized and sandboxed application workloads

---

## 4. Theming Integration (`oote`)

`ootop` automatically discovers and synchronizes visual presentation with [oote](https://github.com/openOODA-tools/oote):

- **Configuration File**: Reads `~/.openooda/theme.oot` with `$HOME` fallback.
- **Environment Overrides**: Respects `OODA_THEME` and `--no-color`.
- **Emotional Mascot**: Dynamic mascot art adapts to real-time processor workload:
  - **Calm / Serene** `( ^.^ )`: Optimal load (< 40%)
  - **Active / Vigilant** `( o.o )`: Moderate workload (40% - 75%)
  - **Turbo / Overload** `( >.< )`: High load stress (> 75%)

---

## 5. Model Context Protocol (MCP)

`ootop` includes a built-in JSON-RPC 2.0 MCP server over standard I/O for LLM coding agents:

```bash
ootop --mcp
```

### Supported Tools:
1. `system_metrics`: Ingests and serializes CPU %, core count, memory %, swap %, disk I/O, and network I/O.
2. `process_list`: Inspects active system processes, reporting PID, command, RSS memory footprint, and systemd slice.
3. `systemd_slices`: Aggregates active task counts and memory usage across systemd slice boundaries.

---

## 6. Security & Architecture

- **Zero Ambient Authority**: Written in pure openOODA with capability-bounded tokens (`&FsReadCap`, `&EnvCap`, `&TimeCap`).
- **No Shell Escapes**: Pure native execution without `/bin/sh` invocations.
- **Page Rule & Academy Governance**: 100% compliant with the openOODA Academy and House Laws codified in [`AGENTS.md`](./AGENTS.md).

---

## 7. License

Apache License, Version 2.0. See [`LICENSE`](./LICENSE) for full text.