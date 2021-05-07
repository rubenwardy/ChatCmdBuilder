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


local ChatCmdBuilder = {}

--- Create and register a new chat command
function ChatCmdBuilder.new(name, func, def)
	def = def or {}
	local cmd = ChatCmdBuilder.build(func)
	cmd.def = def
	def.func = cmd.run
	minetest.register_chatcommand(name, def)
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


--- Type table, types can be registered by assigning to this table
ChatCmdBuilder.types = {
	pos    = "%(? *(%-?[%d.]+) *, *(%-?[%d.]+) *, *(%-?[%d.]+) *%)?",
	text   = "(.+)",
	number = "(%-?[%d.]+)",
	int    = "(%-?[%d]+)",
	word   = "([^ ]+)",
	alpha  = "([A-Za-z]+)",
	modname      = "([a-z0-9_]+)",
	alphascore   = "([A-Za-z_]+)",
	alphanumeric = "([A-Za-z0-9]+)",
	username     = "([A-Za-z0-9-_]+)",
}

function ChatCmdBuilder.build(buildfunc)
	local cmd = {
		_subs = {}
	}
	function cmd:sub(route, func)
		dprint("Parsing " .. route)

		if string.trim then
			route = string.trim(route)
		end

		local sub = {
			pattern = "^",
			params = {},
			func = func
		}

		-- End of param reached: add it to the pattern
		local param = ""
		local param_type = ""
		local should_be_eos = false
		local function finishParam()
			if param ~= "" and param_type ~= "" then
				dprint("   - Found param " .. param .. " type " .. param_type)

				local pattern = ChatCmdBuilder.types[param_type]
				if not pattern then
					error("Unrecognised param_type=" .. param_type)
				end

				sub.pattern = sub.pattern .. pattern

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
			if should_be_eos then
				error("Should be end of string. Nothing is allowed after a param of type text.")
			end

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

	if buildfunc then
		buildfunc(cmd)
	end

	cmd.run = function(name, param)
		for i = 1, #cmd._subs do
			local sub = cmd._subs[i]
			local res = { string.match(param, sub.pattern) }
			if #res > 0 then
				local pointer = 1
				local params = { name }
				for j = 1, #sub.params do
					local param = sub.params[j]  -- luacheck: ignore
					if param == "pos" then
						local pos = {
							x = tonumber(res[pointer]),
							y = tonumber(res[pointer + 1]),
							z = tonumber(res[pointer + 2])
						}
						table.insert(params, pos)
						pointer = pointer + 3
					elseif param == "number" or param == "int" then
						table.insert(params, tonumber(res[pointer]))
						pointer = pointer + 1
					else
						table.insert(params, res[pointer])
						pointer = pointer + 1
					end
				end
				if table.unpack then
					-- lua 5.2 or later
					return sub.func(table.unpack(params))
				else
					-- lua 5.1 or earlier
					return sub.func(unpack(params))
				end
			end
		end
		return false, "Invalid command"
	end

	return cmd
end

return ChatCmdBuilder
