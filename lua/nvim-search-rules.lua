local M = {}

-- trim whitespace before and after the string 
local function trim(s)
	return s:gsub("^%s+", ""):gsub("%s+$", "")
end
local function clean_glob(glob)
	-- remove comments
	glob = glob:gsub("#.*", "")
	glob = trim(glob)
	if glob == "" then
		return nil
	end
	return glob
end

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
local function is_a_negated_glob(glob)
	return glob:sub(0, 1) == "!"
end
local unnegate_glob = function(glob)
	return glob:sub(2)
end

local function prefix_glob_with_path(path, glob)
	local negate = false
	if is_a_negated_glob(glob) then
		negate = true
		glob = glob:sub(2)
	end
	local result = path .. "/" .. glob
	result = result:gsub("//", "/")
	if negate then
		result = "!" .. result
	end
	return result
end
local function basename(path, filename)
	return path.sub(path, 0, path.len(path) - path.len(filename))
end
local function remove_path_prefix_from_glob(path, glob)
	path = path .. "/"
	path = path:gsub("//", "")
	local negate = false
	if is_a_negated_glob(glob) then
		negate = true
		glob = glob:sub(2)
	end
	local result = glob:sub(path:len() + 1)
	if negate then
		result = "!" .. result
	end
	return result
end

local function get_ignore_globs_for_path_and_name(ignore_file_path, ignore_file)
	local ignore_globs = {}
	local ignore_file_contents = vim.fn.readfile(ignore_file_path)
	for _, ignore_glob in ipairs(ignore_file_contents) do
		ignore_glob = clean_glob(ignore_glob)
		if ignore_glob then
			local base_path = basename(ignore_file_path, ignore_file)
			if base_path ~= "" then
				ignore_glob = prefix_glob_with_path(base_path, ignore_glob)
			end
			table.insert(ignore_globs, ignore_glob)
		end
	end
	return ignore_globs
end

local function is_exists_in_set(set, value)
	return set[value] == true
end
local function get_ignore_globs_for_filename(ignore_file, root_dir)
	local ignore_globs = {}
	local ignore_file_paths = find_files_with_name(ignore_file, root_dir)
	for _, ignore_file_path in ipairs(ignore_file_paths) do
		local ignore_globs_for_path = get_ignore_globs_for_path_and_name(ignore_file_path, ignore_file)
		for _, ignore_glob in ipairs(ignore_globs_for_path) do
			table.insert(ignore_globs, ignore_glob)
		end
	end
	return ignore_globs
end
local function get_relative_path_from_root(root_dir, path)
	local relative_path = path:sub(root_dir:len() + 1)
	if relative_path:sub(0, 1) == "/" then
		relative_path = relative_path:sub(2)
	end
	return relative_path
end

---@class Config
---@field ignore_from_files table of strings - the names of files with ignore glob definitions, in order they should be applied
---@field root_dir string - the root directory to search for ignore files - typically the project root. If not provided, the cwd will be used
---@field cwd string - the directory where the search should be performed - the default will be the vim.fn.getcwd()
---@field additional_ignore_globs table of string - globs that should always be ignored, regardless of the ignore files

local Config = {}
M.get_ignore_globs = function(config)
  local additional_ignore_globs = config.additional_ignore_globs or {}
	local ignore_from_files = config.ignore_from_files
	if not ignore_from_files then
		ignore_from_files = { ".gitignore", ".nvimignore" }
	end
	local cwd = config.cwd
	if not cwd then
		cwd = vim.fn.getcwd()
	end
	local root_dir = config.root_dir
	if not root_dir then
		root_dir = cwd
	end
	local ignore_globs = {}
	for _, ignore_file in ipairs(ignore_from_files) do
		local ignore_globs_for_file = get_ignore_globs_for_filename(ignore_file, root_dir)
		for _, ignore_glob in ipairs(ignore_globs_for_file) do
			if is_a_negated_glob(ignore_glob) then
				local unnegated_glob = unnegate_glob(ignore_glob)
				if is_exists_in_set(ignore_globs, unnegated_glob) then
					ignore_globs[unnegated_glob] = false
				end
			else
				ignore_globs[ignore_glob] = true
			end
		end
	end
	local final_ignore_globs = {}
	local relative_path = get_relative_path_from_root(root_dir, cwd)
	for glob, should_ignore in pairs(ignore_globs) do
		if should_ignore then
			local glob_without_path = remove_path_prefix_from_glob(root_dir, glob)
			if trim(relative_path) ~= "" then
				glob_without_path = remove_path_prefix_from_glob(relative_path, glob_without_path)
			end
			table.insert(final_ignore_globs, glob_without_path)
		end
	end
  for _, ignore_glob in ipairs(additional_ignore_globs) do
    table.insert(final_ignore_globs, ignore_glob)
  end

	return final_ignore_globs
end
M.get_ignore_globs_as_rg_args = function(config)
	local ignore_globs = M.get_ignore_globs(config)
	local ignore_globs_as_rg_args = {}
	for _, ignore_glob in ipairs(ignore_globs) do
		table.insert(ignore_globs_as_rg_args, "--iglob")
		table.insert(ignore_globs_as_rg_args, "!" .. ignore_glob)
	end
	return ignore_globs_as_rg_args
end

return M
