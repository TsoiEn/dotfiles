-- <leader>err (visual): generate error handling for the selected lines.
-- Add a language: put a function in `handlers` keyed by filetype.
local M = {}

local function indent_of(lnum)
	return vim.fn.getline(lnum):match("^%s*")
end

local function unit()
	return vim.bo.expandtab and (" "):rep(vim.fn.shiftwidth()) or "\t"
end

-- Go: insert `if err != nil { return <zeros>, fmt.Errorf("call: %w", err) }` below.
local go_funcs = { function_declaration = true, method_declaration = true, func_literal = true }

local function go_zero(t)
	local txt = vim.treesitter.get_node_text(t, 0)
	if txt == "string" then return '""' end
	if txt == "bool" then return "false" end
	if txt:match("^u?int%d*$") or txt:match("^float%d+$") or txt == "byte" or txt == "rune" then return "0" end
	local nilable = { pointer_type = 1, slice_type = 1, map_type = 1, channel_type = 1, interface_type = 1, function_type = 1 }
	if nilable[t:type()] or txt == "any" then return "nil" end
	return ("*new(%s)"):format(txt) -- shortcut: works for any type but is ugly for structs, hand-edit if wanted
end

-- Returns list of zero values for non-error results, and whether the last result is `error`.
local function go_results(fn)
	local res = fn:field("result")[1]
	if not res then return {}, false end
	local types = {}
	if res:type() == "parameter_list" then
		for _, p in ipairs(res:named_children()) do
			local t = p:field("type")[1]
			local names = #p:field("name")
			for _ = 1, math.max(names, 1) do types[#types + 1] = t end
		end
	else
		types[1] = res
	end
	local zeros, has_err = {}, false
	for i, t in ipairs(types) do
		if i == #types and vim.treesitter.get_node_text(t, 0) == "error" then
			has_err = true
		else
			zeros[#zeros + 1] = go_zero(t)
		end
	end
	return zeros, has_err
end

local function go(_, e)
	local line = vim.fn.getline(e)
	vim.treesitter.get_parser():parse()
	local node = vim.treesitter.get_node({ pos = { e - 1, #indent_of(e) } })
	while node and not go_funcs[node:type()] do node = node:parent() end
	if not node then return vim.notify("errhandle: not inside a function", vim.log.levels.WARN) end

	local lhs = line:match("^%s*(.-)%s*:?=[^=]")
	local err = lhs and lhs:match("([%w_]+)%s*$") or "err"
	local call = line:match("([%w_%.]+)%s*%(") or "failed"
	local zeros, has_err = go_results(node)

	local body
	if has_err then
		zeros[#zeros + 1] = ('fmt.Errorf("%s: %%w", %s)'):format(call, err)
		body = "return " .. table.concat(zeros, ", ")
	elseif #zeros == 0 and not node:field("result")[1] then
		body = "return"
	else
		body = ("panic(%s)"):format(err) -- no error result to return it through
	end

	local ind = indent_of(e)
	vim.api.nvim_buf_set_lines(0, e, e, false, {
		("%sif %s != nil {"):format(ind, err),
		ind .. unit() .. body,
		ind .. "}",
	})
end

-- try/catch style: wrap the selection and indent it.
local function wrap(open, close)
	return function(s, e)
		local ind = indent_of(s)
		local u = unit()
		vim.api.nvim_buf_set_lines(0, e, e, false, vim.tbl_map(function(l) return ind .. l:gsub("^>", u) end, close))
		vim.api.nvim_buf_set_lines(0, s - 1, s - 1, false, { ind .. open })
		vim.cmd(("silent %d,%d>"):format(s + 1, e + 1))
	end
end

local ts = wrap("try {", { "} catch (err) {", ">console.error(err);", ">throw err;", "}" })
local handlers = {
	go = go,
	typescript = ts,
	typescriptreact = ts,
	javascript = ts,
	javascriptreact = ts,
	python = wrap("try:", { "except Exception as err:", ">raise" }),
}

function M.run()
	local h = handlers[vim.bo.filetype]
	if not h then return vim.notify("errhandle: no handler for " .. vim.bo.filetype, vim.log.levels.WARN) end
	h(vim.fn.line("'<"), vim.fn.line("'>"))
end

vim.keymap.set("x", "<leader>err", ":<C-u>lua require('tsoien.core.errhandle').run()<CR>", { desc = "Generate error handling" })

return M
