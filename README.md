# tagless.yazi

Bring [Tagless](https://github.com/TU0801/tagless)'s **multi-axis filename
parser** into [Yazi](https://github.com/sxyazi/yazi).

Press `T` on a folder in Yazi → suspend Yazi → Tagless TUI takes over with
parsed columns (顧客 / 案件 / 日付 / 種類 ...), drill-down tree, and live
filtering. Pick a file with `Enter` → return to Yazi at that file. Press
`q` to cancel and stay where you were.

```text
┌─ Yazi ───────────────────────────────────┐         ┌─ tagless-tui ──────────────────────────────────┐
│ ▶ docs/                                  │  T  →   │ Filter:                                         │
│   reports/                               │         ├──Tree──┬──Files─────────────────────────────────┤
│   contracts/                             │         │ 顧客A  │ 階層1 階層2 階層3 項目1 項目2 ファイル名 │
│   invoices/                              │         │ 顧客B  │ 顧客A 案件X 24-01 請求書 ...  請求書.pdf│
│                                          │         │ 顧客C  │ 顧客A 案件X 24-02 契約書 ...  契約書.pdf│
└──────────────────────────────────────────┘         └────────┴──────────────────────────────────────┘
                                                                                     ↓ Enter
                                          Yazi reveals: docs/顧客A/案件X/24-01/請求書.pdf
```

## Why

Yazi already shows `ls`-style listings beautifully. Tagless complements it by
**reading naming conventions you already follow** (e.g.
`顧客A_案件X_2024-01_請求書.pdf` or `docs/customer-A/project-X/`) and turning
them into queryable columns — without making you tag anything by hand.

Use Yazi for navigation. Hop into Tagless when you need "show me everything
matching `顧客=A AND 種類=請求書` across this whole tree" — without `find -name`,
without grep, without writing a script.

## Install

### 1. Install the `tagless-tui` binary

```bash
# Homebrew (recommended)
brew install TU0801/tap/tagless-tui

# Or download a release binary from
# https://github.com/TU0801/tagless-releases/releases
```

Verify:

```bash
tagless-tui --version
```

### 2. Install the plugin

```bash
ya pack -a TU0801/tagless.yazi
# (or copy this directory to ~/.config/yazi/plugins/tagless.yazi/)
```

### 3. Bind a key

Add to `~/.config/yazi/keymap.toml`:

```toml
[manager]
prepend_keymap = [
  { on = "T", run = "plugin tagless", desc = "Open in Tagless" },
]
```

(Optional) configure plugin defaults in `~/.config/yazi/init.lua`:

```lua
require("tagless"):setup({
  -- bin       = "/opt/homebrew/bin/tagless-tui",  -- override binary path
  -- preset    = "顧客別",                          -- shared with GUI/CLI
  -- recursive = true,                              -- pass --no-recursive when false
})
```

## Behavior

- **`T`** in Yazi:
  1. If the cursor is on a directory, that directory becomes the Tagless root.
  2. Otherwise the current cwd is used.
  3. Yazi suspends, `tagless-tui --emit-chosen` takes the terminal.
- **Inside Tagless** (see [main TUI docs](https://github.com/TU0801/tagless#tui)):
  - `Tab` cycles focus between tree and list.
  - `/` filters by substring.
  - `Enter` on a file → exits and returns the path to Yazi.
  - `q` exits without selecting; Yazi stays put.
  - `F2` rename, `Del` trash, `r` rescan — all changes are reflected in Yazi
    after return.

## Shared configuration

Presets created in the Tagless GUI live at:

- macOS: `~/Library/Application Support/com.tagless.app/presets.json`
- Linux: `~/.config/com.tagless.app/presets.json`
- Windows: `%APPDATA%\com.tagless.app\presets.json`

The plugin will load them via `--preset NAME` if you set `preset` in `setup()`,
so a workflow defined once in the GUI works in Yazi too.

## Troubleshooting

- **"Failed to spawn tagless-tui"**: the binary isn't on `$PATH`. Either
  install it (see above) or pass an absolute path via `setup({ bin = "..." })`.
- **Garbled terminal after Tagless exits**: should not happen — the plugin
  pipes only stdout and lets stdin/stderr pass through. If it does, file an
  issue with your terminal emulator and Yazi version.
- **Yazi doesn't reveal the chosen file**: the chosen path was empty (you
  pressed `q`) or the file no longer exists. Try running
  `tagless-tui <dir> --emit-chosen` directly to confirm the picker works.

## Architecture

`init.lua` is intentionally small: it just spawns the standalone `tagless-tui`
binary and parses the chosen path off stdout. All scanning, parsing, file
operations, and rendering live in the [Tagless](https://github.com/TU0801/tagless)
project itself, shared by the GUI, CLI, and TUI. This means:

- Updates to Tagless improve the Yazi experience automatically.
- The plugin works with any future Yazi versions that keep `Command:spawn`
  semantics stable.
- You can use the same picker from `lf`, `nnn`, vim, neovim, or shell scripts
  — just call `tagless-tui --emit-chosen` and read stdout.

## License

MIT
