local M = {}

-- Crear un namespace para los diagnósticos
local namespace_id = vim.api.nvim_create_namespace("test-java")

-- Definir signos para éxito, error y en ejecución
vim.fn.sign_define("MavenTestSuccess", { text = "", texthl = "SuccessMsg", numhl = "" })
vim.fn.sign_define("MavenTestError", { text = "", texthl = "ErrorMsg", numhl = "" })
vim.fn.sign_define("MavenTestRunning", { text = "", texthl = "WarningMsg", numhl = "" })

-- Function to get the name and line of the current Java test function
local function get_current_test_function()
	local cursor_pos = vim.api.nvim_win_get_cursor(0)
	local line_num = cursor_pos[1]
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

	for i = line_num, 1, -1 do
		local func_name = lines[i]:match("^%s*[%w_%s]+%s+void%s+([%w_]+)%s*%(")
		if func_name then
			return func_name, i - 1 -- Return function name and line number (0-based)
		end
	end
	return nil, nil
end

-- Function to clear previous signs for a specific line or the entire buffer
function M.clear_signs(bufnr, line_num)
	if line_num then
		-- Clear signs only on the specified line
		vim.fn.sign_unplace("test-java", { buffer = bufnr, lnum = line_num })
	else
		-- Clear all signs for the namespace in the buffer
		vim.fn.sign_unplace("test-java", { buffer = bufnr })
	end
end

-- Function to get the name and line of all Java test functions in the current file
local function get_all_test_functions()
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	local test_functions = {}
	for i, line in ipairs(lines) do
		local func_name = line:match("^%s*[%w_%s]+%s+void%s+([%w_]+)%s*%(")
		if func_name then
			table.insert(test_functions, { name = func_name, line = i - 1 }) -- Collect function name and line number (0-based)
		end
	end
	return test_functions
end

-- Function to show signs (success, error or running) based on state
local function show_signs(bufnr, line_num, state)
	-- Clear any existing signs on the line
	M.clear_signs(bufnr, line_num + 1)
	if state == "success" then
		vim.fn.sign_place(0, namespace_id, "MavenTestSuccess", bufnr, { lnum = line_num + 1, priority = 10 })
	elseif state == "error" then
		vim.fn.sign_place(0, namespace_id, "MavenTestError", bufnr, { lnum = line_num + 1, priority = 10 })
	elseif state == "running" then
		vim.fn.sign_place(0, namespace_id, "MavenTestRunning", bufnr, { lnum = line_num + 1, priority = 10 })
	end
end

-- Function to get the root of the project
local function get_project_root()
	local root_dir = vim.fn.finddir(".git/..", vim.fn.expand("%:p:h") .. ";")
	if root_dir == "" then
		root_dir = vim.fn.getcwd()
	end
	return root_dir
end

-- Function to run Maven tests for the current file
function M.run_current_file_tests()
	local current_file_name = vim.fn.expand("%:t:r")

	-- Check if the current file is a Java test file
	if not vim.fn.expand("%:p"):match(".*%.java$") then
		print("This is not a Java file.")
		return
	end

	-- Command to run Maven tests for the current file using mvn
	local cmd = "clear && mvn test -Dtest=" .. current_file_name

	-- Open terminal and execute command
	vim.cmd("TermExec direction=float cmd='" .. cmd .. "'")
end

-- Function to run Maven test for the function under the cursor
function M.run_test_at_cursor()
	local bufnr = vim.api.nvim_get_current_buf()
	local current_file_name = vim.fn.expand("%:t:r")
	local current_function_name, line_num = get_current_test_function()
	local project_root = get_project_root()

	-- Clear previous signs for the entire buffer before running the test
	M.clear_signs(bufnr)

	-- Check if the current file is a Java test file
	if not vim.fn.expand("%:p"):match(".*%.java$") then
		print("This is not a Java file.")
		return
	end

	if not current_function_name then
		print("No test function found under the cursor.")
		return
	end

	local all_errors = {}
	local errorMessage = ""

	-- Show running sign
	show_signs(bufnr, line_num, "running")

	-- Command to run Maven tests for the current function using mvn
	local cmd = {
		"mvn",
		"test",
		"-q",
		"-Dtest=" .. current_file_name .. "#" .. current_function_name,
	}

	-- Run the command asynchronously
	vim.fn.jobstart(cmd, {
		cwd = project_root,
		stdout_buffered = true,
		stderr_buffered = true,
		on_stdout = function(_, data)
			if data then
				for _, line in ipairs(data) do
					if line:match("^%[ERROR%]%s%s%s+") then
						errorMessage = line
					end
				end
			end
		end,
		on_stderr = function(_, data)
			if data then
				for _, line in ipairs(data) do
					if line:match("^%[ERROR%]%s+") then
						table.insert(all_errors, line)
					end
				end
			end
		end,
		on_exit = function(_, exit_code)
			-- Clear running sign before setting the final status
			M.clear_signs(bufnr, line_num + 1)
			if exit_code == 0 then
				show_signs(bufnr, line_num, "success")
				vim.api.nvim_echo({ { "Test executed successfully", "SuccessMsg" } }, false, {})
			else
				show_signs(bufnr, line_num, "error")
				if #all_errors > 0 then
					vim.api.nvim_echo({ { table.concat(all_errors, "\n"), "ErrorMsg" } }, false, {})
				else
					vim.api.nvim_echo({ { errorMessage, "ErrorMsg" } }, false, {})
				end
			end
		end,
	})
end

-- Setup function to define the commands and key mappings
function M.setup()
	vim.api.nvim_create_user_command("MavenTestCurrentFile", function()
		M.run_current_file_tests()
	end, { nargs = 0 })

	vim.api.nvim_create_user_command("MavenTestAtCursor", function()
		M.run_test_at_cursor()
	end, { nargs = 0 })
end

return M
