--- tagless.yazi -- Yazi <-> Tagless bridge
---
--- This plugin suspends Yazi and launches `tagless-tui` against the cursor's
--- current folder. When the user picks a file inside Tagless (Enter on a
--- file row in --emit-chosen mode), the absolute path is written to stdout
--- and we reveal it in Yazi on return. Pressing `q` in Tagless cancels and
--- leaves Yazi exactly where it was.
---
--- Requirements:
---   - tagless-tui binary on $PATH (see https://github.com/TU0801/tagless#tui)
---
--- Recommended keymap (yazi.toml):
---
---   [manager]
---   prepend_keymap = [
---     { on = "T", run = "plugin tagless",        desc = "Open in Tagless" },
---     { on = "t", run = "plugin tagless filter", desc = "Tagless: filter to picker" },
---   ]
---
--- The default sub-action is the TUI bridge. Pass "filter" to use the CLI
--- spotter mode (planned -- currently behaves the same as the default).

local M = {}

--- Resolve the directory the user wants to open in Tagless.
--- If the cursor is on a folder, use that. Otherwise use the current cwd.
local function target_dir()
  local hovered = cx.active.current.hovered
  if hovered and hovered.cha.is_dir then
    return tostring(hovered.url)
  end
  return tostring(cx.active.current.cwd)
end

--- Locate the tagless-tui binary, allowing override via plugin opts.
local function tui_bin()
  if M._opts and M._opts.bin and #M._opts.bin > 0 then
    return M._opts.bin
  end
  return "tagless-tui"
end

--- Build extra args from plugin options.
--- - opts.preset (string, optional): forwarded as --preset
--- - opts.recursive (bool, default true): false adds --no-recursive
local function extra_args()
  local args = {}
  local opts = M._opts or {}
  if opts.preset and #opts.preset > 0 then
    table.insert(args, "--preset")
    table.insert(args, opts.preset)
  end
  if opts.recursive == false then
    table.insert(args, "--no-recursive")
  end
  return args
end

function M:setup(opts)
  self._opts = opts or {}
end

function M:entry(job)
  local dir = target_dir()
  local args = { dir, "--emit-chosen" }
  for _, a in ipairs(extra_args()) do
    table.insert(args, a)
  end

  -- Yazi suspends its own UI for the duration of this child. stdin/stderr
  -- are inherited so the TUI can render to the real terminal; stdout is
  -- piped so we can read the chosen path on exit.
  local child, err = Command(tui_bin())
    :args(args)
    :stdin(0)
    :stderr(2)
    :stdout(Command.PIPED)
    :spawn()

  if not child then
    return ya.notify({
      title = "Tagless",
      content = "Failed to spawn `" .. tui_bin() .. "`: " .. tostring(err),
      level = "error",
      timeout = 5,
    })
  end

  local output, werr = child:wait_with_output()
  if not output then
    return ya.notify({
      title = "Tagless",
      content = "wait failed: " .. tostring(werr),
      level = "error",
      timeout = 5,
    })
  end

  if not output.status.success then
    return ya.notify({
      title = "Tagless",
      content = "exited with status " .. tostring(output.status.code),
      level = "warn",
      timeout = 4,
    })
  end

  -- Empty stdout = user cancelled (q). Otherwise the first non-empty line is
  -- the absolute path of the chosen file.
  local stdout = output.stdout or ""
  local chosen = stdout:match("([^\n\r]+)")
  if not chosen or #chosen == 0 then
    return
  end

  ya.manager_emit("reveal", { Url(chosen) })
end

return M
