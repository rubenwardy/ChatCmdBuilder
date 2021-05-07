-- This file tests to make sure that CCB remains roughly compatible
-- with previous versions.

_G.unpack = unpack or table.unpack
_G.minetest = {
	log = function() end,
}

local ChatCmdBuilder = dofile("chatcmdbuilder.lua")

describe("build", function()
	it("word", function()
		local cmd = ChatCmdBuilder.build(function(cmd)
			cmd:sub("bar :one and :two:word", function(name, one, two)
				if name == "singleplayer" and one == "abc" and two == "def" then
					return true
				end
			end)
		end)

		assert(cmd:run("singleplayer", "bar abc and def"), "Test 1 failed")
	end)

	it("pos", function()
		local move = ChatCmdBuilder.build(function(cmd)
			cmd:sub("move :target to :pos:pos", function(name, target, pos)
				if name == "singleplayer" and target == "player1" and
						pos.x == 0 and pos.y == 1 and pos.z == 2 then
					return true
				end
			end)
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


		local checknegpos = ChatCmdBuilder.build(function(cmd)
			cmd:sub("checknegpos :pos:pos", function(_, pos)
				return pos
			end)
		end)

		assert.same({ x=-13.3, y=-4.6, z=-1234.5 },
			checknegpos:run("checker","checknegpos (-13.3,-4.6,-1234.5)"))
	end)

	it("int", function()
		local cmd1 = ChatCmdBuilder.build(function(cmd)
			cmd:sub("does :one:int plus :two:int equal :three:int", function(name, one, two, three)
				if name == "singleplayer" and one + two == three then
					return true
				end
			end)
		end)
		assert(cmd1:run("singleplayer", "does 1 plus 2 equal 3"))

		local cmd2 = ChatCmdBuilder.build(function(cmd)
			cmd:sub("checknegint :x:int", function(_, x)
				return x
			end)
		end)

		assert.equal(-2, cmd2:run("checker","checknegint -2"))
	end)

	it("number", function()
		local checknegnumber = ChatCmdBuilder.build(function(cmd)
			cmd:sub("checknegnumber :x:number", function(_, x)
				return x
			end)
		end)
		assert.equal(-3.3, checknegnumber:run("checker","checknegnumber -3.3"))
	end)

	it("types", function()
		local checktypes = ChatCmdBuilder.build(function(cmd)
			cmd:sub("checktypes :int:int :number:number  :pos:pos :word:word  :text:text",
				function(_, ...) return ... end)
		end)

		local int, number, pos, word, text =
			checktypes:run("checker","checktypes -1 -2.4 (-3,-5.3,6.12)  some text  to finish off with")
		if int ~= -1 or number ~= -2.4 or pos.x ~= -3 or pos.y ~= -5.3 or pos.z ~= 6.12 or
				word ~= "some" or text ~= "text  to finish off with" then
			error("Test 15 failed")
		end
	end)
end)
