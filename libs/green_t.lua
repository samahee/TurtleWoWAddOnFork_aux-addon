library 'green_t'

local next, getn, setn, tremove, type, setmetatable = next, getn, table.setn, tremove, type, setmetatable

local wipe, acquire, release, auto_release, dep_release
do
	local pool, pool_size, overflow_pool, is_auto_release, is_dep_release = {}, 0, setmetatable({}, {__mode='k'}), {}, setmetatable({}, {__mode='k'})

	function wipe(t)
		setmetatable(t, nil)
		for k, v in t do
			if is_dep_release[v] then release(v) end
			t[k] = nil
		end
		t.reset, t.reset = nil, 1
		setn(t, 0)
	end
	M.wipe = wipe

	CreateFrame'Frame':SetScript('OnUpdate', function()
		for t in is_auto_release do release(t) end
		wipe(is_auto_release)
	end)
	
	function acquire()
		if pool_size > 0 then
			pool_size = pool_size - 1
			return pool[pool_size + 1]
		end
		local t = next(overflow_pool)
		if t then
			overflow_pool[t] = nil
			return t
		end
		return {}
	end
	M.acquire = acquire

	function release(t)
		wipe(t)
		is_auto_release[t] = nil
		is_dep_release[t] = nil
		if pool_size < 50 then
			pool_size = pool_size + 1
			pool[pool_size] = t
		else
			overflow_pool[t] = true
		end
	end
	M.release = release

	function auto_release(v, enable)
		if type(v) ~= 'table' then return end
		is_auto_release[v] = enable and true or nil
	end
	M.auto_release = auto_release

	function dep_release(v, enable)
		if type(v) ~= 'table' then return end
		is_dep_release[v] = enable and true or nil
	end
	M.dep_release = dep_release
end

M.get_t = acquire

function M.get_tt()
	local t = acquire()
	auto_release(t, true)
	return t
end

M.temp = setmetatable({}, {
	__metatable = false,
	__newindex = nop,
	__sub = function(_, v) auto_release(v, true); return v end,
})
M.weak = setmetatable({}, {
	__metatable = false,
	__newindex = nop,
	__sub = function(_, v) dep_release(v, true); return v end,
})

do
	local function ret(t)
		if getn(t) > 0 then
			return tremove(t, 1), ret(t)
		else
			release(t)
		end
	end
	M.ret = ret
end

M.empty = setmetatable({}, {__metatable=false, __newindex=nop})

local vararg
do
	local MAXPARAMS = 100

	local code = [[
		local f, setn, acquire, auto_release = f, setn, acquire, auto_release
		return function(
	]]
	for i = 1, MAXPARAMS - 1 do
		code = code .. format('a%d,', i)
	end
	code = code .. [[
		overflow)
		if overflow ~= nil then error("Vararg overflow.") end
		local n = 0
		repeat
	]]
	for i = MAXPARAMS - 1, 1, -1 do
		code = code .. format('if a%1$d ~= nil then n = %1$d; break end;', i)
	end
	code = code .. [[
		until true
		local t = acquire()
		auto_release(t, true)
		setn(t, n)
		repeat
	]]
	for i = 1, MAXPARAMS - 1 do
		code = code .. format('if %1$d > n then break end; t[%1$d] = a%1$d;', i)
	end
	code = code .. [[
		until true
		return f(t)
		end
	]]

	function vararg(f)
		local chunk = loadstring(code)
		setfenv(chunk, {f=f, setn=setn, acquire=acquire, auto_release=auto_release})
		return chunk()
	end
	M.vararg = setmetatable({}, {
		__metatable = false,
		__sub = function(_, v) return vararg(v) end,
	})
end

M.A = vararg(function(arg)
	auto_release(arg, false)
	return arg
end)
M.S = vararg(function(arg)
	local t = acquire()
	for _, v in arg do
		t[v] = true
	end
	return t
end)
M.T = vararg(function(arg)
	local t = acquire()
	for i = 1, getn(arg), 2 do
		t[arg[i]] = arg[i + 1]
	end
	return t
end)