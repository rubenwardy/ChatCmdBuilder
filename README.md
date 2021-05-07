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
   local ChatCmdBuilder = dofile("chatcmdbuilder.lua")
   ```

   It's important that you keep this as a local, to avoid conflict with the
   mod version if installed.


## Registering Chat Commands

`ChatCmdBuilder.new(name, setup)` registers a new chat command called `name`.
Setup is called immediately after calling `new` to initialise subcommands.

You can set values in the chat command definition by using def:
`ChatCmdBuilder.new(name, setup, def)`.

Here is an example:

```lua
local cmd = ChatCmdBuilder.new("admin", {
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

cmd:sub("move :target to :pos:pos", function(name, target, pos)
	local player = minetest.get_player_by_name(target)
	if player then
		player:setpos(pos)
		return true, "Moved " .. target .. " to " .. minetest.pos_to_string(pos)
	else
		return false, "Unable to find " .. target
	end
end)
```

A player could then do `/admin kill player1` to kill player1,
or `/admin move player1 to 0,0,0` to teleport a user.

## Introduction to Routing

A route is a string. Let's look at `move :target to :pos:pos`:

* `move` and `to` are constants. They need to be there in order to match.
* `:target` and `:pos:pos` are parameters. They're passed to the function.
* The second `pos` in `:pos:pos` after `:` is the param type. `:target` has an implicit
  type of `word`.

## Param Types

* `word` - default. Any string without spaces
* `number` - Any number, including decimals
* `int` - Any integer, no decimals
* `text` - Any string
* `pos` - 1,2,3 or 1.1,2,3.4567 or (1,2,3) or 1.2, 2 ,3.2
* `modname` - a mod name
* `alpha` - upper or lower alphabetic characters (A-Za-z)
* `alphascore` - above, but with underscores
* `alphanumeric` - upper or lower alphabetic characters and numbers (A-Za-z0-9)
* `username` - a valid username

## Registering new Paramtypes

```lua
ChatCmdBuilder.types["lower"] = "([a-z])"
```

## Build chat command function

If you don't want to register the chatcommand at this point, you can just generate
the chat command's `func` function using `ChatCmdBuilder.build`.
