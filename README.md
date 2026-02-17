# sink.nvim

A Neovim plugin that wraps `rsync` to sync files between your local machine and a remote server. `sink.nvim` is especially useful for developing on remote servers. Rather than installing Neovim on the remote, edit your files locally using your dialed-in Neovim config and then quickly push files up to the server when you are ready to run them. 

## Requirements

- Neovim 0.10+
- `rsync` installed and available on your `$PATH`

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim), pinned to the latest tag:

```lua
{
  "NikolaiLyssogor/sink.nvim",
  tag = "v0.1.0", -- replace with the latest tag
}
```

There are no configuration options for the plugin itself. No `setup()` call is required.

## Configuration

sink.nvim is configured per-project using a `.sink.json` file placed at the **root of your project** (i.e. the directory you open Neovim from). This file is not global. Each project has its own sync configuration.

### `.sink.json` format

```json
{
  "commands": [
    {
      "description": "Sync to production server",
      "default": true,
      "command": [
        "-avz",
        "--delete",
        "--exclude-from", "/home/user/.rsync-exclude",
        "/path/to/local/project/",
        "user@remote-host:/path/to/remote/project/"
      ]
    },
    {
      "description": "Sync to staging server",
      "default": false,
      "command": [
        "-avz",
        "/path/to/local/project/",
        "user@staging-host:/path/to/remote/project/"
      ]
    }
  ]
}
```

**Fields:**

| Field | Type | Required | Description |
|---|---|---|---|
| `description` | string | yes | Human-readable label shown in the command picker |
| `default` | boolean | yes | Whether this is the default command (see below) |
| `command` | array of strings | yes | The arguments passed to `rsync`. Do **not** include `rsync` itself — only the flags and paths |

**Notes:**

- The `command` array contains only the arguments to `rsync`, not the executable itself. For example, `-avz` becomes `["-avz", ...]`.
- Exactly one command must have `"default": true` if you plan to use `Sink default=true`.
- The `.sink.json` file is read from the current working directory when the `Sink` command is invoked, so make sure Neovim is opened from your project root.

## Usage

sink.nvim exposes a single command: `:Sink`.

### `:Sink default=true`

Runs the command marked `"default": true` in your `.sink.json` immediately, without any prompts. Bind it to a keymap for quick syncing.

```lua
vim.keymap.set("n", "<leader>ss", "<cmd>Sink default=true<cr>", { desc = "Sync (default)" })
```

### `:Sink default=false`

Opens a picker (via `vim.ui.select`) listing all commands defined in `.sink.json` by their `description`. Select one and it runs. Useful when you have multiple sync targets and want to choose interactively.

```lua
vim.keymap.set("n", "<leader>sS", "<cmd>Sink default=false<cr>", { desc = "Sync (pick)" })
```

## Example workflow

1. Place a `.sink.json` at the root of your project.
2. Configure one or more rsync commands.
3. Mark your most-used command as `"default": true`.
4. Bind `:Sink default=true` to a convenient keymap.
5. Edit code locally in Neovim, hit your keymap, and the files are synced to the remote.

## Tips

- Use `--exclude-from` to point at a file listing paths to exclude (similar to `.gitignore`). This keeps things like `node_modules` or build artifacts from being synced.
- Use `-avz` for archive mode with verbose output and compression over SSH.
- Add `.sink.json` to your project's `.gitignore` if it contains paths or credentials specific to your local machine.
