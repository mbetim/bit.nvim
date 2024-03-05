# Bit.nvim

Inspired by the [gh](https://github.com/cli/cli) CLI from GitHub and the [octo.nvim](https://github.com/pwntester/octo.nvim) plugin, Bit.nvim is a neovim plugin designed to interact with Bitbucket repositories.

**Note:** so far the plugin can only lists the Pull Requests for the current repo.

## Installation

Use your plugin manager of choice. Here's an example using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{ "mbetim/bit.nvim" }
```

The plugin uses [telescope](https://github.com/nvim-telescope/telescope.nvim) as the picker to list the PRs, so you'll need to have it installed as well.

## Configuration

During the first use of the Bit plugin, it'll prompt you for your Bitbucket auth token, which it is required to fetch the PR data. The prompt is designed to securely handle your credentials.

## Usage

You can list the PRs of the current Bitbucket repository by using the following neovim command:

```lua
:lua require("bit-nvim").list_prs()

-- which can be mapped to something like:
vim.keymap.set("n", "<leader>sp", require("bit-nvim").list_prs)
```

This will open the list of PRs in a Telescope picker. You can navigate through the list with your telescope keymaps.

Use `enter` to checkout the branch of a PR, and `<c-o>` to open the PR in a browser.
