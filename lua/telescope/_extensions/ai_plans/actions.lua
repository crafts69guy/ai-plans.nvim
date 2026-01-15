-- ai-plans.nvim: Actions module
-- Custom telescope actions for AI plan files

local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local transform_mod = require("telescope.actions.mt").transform_mod

local ap_utils = require("telescope._extensions.ai_plans.utils")

local M = {}

--- Get selected entries (multi-select aware)
--- Returns list of entries: either multi-selected or current selection
---@param prompt_bufnr number Telescope prompt buffer number
---@return table List of selected entries
local get_selected_entries = function(prompt_bufnr)
  local current_picker = action_state.get_current_picker(prompt_bufnr)
  local multi_selections = current_picker:get_multi_selection()

  if #multi_selections > 0 then
    return multi_selections
  end

  -- Fall back to single selection
  local entry = action_state.get_selected_entry()
  return entry and { entry } or {}
end

--- Yank file paths to clipboard
---@param prompt_bufnr number Telescope prompt buffer number
M.yank_paths = function(prompt_bufnr)
  local entries = get_selected_entries(prompt_bufnr)
  if #entries == 0 then
    ap_utils.notify("No files selected", vim.log.levels.WARN)
    return
  end

  local paths = {}
  for _, entry in ipairs(entries) do
    table.insert(paths, entry.path or entry.value)
  end

  local path_str = table.concat(paths, "\n")
  vim.fn.setreg("+", path_str)
  vim.fn.setreg('"', path_str)

  actions.close(prompt_bufnr)
  ap_utils.notify(string.format("Yanked %d path(s) to clipboard", #paths))
end

--- Delete selected files with confirmation
---@param prompt_bufnr number Telescope prompt buffer number
M.delete_files = function(prompt_bufnr)
  local entries = get_selected_entries(prompt_bufnr)
  if #entries == 0 then
    ap_utils.notify("No files selected", vim.log.levels.WARN)
    return
  end

  -- Build confirmation message
  local file_names = {}
  for _, entry in ipairs(entries) do
    table.insert(file_names, vim.fn.fnamemodify(entry.path or entry.value, ":t"))
  end

  local msg = string.format("Delete %d file(s)?\n%s", #entries, table.concat(file_names, "\n"))

  vim.ui.select({ "Yes", "No" }, {
    prompt = msg,
  }, function(choice)
    if choice == "Yes" then
      local deleted = 0
      for _, entry in ipairs(entries) do
        local path = entry.path or entry.value
        local ok, err = os.remove(path)
        if ok then
          deleted = deleted + 1
        else
          ap_utils.notify(string.format("Failed to delete %s: %s", path, tostring(err)), vim.log.levels.ERROR)
        end
      end

      if deleted > 0 then
        ap_utils.notify(string.format("Deleted %d file(s)", deleted))
        -- Refresh the picker
        local current_picker = action_state.get_current_picker(prompt_bufnr)
        if current_picker then
          local ap_finders = require("telescope._extensions.ai_plans.finders")
          current_picker:refresh(ap_finders.finder({}), { reset_prompt = false })
        end
      end
    end
  end)
end

--- Toggle selection and move to next entry
---@param prompt_bufnr number Telescope prompt buffer number
M.toggle_selection_and_next = function(prompt_bufnr)
  actions.toggle_selection(prompt_bufnr)
  actions.move_selection_next(prompt_bufnr)
end

--- Toggle selection and move to previous entry
---@param prompt_bufnr number Telescope prompt buffer number
M.toggle_selection_and_prev = function(prompt_bufnr)
  actions.toggle_selection(prompt_bufnr)
  actions.move_selection_previous(prompt_bufnr)
end

--- Open file in current window
---@param prompt_bufnr number Telescope prompt buffer number
M.open_file = function(prompt_bufnr)
  local entry = action_state.get_selected_entry()
  if not entry then
    return
  end
  actions.close(prompt_bufnr)
  vim.cmd("edit " .. vim.fn.fnameescape(entry.path or entry.value))
end

--- Open file in horizontal split
---@param prompt_bufnr number Telescope prompt buffer number
M.open_in_split = function(prompt_bufnr)
  local entry = action_state.get_selected_entry()
  if not entry then
    return
  end
  actions.close(prompt_bufnr)
  vim.cmd("split " .. vim.fn.fnameescape(entry.path or entry.value))
end

--- Open file in vertical split
---@param prompt_bufnr number Telescope prompt buffer number
M.open_in_vsplit = function(prompt_bufnr)
  local entry = action_state.get_selected_entry()
  if not entry then
    return
  end
  actions.close(prompt_bufnr)
  vim.cmd("vsplit " .. vim.fn.fnameescape(entry.path or entry.value))
end

--- Open file in new tab
---@param prompt_bufnr number Telescope prompt buffer number
M.open_in_tab = function(prompt_bufnr)
  local entry = action_state.get_selected_entry()
  if not entry then
    return
  end
  actions.close(prompt_bufnr)
  vim.cmd("tabedit " .. vim.fn.fnameescape(entry.path or entry.value))
end

--- Refresh the picker
---@param prompt_bufnr number Telescope prompt buffer number
M.refresh = function(prompt_bufnr)
  local current_picker = action_state.get_current_picker(prompt_bufnr)
  if current_picker then
    local ap_finders = require("telescope._extensions.ai_plans.finders")
    current_picker:refresh(ap_finders.finder({}), { reset_prompt = false })
  end
end

return transform_mod(M)
