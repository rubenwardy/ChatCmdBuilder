-- Copyright (c) 2016-21  rubenwardy
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.


local chatcmdbuilder = {
	types = {	}
}

function chatcmdbuilder.register(name, def)
	local cmd = chatcmdbuilder.Builder:new()

	def = def or {}
	cmd.def = def
	def.func = function(...)
		return cmd:run(...)
	end
	minetest.register_chatcommand(name, def)

	return cmd
end

function chatcmdbuilder.register_type(name, pattern, converter)
	converter = converter or function(pop)
		return pop()
	end

	assert(chatcmdbuilder.types[name] == nil, "Type " .. name ..
			" is already registered")
	chatcmdbuilder.types[name] = {
		pattern = pattern,
		convert = converter,
	}
end

chatcmdbuilder.register_type("pos", "%(? *(%-?[%d.]+) *, *(%-?[%d.]+) *, *(%-?[%d.]+) *%)?", function(pop)
	return {
		x = tonumber(pop()),
		y = tonumber(pop()),
		z = tonumber(pop())
	}
end)

chatcmdbuilder.register_type("text", "(.+)")
chatcmdbuilder.register_type("number", "(%-?[%d.]+)", function(pop)
	return tonumber(pop())
end)
chatcmdbuilder.register_type("int", "(%-?[%d]+)", function(pop)
	return tonumber(pop())
end)
chatcmdbuilder.register_type("word", "([^ ]+)")
chatcmdbuilder.register_type("alpha", "([A-Za-z]+)")
chatcmdbuilder.register_type("modname", "([a-z0-9_]+)")
chatcmdbuilder.register_type("alphascore", "([A-Za-z_]+)")
chatcmdbuilder.register_type("alphanumeric", "([A-Za-z0-9]+)")
chatcmdbuilder.register_type("username", "([A-Za-z0-9-_]+)")
chatcmdbuilder.register_type("itemname", "([a-z0-9_]+:?[a-z0-9_]+)")

-- Compat
function chatcmdbuilder.new(name, func, def)
	minetest.log("warning", "Deprecated call to chatcmdbuilder.new")

	local cmd = chatcmdbuilder.register(name, def)
	func(cmd)
end

function chatcmdbuilder.build(func)
	minetest.log("warning", "Deprecated call to chatcmdbuilder.build, use chatcmdbuilder.Builder:new() instead")

	local cmd = chatcmdbuilder.Builder:new()
	if func then
		func(cmd)
	end
	return cmd
end



local STATE_READY = 1
local STATE_PARAM = 2
local STATE_PARAM_TYPE = 3
local bad_chars = {
	["("] = true, [")"] = true, ["."] = true,  ["%"] = true, ["+"] = true,
	["-"] = true, ["*"] = true, ["?"] = true, ["["] = true, ["^"] = true,
	["$"] = true,
}

local function escape(char)
	if bad_chars[char] then
		return "%" .. char
	else
		return char
	end
end

-- Debug print
local dprint = function() end
-- local dprint = print


local CmdBuilder = {}
chatcmdbuilder.Builder = CmdBuilder

function CmdBuilder:new()
	local o = {
		_subs = {}
	}

	setmetatable(o, self)
	self.__index = self
	return o
end

function CmdBuilder:sub(route, func_or_def)
	dprint("Parsing " .. route)

	if string.trim then
		route = string.trim(route)
	end

	if type(func_or_def) == "function" then
		func_or_def = {
			func = func_or_def
		}
	end

	local sub = {
		pattern = "^",
		params = {},
		func = func_or_def.func,
		def = func_or_def,
	}


	-- End of param reached: add it to the pattern
	local param = ""
	local param_type = ""
	local should_be_eos = false
	local function finishParam()
		if param ~= "" and param_type ~= "" then
			dprint("   - Found param " .. param .. " type " .. param_type)

			local ptype = chatcmdbuilder.types[param_type]
			assert(ptype, "Unrecognised param_type=" .. param_type)

			sub.pattern = sub.pattern .. ptype.pattern

			table.insert(sub.params, param_type)

			param = ""
			param_type = ""
		end
	end

	-- Iterate through the route to find params
	local state = STATE_READY
	local catching_space = false
	local match_space = " " -- change to "%s" to also catch tabs and newlines
	local catch_space = match_space.."+"
	for i = 1, #route do
		local c = route:sub(i, i)
		assert(not should_be_eos,
				"Should be end of string. Nothing is allowed after a param of type text.")

		if state == STATE_READY then
			if c == ":" then
				dprint(" - Found :, entering param")
				state = STATE_PARAM
				param_type = "word"
				catching_space = false
			elseif c:match(match_space) then
				dprint(" - Found space")
				if not catching_space then
					catching_space = true
					sub.pattern = sub.pattern .. catch_space
				end
			else
				catching_space = false
				sub.pattern = sub.pattern .. escape(c)
			end
		elseif state == STATE_PARAM then
			if c == ":" then
				dprint(" - Found :, entering param type")
				state = STATE_PARAM_TYPE
				param_type = ""
			elseif c:match(match_space) then
				dprint(" - Found whitespace, leaving param")
				state = STATE_READY
				finishParam()
				catching_space = true
				sub.pattern = sub.pattern .. catch_space
			elseif c:match("%W") then
				dprint(" - Found nonalphanum, leaving param")
				state = STATE_READY
				finishParam()
				sub.pattern = sub.pattern .. escape(c)
			else
				param = param .. c
			end
		elseif state == STATE_PARAM_TYPE then
			if c:match(match_space) then
				dprint(" - Found space, leaving param type")
				state = STATE_READY
				finishParam()
				catching_space = true
				sub.pattern = sub.pattern .. catch_space
			elseif c:match("%W") then
				dprint(" - Found nonalphanum, leaving param type")
				state = STATE_READY
				finishParam()
				sub.pattern = sub.pattern .. escape(c)
			else
				param_type = param_type .. c
			end
		end
	end
	dprint(" - End of route")
	finishParam()
	sub.pattern = sub.pattern .. "$"
	dprint("Pattern: " .. sub.pattern)

	table.insert(self._subs, sub)
end

function CmdBuilder:run(name, param)
	for i = 1, #self._subs do
		local sub = self._subs[i]
		local res = { string.match(param, sub.pattern) }
		if #res > 0 then
			if sub.def.privs then
				local suc, missing_privs = minetest.check_player_privs(name, sub.def.privs)
				if not suc then
					return false, "Missing privs: " ..
							minetest.privs_to_string(missing_privs)
				end
			end

			local pointer = 1
			local params = { name }
			for j = 1, #sub.params do
				local ptypename = sub.params[j]
				local ptype = chatcmdbuilder.types[ptypename]
				local result = ptype.convert(function()
					pointer = pointer + 1
					return res[pointer - 1]
				end)
				table.insert(params, result)
			end

			return sub.func(unpack(params))
		end
	end
	return false, "Invalid command"
end


return chatcmdbuilder
