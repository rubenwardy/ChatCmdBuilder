_G.unpack = unpack or table.unpack
_G.minetest = {
	log = function() end,
	privs_to_string = function(privs)
		local list = {}
		for key, _ in pairs(privs) do
			list[#list + 1] = key
		end
		table.sort(list)
		return table.concat(list, ", ")
	end,
}

local chatcmdbuilder = dofile("chatcmdbuilder.lua")
local Builder = chatcmdbuilder.Builder

describe("builder", function()
	it("word", function()
		local cmd = Builder:new()
		cmd:sub("bar :one and :two:word", function(name, one, two)
			if name == "singleplayer" and one == "abc" and two == "def" then
				return true
			end
		end)

		assert(cmd:run("singleplayer", "bar abc and def"), "Test 1 failed")
	end)

	it("pos", function()
		local move = Builder:new()
		move:sub("move :target to :pos:pos", function(name, target, pos)
			if name == "singleplayer" and target == "player1" and
					pos.x == 0 and pos.y == 1 and pos.z == 2 then
				return true
			end
		end)

		assert(move:run("singleplayer", "move player1 to 0,1,2"))
		assert(move:run("singleplayer", "move player1 to (0,1,2)"))
		assert(move:run("singleplayer", "move player1 to 0, 1,2"))
		assert(move:run("singleplayer", "move player1 to 0 ,1, 2"))
		assert(move:run("singleplayer", "move player1 to 0, 1, 2"))
		assert(move:run("singleplayer", "move player1 to 0 ,1 ,2"))
		assert(move:run("singleplayer", "move player1 to ( 0 ,1 ,2)"))
		assert(not move:run("singleplayer", "move player1 to abc,def,sdosd"))
		assert(not move:run("singleplayer", "move player1 to abc def sdosd"))

		local checknegpos = Builder:new()
		checknegpos:sub("checknegpos :pos:pos", function(_, pos)
			return pos
		end)

		assert.same({ x=-13.3, y=-4.6, z=-1234.5 },
			checknegpos:run("checker","checknegpos (-13.3,-4.6,-1234.5)"))
	end)

	it("int", function()
		local cmd1 = Builder:new()
		cmd1:sub("does :one:int plus :two:int equal :three:int", function(name, one, two, three)
			if name == "singleplayer" and one + two == three then
				return true
			end
		end)
		assert(cmd1:run("singleplayer", "does 1 plus 2 equal 3"))

		local cmd2 = Builder:new()
		cmd2:sub("checknegint :x:int", function(_, x)
			return x
		end)

		assert.equal(-2, cmd2:run("checker","checknegint -2"))
	end)

	it("number", function()
		local cmd = Builder:new()
		cmd:sub("checknegnumber :x:number", function(_, x)
			return x
		end)

		assert.equal(-3.3, cmd:run("checker","checknegnumber -3.3"))
	end)

	it("types", function()
		local cmd = Builder:new()
		cmd:sub("checktypes :int:int :number:number  :pos:pos :word:word  :text:text",
			function(_, ...) return ... end)

		local int, number, pos, word, text =
			cmd:run("checker","checktypes -1 -2.4 (-3,-5.3,6.12)  some text  to finish off with")
		if int ~= -1 or number ~= -2.4 or pos.x ~= -3 or pos.y ~= -5.3 or pos.z ~= 6.12 or
				word ~= "some" or text ~= "text  to finish off with" then
			error("Test 15 failed")
		end
	end)

	it("itemname", function()
		local cmd = Builder:new()
		cmd:sub("echo :two:itemname", function(_, ...)
			return ...
		end)

		assert.equal("one:two", cmd:run("singleplayer", "echo one:two"))
		assert.equal("one", cmd:run("singleplayer", "echo one"))
		assert.is_false(cmd:run("singleplayer", "echo one:"))
		assert.is_false(cmd:run("singleplayer", "echo :two"))
	end)

	it("privs", function()
		local cmd = Builder:new()
		cmd:sub("echo :two:text", {
			privs = {
				priv1 = true,
				priv2 = true
			},
			func = function(_, ...)
				return true, ...
			end,
		})

		do
			_G.minetest.check_player_privs = function()
				return false, { priv1 = true, priv2 = true }
			end

			local suc, msg = cmd:run("singleplayer", "echo hello")
			assert.is_false(suc)
			assert.equal("Missing privs: priv1, priv2", msg)
		end

		do
			_G.minetest.check_player_privs = function()
				return false, { priv1 = true }
			end

			local suc, msg = cmd:run("singleplayer", "echo hello")
			assert.is_false(suc)
			assert.equal("Missing privs: priv1", msg)
		end


		do
			_G.minetest.check_player_privs = function()
				return true, {}
			end

			local suc, msg = cmd:run("singleplayer", "echo hello")
			assert.is_true(suc)
			assert.equal("hello", msg)
		end
	end)
end)
