# Test Java
## Why the plugin?
This plugin was born from the idea that I couldn't use the [neotest-java](https://github.com/rcasia/neotest-java/issues/127#issue-2425621346) plugin, so I came up with the idea of creating my own plugin that does what I want.

# Usage
This plugin when installed will enable 2 commands:
```
:MavenTestCurrentFile --> This command will run the tests for the entire file in which this.
:MavenTestAtCursor --> This command will execute the test where the cursor is located.
:MavenTestAtCursorDetail -> This command will execute the MavenTestAtCursor command in the terminal
```

# Keymaps
``` lua
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
```

# Photos of results

## Running
![Running](https://imgur.com/ZKaGPj0.png)

An icon will be displayed at the beginning of running the commands (MavenTestAtCursor, MavenTestCurrentFile) to let you know that it has started.

## Success
![Success](https://imgur.com/uHy96Ik.png)

If the test passes the test this icon will be displayed and will show the notification

![Notification](https://imgur.com/JWXZtex.png)

## Error
![Error](https://imgur.com/fKZjM34.png)

If the test fails, this icon will be displayed and will show where the test failed.

![Error Details](https://imgur.com/1et2Nxf.png)
