local Gamestate = require 'vendor.hump.gamestate'
local Vector = require 'vendor.hump.vector'

local actors_base = require 'klinklang.actors.base'
local actors_misc = require 'klinklang.actors.misc'
local util = require 'klinklang.util'
local whammo_shapes = require 'klinklang.whammo.shapes'
local DialogueScene = require 'klinklang.scenes.dialogue'


local Glomeleon = actors_base.MobileActor:extend{
    name = 'glomeleon',
    sprite_name = 'glomeleon',

    walking_left = true,
}

-- FIXME merge this with Player
function Glomeleon:update(dt)
    if self.is_dead then
        -- FIXME a corpse still has physics, just not input
        self.sprite:update(dt)
        return
    end

    local xmult
    if self.on_ground then
        -- TODO adjust this factor when on a slope, so ascending is harder than
        -- descending?  maybe even affect max_speed going uphill?
        xmult = self.ground_friction
    else
        xmult = self.aircontrol
    end
    --print()
    --print()
    --print("position", self.pos, "velocity", self.velocity)

    -- Explicit movement
    if self.velocity.x == 0 then
        self.walking_left = not self.walking_left
    end
    local pose = 'stand'
    if self.walking_left then
        if self.velocity.x < self.max_speed then
            self.velocity.x = self.velocity.x + self.xaccel * xmult * dt
        end
        self.facing_left = false
        pose = 'walk'
    elseif not self.walking_left then
        if self.velocity.x > -self.max_speed then
            self.velocity.x = self.velocity.x - self.xaccel * xmult * dt
        end
        self.facing_left = true
        pose = 'walk'
    end
    -- FIXME no aliases, and no walking pose for glomeleon yet...
    pose = 'stand'

    -- Jumping
    -- [n/a]

    -- Run the base logic to perform movement, collision, sprite updating, etc.
    Glomeleon.__super.update(self, dt)

    -- FIXME uhh this sucks, but otherwise the death animation is clobbered by
    -- the bit below!  should death skip the rest of the actor's update cycle
    -- entirely, including activating any other collision?  should death only
    -- happen at the start of a frame?  should it be an event or something?
    if self.is_dead then
        return
    end

    -- Update pose depending on actual movement
    if self.on_ground then
    elseif self.velocity.y < 0 then
        --pose = 'jump'
    elseif self.velocity.y > 0 then
        --pose = 'fall'
    end
    -- TODO how do these work for things that aren't players?
    self.sprite:set_facing_right(not self.facing_left)
    self.sprite:set_pose(pose)

    local hits = self._stupid_hits_hack
    debug_hits = hits
end

function Glomeleon:on_collide(other, d)
    other:damage(self, 1)
end

function Glomeleon:damage(source, amount)
    --self:die()
    worldscene:remove_actor(self)
end


return {
    Glomeleon = Glomeleon,
}