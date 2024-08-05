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

	for i = line_num, #lines do
		local func_name = lines[i]:match("^%s*[%w_%s]+%s+void%s+([%w_]+)%s*%(")
		if func_name then
			return func_name, i - 1 -- Return function name and line number (0-based)
		end
	end
	return nil, nil
end

function M.get_class_and_method()
	-- Obtener el buffer actual
	local buf = vim.api.nvim_get_current_buf()

	-- Obtener el contenido del buffer
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

	local class_name = ""
	local method_name = ""

	-- Buscar el nombre de la clase
	for _, line in ipairs(lines) do
		local class_match = line:match("public%s+class%s+(%w+)")
		if class_match then
			class_name = class_match
			break
		end
	end
	-- Buscar el nombre del método en la línea actual
	local current_line = vim.api.nvim_get_current_line()
	local method_match = current_line:match("void%s+(%w+)%s*%(")
	if method_match then
		method_name = method_match
	end

	return class_name, method_name
end

-- Function to clear previous signs for a specific line or the entire buffer
function M.clear_signs(bufnr, line_num)
	if line_num then
		-- Clear signs only on the specified line
		vim.api.nvim_buf_clear_namespace(bufnr, namespace_id, line_num, line_num + 1)
	else
		-- Clear all signs for the namespace in the buffer
		vim.api.nvim_buf_clear_namespace(bufnr, namespace_id, 0, -1)
	end
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
	local all_errors = {}

	-- Limpiar signos previos para todo el buffer antes de ejecutar la prueba
	vim.schedule(function()
		M.clear_signs(bufnr)
	end)

	-- Verificar si el archivo actual es un archivo de prueba Java
	if not vim.fn.expand("%:p"):match(".*%.java$") then
		print("This is not a Java file.")
		return
	end

	if not current_function_name then
		print("No test function was found under the cursor.")
		return
	end

	-- Mostrar signo de ejecución
	vim.schedule(function()
		show_signs(bufnr, line_num, "running")
	end)

	-- Comando para ejecutar pruebas de Maven en la función actual usando mvn
	local cmd = {
		"mvn",
		"test",
		"-q",
		"-Dtest=" .. current_file_name .. "#" .. current_function_name,
	}

	-- Ejecutar el comando de manera asíncrona usando vim.system
	vim.system(cmd, { cwd = project_root }, function(obj)
		local exit_code = obj.code
		local stdout = obj.stdout

		-- Asegurarse de que stderr sea una cadena
		if type(stdout) == "string" then
			-- Procesar stderr para capturar mensajes de error
			for _, line in ipairs(vim.split(stdout, "\n")) do
				print(line)
				if line:match("^%[ERROR%]%s%s%s%S") and line:match("expected:%s<.*>%s*but was:%s<.*>") then
					table.insert(all_errors, line)
				elseif line:match("^Wanted%s[%d]+%stime[s]?[:]") then
					table.insert(all_errors, line)
				elseif line:match("^But%swas%s[%d]+%stime[s]?[:]") then
					table.insert(all_errors, line)
				end
			end
		end

		-- Limpiar signo de ejecución antes de establecer el estado final
		vim.schedule(function()
			M.clear_signs(bufnr, line_num + 1)
			if exit_code == 0 then
				show_signs(bufnr, line_num, "success")
				vim.api.nvim_echo({ { "Test executed successfully", "SuccessMsg" } }, false, {})
			else
				show_signs(bufnr, line_num, "error")
				if #all_errors > 0 then
					vim.api.nvim_echo({ { table.concat(all_errors, "\n"), "ErrorMsg" } }, false, {})
				else
					vim.api.nvim_echo({ { "Test failed", "ErrorMsg" } }, false, {})
				end
			end
		end)
	end)
end

-- Function to run Maven test for the function under the cursor details
function M.run_test_at_cursor_details()
	local class_name, current_function_name = M.get_class_and_method()

	if class_name == "" or current_function_name == "" then
		print("The name of the class or method could not be obtained.")
		return
	end

	-- Check if the current file is a Java test file
	if not vim.fn.expand("%:p"):match(".*%.java$") then
		print("This is not a Java file.")
		return
	end

	-- Command to run Maven tests for the current function using mvn
	local command = string.format("clear && mvn test -q -Dtest=%s#%s", class_name, current_function_name)

	-- Open terminal and execute command
	vim.cmd("TermExec direction=float cmd='" .. command .. "'")
end

-- Setup function to define the commands and key mappings
function M.setup()
	vim.api.nvim_create_user_command("MavenTestCurrentFile", function()
		M.run_current_file_tests()
	end, { nargs = 0 })

	vim.api.nvim_create_user_command("MavenTestAtCursor", function()
		M.run_test_at_cursor()
	end, { nargs = 0 })

	vim.api.nvim_create_user_command("MavenTestAtCursorDetail", function()
		M.run_test_at_cursor_details()
	end, { nargs = 0 })

	vim.api.nvim_set_keymap("n", "<Leader>t", "", { noremap = true, silent = true, desc = " Test" })
	vim.api.nvim_set_keymap(
		"n",
		"<Leader>tm",
		":lua require('test-java').run_test_at_cursor()<CR>",
		{ noremap = true, silent = true, desc = " Test Method" }
	)
	vim.api.nvim_set_keymap(
		"n",
		"<Leader>tf",
		":lua require('test-java').run_current_file_tests()<CR>",
		{ noremap = true, silent = true, desc = " Test File" }
	)
	vim.api.nvim_set_keymap(
		"n",
		"<Leader>td",
		":lua require('test-java').run_test_at_cursor_details()<CR>",
		{ noremap = true, silent = true, desc = " Detail Test" }
	)
end

return M
