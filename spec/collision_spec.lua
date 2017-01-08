local Vector = require 'vendor.hump.vector'

local whammo = require 'klinklang.whammo'
local whammo_shapes = require 'klinklang.whammo.shapes'

describe("Collision", function()
    it("should handle orthogonal movement", function()
        --[[
            +--------+
            | player |
            +--------+
            | floor  |
            +--------+
            movement is straight down; should do nothing
        ]]
        local collider = whammo.Collider(400)
        local floor = whammo_shapes.Box(0, 100, 100, 100)
        collider:add(floor)

        local player = whammo_shapes.Box(0, 0, 100, 100)
        local successful, hits = collider:slide(player, 0, 50)
        assert.are.equal(Vector(0, 0), successful)
        assert.are.equal(1, hits[floor])
    end)
    it("should stop at the first obstacle", function()
        --[[
                +--------+
                | player |
                +--------+
            +--------+
            | floor1 |+--------+ 
            +--------+| floor2 | 
                      +--------+
            movement is straight down; should hit floor1 and stop
        ]]
        local collider = whammo.Collider(400)
        local floor1 = whammo_shapes.Box(0, 150, 100, 100)
        collider:add(floor1)
        local floor2 = whammo_shapes.Box(100, 200, 100, 100)
        collider:add(floor2)

        local player = whammo_shapes.Box(50, 0, 100, 100)
        local successful, hits = collider:slide(player, 0, 150)
        assert.are.equal(Vector(0, 50), successful)
        assert.are.equal(1, hits[floor1])
        assert.are.equal(nil, hits[floor2])
    end)
    it("should allow sliding past an obstacle", function()
        --[[
            +--------+
            |  wall  |
            +--------+
                     +--------+
                     | player |
                     +--------+
            movement is straight up; shouldn't collide
        ]]
        local collider = whammo.Collider(400)
        local wall = whammo_shapes.Box(0, 0, 100, 100)
        collider:add(wall)

        local player = whammo_shapes.Box(100, 150, 100, 100)
        local successful, hits = collider:slide(player, 0, -150)
        assert.are.equal(Vector(0, -150), successful)
        assert.are.equal(0, hits[wall], false)
    end)
    it("should handle diagonal movement into lone corners", function()
        --[[
            +--------+
            |  wall  |
            +--------+
                       +--------+
                       | player |
                       +--------+
            movement is up and to the left (more left); should slide left along
            the ceiling
        ]]
        local collider = whammo.Collider(400)
        local wall = whammo_shapes.Box(0, 0, 100, 100)
        collider:add(wall)

        local player = whammo_shapes.Box(200, 150, 100, 100)
        local successful, hits = collider:slide(player, -200, -100)
        assert.are.equal(Vector(-200, -50), successful)
        assert.are.equal(1, hits[wall])
    end)
    it("should handle diagonal movement into corners with walls", function()
        --[[
            +--------+
            | wall 1 |
            +--------+--------+
            | wall 2 | player |
            +--------+--------+
            movement is up and to the left; should slide along the wall upwards
        ]]
        local collider = whammo.Collider(400)
        local wall1 = whammo_shapes.Box(0, 0, 100, 100)
        collider:add(wall1)
        local wall2 = whammo_shapes.Box(0, 100, 100, 100)
        collider:add(wall2)

        local player = whammo_shapes.Box(100, 100, 100, 100)
        local successful, hits = collider:slide(player, -50, -50)
        assert.are.equal(Vector(0, -50), successful)
        assert.are.equal(1, hits[wall1])
        assert.are.equal(1, hits[wall2])
    end)
    it("should slide you down when pressed against a corner", function()
        --[[
                     +--------+
            +--------+ player |
            |  wall  +--------+
            +--------+
            movement is down and to the left; should slide down along the wall
            at full speed
        ]]
        local collider = whammo.Collider(400)
        local wall = whammo_shapes.Box(0, 50, 100, 100)
        collider:add(wall)

        local player = whammo_shapes.Box(100, 0, 100, 100)
        local successful, hits = collider:slide(player, -100, 50)
        assert.are.equal(Vector(0, 50), successful)
        assert.are.equal(1, hits[wall])
    end)
    it("should slide you down when pressed against a wall", function()
        --[[
            +--------+
            | wall 1 +--------+
            +--------+ player |
            | wall 2 +--------+
            +--------+
            movement is down and to the left; should slide down along the wall
            at full speed
        ]]
        local collider = whammo.Collider(400)
        local wall1 = whammo_shapes.Box(0, 0, 100, 100)
        collider:add(wall1)
        local wall2 = whammo_shapes.Box(0, 100, 100, 100)
        collider:add(wall2)

        local player = whammo_shapes.Box(100, 50, 100, 100)
        local successful, hits = collider:slide(player, -50, 100)
        assert.are.equal(Vector(0, 100), successful)
        assert.are.equal(1, hits[wall1])
        assert.are.equal(1, hits[wall2])
    end)
    it("should not register slides against objects out of range", function()
        --[[
            +--------+
            | player |
            +--------+    +--------+--------+
                          | floor1 | floor2 |
                          +--------+--------+
            movement is directly right; should not be blocked at all, should
            slide on floor 1, should NOT slide on floor 2
        ]]
        local collider = whammo.Collider(400)
        local floor1 = whammo_shapes.Box(150, 100, 100, 100)
        collider:add(floor1)
        local floor2 = whammo_shapes.Box(250, 100, 100, 100)
        collider:add(floor2)

        local player = whammo_shapes.Box(0, 0, 100, 100)
        local successful, hits = collider:slide(player, 100, 0)
        assert.are.equal(Vector(100, 0), successful)
        assert.are_equal(0, hits[floor1])
        assert.are_equal(nil, hits[floor2])
    end)
    it("should count touches even when not moving", function()
        --[[
                     +--------+
                     | player |
            +--------+--------+--------+
            | floor1 | floor2 | floor3 |
            +--------+--------+--------+
            movement is nowhere; should touch all three floors
            at full speed
        ]]
        local collider = whammo.Collider(400)
        local floor1 = whammo_shapes.Box(0, 100, 100, 100)
        collider:add(floor1)
        local floor2 = whammo_shapes.Box(100, 100, 100, 100)
        collider:add(floor2)
        local floor3 = whammo_shapes.Box(200, 100, 100, 100)
        collider:add(floor3)

        local player = whammo_shapes.Box(100, 0, 100, 100)
        local successful, hits = collider:slide(player, 0, 0)
        assert.are.equal(Vector(0, 0), successful)
        assert.are.equal(0, hits[floor1])
        assert.are.equal(0, hits[floor2])
        assert.are.equal(0, hits[floor3])
    end)
    it("should ignore existing overlaps", function()
        --[[
                    +--------+
            +-------++player |
            | floor ++-------+
            +--------+
            movement is to the left; shouldn't block us at all
        ]]
        local collider = whammo.Collider(400)
        local floor = whammo_shapes.Box(0, 100, 100, 100)
        collider:add(floor)

        local player = whammo_shapes.Box(80, 80, 100, 100)
        local successful, hits = collider:slide(player, -200, 0)
        assert.are.equal(Vector(-200, 0), successful)
        assert.are.equal(-1, hits[floor])
    end)

    it("should not let you fall into the floor", function()
        --[[
            Actual case seen when playing:
            +--------+
            | player |
            +--------+--------+
            | floor1 | floor2 |
            +--------+--------+
            movement is right and down (due to gravity)
        ]]
        local collider = whammo.Collider(4 * 32)
        local floor1 = whammo_shapes.Box(448, 384, 32, 32)
        collider:add(floor1)
        local floor2 = whammo_shapes.Box(32, 256, 32, 32)
        collider:add(floor2)

        local player = whammo_shapes.Box(443, 320, 32, 64)
        local successful, hits = collider:slide(player, 4.3068122830999, 0.73455352286288)
        assert.are.equal(Vector(4.3068122830999, 0), successful)
        assert.are.equal(1, hits[floor1])
    end)

    it("should allow near misses", function()
        --[[
            Actual case seen when playing:
                    +--------+
                    | player |
                    +--------+

            +--------+
            | floor  |
            +--------+
            movement is right and down, such that the player will not actually
            touch the floor
        ]]
        local collider = whammo.Collider(4 * 100)
        local floor = whammo_shapes.Box(0, 250, 100, 100)
        collider:add(floor)

        local player = whammo_shapes.Box(0, 0, 100, 100)
        local move = Vector(150, 150)
        local successful, hits = collider:slide(player, move:unpack())
        assert.are.equal(move, successful)
        assert.are.equal(nil, hits[floor])
    end)
end)
