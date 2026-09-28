# OS detection

`scripts/detect-os.sh` defines `detect_os`, used by `bootstrap.sh` as:

```bash
OS="$(detect_os || true)"
```

## Contract

- Prints **exactly one token on stdout**: `macos` or `arch` — the output is captured, so nothing else may be written there.
- Diagnostics go to **stderr** only.
- Returns non-zero with empty stdout for anything unsupported → bootstrap dies with `Unsupported OS. Supported: arch, macos`.
- Sourcing the file only defines functions; running it directly (`bash scripts/detect-os.sh`) prints the result.

## Decision tree

```
uname -s
├── Darwin → "macos"
├── Linux  → read os-release (default /etc/os-release)
│     ├── ID == "arch"                    → "arch"
│     ├── ID_LIKE contains word "arch"    → "arch"   (Manjaro, EndeavourOS)
│     ├── ID empty AND pacman on PATH     → "arch"   (fallback)
│     └── otherwise                       → stderr diag, rc 1
└── anything else                         → stderr diag "unsupported kernel", rc 1
```

## Implementation notes

- **Parsed, not sourced.** `/etc/os-release` is read line-by-line by `_os_release_value` (pure bash, no `grep`/`sed` forks, no executing a file from disk). Quotes around values are stripped.
- **The missing-`ID_LIKE` trap.** Plain Arch's os-release has no `ID_LIKE` line, so the lookup returns non-zero. Without the `|| true` on those assignments, the command substitution would trip `set -e` *inside* `$(detect_os || true)` and bootstrap would report "Unsupported OS" on Arch itself.
- **Word match, not substring.** `ID_LIKE="fedora centos"` is tested as `" $id_like " == *" arch "*`, so unrelated values containing "arch" as a fragment don't match.

## Testing hook

```bash
OS_RELEASE_FILE=/tmp/fake-arch bash scripts/detect-os.sh
```

`OS_RELEASE_FILE` overrides the os-release path. Combined with a stubbed `uname` on `PATH`, this is how the distro branches are tested on any host — see [development.md](development.md).

## Related

- [bootstrap.md](bootstrap.md) — where detection sits in the flow
- [packages.md](packages.md) — what runs for each detected OS
