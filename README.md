# nvim-search-rules

## What is it

nvim-search-rules is a neovim plugin/library refining code search results. 
This library helps move glob-based file exclusion rulesets (IE: .gitignore) into their respective projects and out of your global neovim config.

nvim-search-rules supports the following operations:
1. recursively searching your project for glob-based ruleset files
2. layering rulesets from different files with overriding precedence. 
3. applying / defining global ignore rules for all projects


nvim-search-rules has been built primarily for use with ripgrep `rg`. 
However, the configuration is generic enough that glob rules can be built and used with any file searching tool.

## Installation

Here is how you can install nvim-search-rules using `packer`:
```lua
  use { 'napisani/nvim-search-rules' }
```


Here is how you can install nvim-search-rules using `lazy.nvim`
```lua
  { 'napisani/nvim-search-rules' }
```

## Configuration + Usage

There are two primary functions exposed by the nvim-search-rules module, both of which take same configuration options parameter.

The two primary functions for building glob rules are: 
`get_ignore_globs(config)` - returns a list of raw globs, intended to be used with any search tool 
`get_ignore_globs_as_rg_args(config)` - returns a list of `--iglob <X>` arguments intended to be passed to `rg`

Both of these functions take a configuration object  as a parameter:

```lua
local function find_files_with_name(name, root_dir)
	if not root_dir then
		root_dir = vim.fn.getcwd()
	end
	local files = {}
	for _, file in ipairs(vim.fn.split(vim.fn.system("rg --glob " .. name .. ' --files "' .. root_dir .. '"'))) do
		table.insert(files, file)
	end
	return files
end

local config_opts = {
  -- A list of files to search recursively within any project.
  -- Ignore rules in the latter files take precedence over the former files.
  -- For example, if .gitignore has a global rule like `*.env` but 
  -- .nvimignore has a rule like `!*.env`, then all .env files 
  -- will be INCLUDED in the search. (.nvimignore has the ability 
  -- to negate the glob rules in .gitingnore files because they are defined second in the list)
  -- (Optional), Default = { '.gitignore', '.nvimignore' }
  ignore_from_files = { 
    ".gitignore", 
    ".nvimignore" 
  },

  -- These are any globs to include regardless of what is found in any of the `ignore_from_files` files. 
  -- In other words, any rules defined here will always be ignored from searches.
  -- (Optional), Default = {}
  additional_ignore_globs = { "node_modules", ".git", "dist", ".idea", ".vscode" },

  -- This is the absolute path to the root of the project. 
  -- (Optional), Default = the current working directory - IE: the result of `vim.fn.getcwd()`
	root_dir = vim.fn.getcwd() 

  -- This is the absolute path to the current working directory.
  -- In other words, the directory where the search will be initiated from.
  -- (Optional), Default = the current working directory - IE: the result of `vim.fn.getcwd()`
  cwd = vim.fn.getcwd() 
 
  -- This is a function that takes a filename and the absolute path to the root of the project and returns a 
  -- list containing absolute paths to all files found with that filename recursively within the project directory.
  -- This option is primarily provided for anyone NOT using `rg`. If you are using `rg` 
  -- you shouldn't need to define this configuration key.
  find_files_with_name = find_files_with_name 
}

search_rules = require('nvim-search-rules')

-- returns a list of arguments that can be passed directly to `rg`
iglob_args_for_rg = search_rules.get_ignore_globs_as_rg_args(config)

```


## End-to-end example

This example is using `telescope` but `telescope` is NOT a requirement for using nvim-search-rules. This is just a real world example of how this library can be used.


```lua
local search_rules = require("nvim-search-rules")
local ignore_globs = search_rules.get_ignore_globs_as_rg_args({
  -- search these files in the project to define all project-specific rules
	ignore_from_files = { ".gitignore", ".nvimignore" },
  -- always ignore these files
  additional_ignore_globs = { 
    "node_modules",
    ".git", 
    "dist", 
    ".idea", 
    ".vscode" 
  }
})

local builtin = require("telescope.builtin")

function find_files_from_root(opts)
	opts = opts or {}
	opts.find_command = 
		search_rules.table_merge({
			"rg",
			"--files",
			"--hidden",
			"--no-ignore", -- add this flag so we can control it with our own ignore rules 
		}, ignore_globs)
	builtin.find_files(opts)
end

function live_grep_from_root(opts)
	opts = opts or {}
	opts.vimgrep_arguments = utils.table_merge({
			"rg",
			"--color=never",
			"--no-heading",
			"--with-filename",
			"--line-number",
			"--column",
			"--smart-case",
			"--no-ignore", -- add this flag so we can control it with our own ignore rules 
			"--hidden", 
		}, ignore_globs)

	builtin.live_grep(opts)
end

-- search for files by name
vim.keymap.set("n", "<leader>ft", find_files_from_root, {})
-- search for files by grep'ing contents
vim.keymap.set("n", "<leader>fh", live_grep_from_root, {})
```
