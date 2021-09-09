# ChatCmdBuilder

Easily create complex chat commands with no pattern matching.

Created by rubenwardy.\\
License: MIT

# API

## Installing

As a mod developer, you can:

1. Depend on [lib_chatcmdbuilder](https://content.minetest.net/packages/rubenwardy/lib_chatcmdbuilder/)
   mod and let the Minetest dependency system install it for you.

2. OR include the `chatcmdbuilder.lua` file in your mod, and then `dofile` it like so:

   ```lua
   local chatcmdbuilder = dofile("chatcmdbuilder.lua")
   ```

   It's important that you keep this as a local, to avoid conflict with the
   mod version if installed.


## Registering Chat Commands

`chatcmdbuilder.register(name, def)` registers a new chat command called `name`. It returns an object to register subcommands.

Here is an example:

```lua
local cmd = chatcmdbuilder.register("admin", {
	description = "Admin tools",
	privs = {
		kick = true,
		ban = true
	}
})

cmd:sub("kill :target", function(name, target)
	local player = minetest.get_player_by_name(target)
	if player then
		player:set_hp(0)
		return true, "Killed " .. target
	else
		return false, "Unable to find " .. target
	end
end)

cmd:sub("move :target to :pos:pos", {
	privs = {
		teleport = true
	},

	func = function(name, target, pos)
		local player = minetest.get_player_by_name(target)
		if player then
			player:setpos(pos)
			return true, "Moved " .. target .. " to " .. minetest.pos_to_string(pos)
		else
			return false, "Unable to find " .. target
		end
	end,
})
```

A player could then do `/admin kill player1` to kill player1,
or `/admin move player1 to 0,0,0` to teleport a user.

## Introduction to Routing

A route is a string. Let's look at `move :target to :pos:pos`:

* `move` and `to` are terminals. They need to be there in order to match.
* `:target` and `:pos:pos` are variables. They're passed to the function.
* The second `pos` in `:pos:pos` after `:` is the param type. `:target` has an implicit
  type of `word`.

### Param Types

* `word`: default. Any string without spaces
* `number`: Any number, including decimals
* `int`: Any integer, no decimals
* `text`: Any string
* `pos`: 1,2,3 or 1.1,2,3.4567 or (1,2,3) or 1.2, 2 ,3.2
* `modname`: a mod name
* `alpha`: upper or lower alphabetic characters (A-Za-z)
* `alphascore`: above, but with underscores
* `alphanumeric`: upper or lower alphabetic characters and numbers (A-Za-z0-9)
* `username`: a username
* `itemname`: an item name

### Registering new Param Types

```lua
-- Simple type for lowercase text
--    eg: `:param:lower`
chatcmdbuilder.register_type("lower", "([a-z]+)", function(pop)
	return tonumber(pop())
end)

-- Position type
--    eg: `:param:pos`
chatcmdbuilder.register_type("pos", "%(? *(%-?[%d.]+) *, *(%-?[%d.]+) *, *(%-?[%d.]+) *%)?", function(pop)
	return {
		x = tonumber(pop()),
		y = tonumber(pop()),
		z = tonumber(pop())
	}
end)
```

## Reference

### Functions

* `chatcmdbuilder.register(name, def)`: registers a chat command
	* Returns a `chatcmdbuilder.Builder` instance
	* `name`: chat command name.
	* `def`: chat command def, can contain everything in `register_chatcommand`, except for `func`.
* `chatcmdbuilder.register_type(name, pattern, converter)`: register a param type
	* `name`: type name, used in routes
	* `pattern`: A Lua pattern
	* `converter(pop)`: Optional, a function to convert text into the type
		* `pop`: function to return the next matched group.
		* returns the converted value.

### class chatcmdbuilder.Builder

This is the class returned by `chatcmdbuilder.register`.

Constructor:

* `chatcmdbuilder.Builder:new()`: returns new instance

Methods:

* `sub(path, func_or_def)`
	* `path`: a route
	* `func_or_def`: either a function or a def table containing:
		* `func`: function
		* `privs`: a list of required privs
* `run(name, params)`: Execute chat command
	* Returns same as `func`: `boolean, message`.
	* Doesn't check chat command privs, but will check subcommand privs.
