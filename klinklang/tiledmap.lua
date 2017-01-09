--[[
Read a map in Tiled's JSON format.
]]

local anim8 = require 'vendor.anim8'
local Class = require 'vendor.hump.class'
local Vector = require 'vendor.hump.vector'
local json = require 'vendor.dkjson'

local util = require 'klinklang.util'
local whammo_shapes = require 'klinklang.whammo.shapes'
local SpriteSet = require 'klinklang.sprite'


-- I hate silent errors
local function strict_json_decode(str)
    local obj, pos, err = json.decode(str)
    if err then
        error(err)
    else
        return obj
    end
end

-- TODO no idea how correct this is
-- n.b.: a is assumed to hold a /filename/, which is popped off first
local function relative_path(a, b)
    a = a:gsub("[^/]+$", "")
    while b:find("^%.%./") do
        b = b:gsub("^%.%./", "")
        a = a:gsub("[^/]+/?$", "")
    end
    if not a:find("/$") then
        a = a .. "/"
    end
    return a .. b
end


--------------------------------------------------------------------------------
-- TileProxy
--
-- Not a real tile object, but a little wrapper that can read its properties
-- from the Tiled JSON on the fly.

local TileProxy = Class{}

function TileProxy:init()
end

--------------------------------------------------------------------------------
-- TiledTileset

local TiledTileset = Class{}

function TiledTileset:init(path, data, resource_manager)
    self.path = path
    if not data then
        data = strict_json_decode(love.filesystem.read(path))
    end
    self.raw = data

    -- Copy some basics
    local iw, ih = data.imagewidth, data.imageheight
    local tw, th = data.tilewidth, data.tileheight
    self.imagewidth = iw
    self.imageheight = ih
    self.tilewidth = tw
    self.tileheight = th
    self.tilecount = data.tilecount
    self.columns = data.columns

    -- Fetch the image
    local imgpath = relative_path(path, data.image)
    self.image = resource_manager:load(imgpath)

    -- Double-check the image size matches
    local aiw, aih = self.image:getDimensions()
    if iw ~= aiw or ih ~= aih then
        error((
            "Tileset at %s claims to use a %d x %d image, but the actual " ..
            "image at %s is %d x %d -- if you resized the image, open the " ..
            "tileset in Tiled, and it should offer to fix this automatically"
            ):format(path, iw, ih, imgpath, aiw, aih))
    end

    -- Create a quad for each tile
    -- NOTE: This is NOT (quite) a Lua array; it's a map from Tiled's tile ids
    -- (which start at zero) to quads
    self.quads = {}
    for relid = 0, self.tilecount - 1 do
        -- TODO support spacing, margin
        local row, col = util.divmod(relid, self.columns)
        self.quads[relid] = love.graphics.newQuad(
            col * tw, row * th, tw, th, iw, ih)

        -- While we're in here: JSON necessitates that the keys for per-tile
        -- data are strings, but they're intended as numbers, so fix them up
        -- TODO surely this could be done as its own loop on the outside
        for _, key in ipairs{'tiles', 'tileproperties', 'tilepropertytypes'} do
            local tbl = data[key]
            if tbl then
                tbl[relid] = tbl["" .. relid]
                tbl["" .. relid] = nil
            end
        end
    end

    -- Read named sprites (and their animations, if appropriate)
    -- FIXME this probably shouldn't happen for a random-ass sprite we're
    -- reading from within a map, right?  maybe this should be a separate
    -- method that dumps the spritesets into a passed-in table (which would let
    -- me get rid of _all_sprites)
    -- FIXME this scheme is nice, except, there's no way to use the same frame
    -- for two poses?
    local spritesets = {}
    local grid = anim8.newGrid(tw, th, iw, ih, data.margin, data.margin, data.spacing)
    for id = 0, self.tilecount - 1 do
        -- Tile IDs are keyed as strings, because JSON
        --id = "" .. id
        -- FIXME uggh
        if data.tileproperties and data.tileproperties[id] and data.tileproperties[id]['sprite name'] then
            local full_sprite_name = data.tileproperties[id]['sprite name']
            local sprite_name, pose_name = full_sprite_name:match("^(.+)/(.+)$")
            local spriteset = spritesets[sprite_name]
            if not spriteset then
                spriteset = SpriteSet(sprite_name, self.image)
                spritesets[sprite_name] = spriteset
            end

            -- Collect the frames, as a list of quads
            local quads, durations, onloop
            if data.tiles and data.tiles[id] and data.tiles[id].animation then
                quads = {}
                durations = {}
                for _, animation_frame in ipairs(data.tiles[id].animation) do
                    table.insert(quads, self.quads[animation_frame.tileid])
                    table.insert(durations, animation_frame.duration / 1000)
                end
                if data.tileproperties[id]['animation stops'] then
                    onloop = 'pauseAtEnd'
                end
            else
                quads = {self.quads[id]}
                durations = 1
                onloop = 'pauseAtEnd'
            end
            spriteset:add(pose_name, quads, durations, onloop)
        end
    end
end

function TiledTileset:get_collision(tileid)
    if not self.raw.tiles then
        return
    end

    local tiledata = self.raw.tiles[tileid]
    if not tiledata then
        return nil
    end

    -- TODO extremely hokey -- assumes at least one, doesn't check for more
    -- than one, doesn't check shape, etc
    -- TODO and this might crash at any point
    local coll = tiledata.objectgroup.objects[1]
    if not coll then
        return
    end

    if coll.polygon then
        local points = {}
        for _, pt in ipairs(coll.polygon) do
            if _ ~= 1 then
                table.insert(points, pt.x)
                table.insert(points, pt.y)
            end
        end
        return whammo_shapes.Polygon(unpack(points))
    end

    local shape = whammo_shapes.Box(
        coll.x, coll.y, coll.width, coll.height)

    -- FIXME this is pretty bad
    if coll.properties and coll.properties['one-way platform'] then
        shape._xxx_is_one_way_platform = true
    end

    return shape
end

--------------------------------------------------------------------------------
-- TiledMap

local TiledMap = Class{
    player_start = nil,
}

function TiledMap:init(path, resource_manager)
    self.raw = strict_json_decode(love.filesystem.read(path))

    -- Copy some basics
    self.tilewidth = self.raw.tilewidth
    self.tileheight = self.raw.tileheight
    self.width = self.raw.width * self.tilewidth
    self.height = self.raw.height * self.tileheight

    -- Load tilesets
    self.tiles = {}
    for _, tilesetdef in pairs(self.raw.tilesets) do
        local tileset
        if tilesetdef.source then
            -- External tileset; load it
            local tspath = relative_path(path, tilesetdef.source)
            tileset = resource_manager:get(tspath)
            if not tileset then
                tileset = TiledTileset(tspath, nil, resource_manager)
                resource_manager:add(tspath, tileset)
            end
        else
            tileset = TiledTileset(path, tilesetdef, resource_manager)
        end

        -- TODO spacing, margin
        local firstgid = tilesetdef.firstgid
        for relid = 0, tileset.tilecount - 1 do
            -- TODO gids use the upper three bits for flips, argh!
            -- see: http://doc.mapeditor.org/reference/tmx-map-format/#data
            -- also fix below
            self.tiles[firstgid + relid] = {
                tileset = tileset,
                tilesetid = relid,
            }
        end
    end

    -- Detach any automatic actor tiles
    -- TODO also more explicit actors via object layers probably
    self.actor_templates = {}
    for _, layer in pairs(self.raw.layers) do
        -- TODO this is largely copy/pasted from below
        local lx = layer.x * self.tilewidth + (layer.offsetx or 0)
        local ly = layer.y * self.tileheight + (layer.offsety or 0)
        -- FIXME i think these are deprecated for layers maybe?
        local width, height = layer.width, layer.height
        if layer.type == 'tilelayer' then
            local data = layer.data
            for t = 0, width * height - 1 do
                local gid = data[t + 1]
                local tile = self.tiles[gid]
                -- TODO lol put this in the tileset jesus
                -- TODO what about the tilepropertytypes
                if tile then
                    local proptable = tile.tileset.raw.tileproperties
                    if proptable then
                        local props = proptable[tile.tilesetid]
                        if props and props.actor then
                            local ty, tx = util.divmod(t, width)
                            table.insert(self.actor_templates, {
                                name = props.actor,
                                position = Vector(
                                    lx + tx * self.raw.tilewidth,
                                    ly + ty * self.raw.tileheight),
                            })
                            data[t + 1] = 0
                        end
                    end
                end
            end
        elseif layer.type == 'objectgroup' then
            for _, object in ipairs(layer.objects) do
                if object.type == 'player start' then
                    self.player_start = Vector(object.x, object.y)
                end
            end
        end
    end
end

function TiledMap:add_to_collider(collider, submap_name)
    -- TODO injecting like this seems...  wrong?  also keeping references to
    -- the collision shapes /here/?  this object should be a dumb wrapper and
    -- not have any state i think.  maybe return a structure of shapes?
    if not self.shapes then
        self.shapes = {}
    end
    for _, layer in pairs(self.raw.layers) do
        -- FIXME use the prop, and don't add the main map stuff
        if layer.type == 'tilelayer' and (layer.visible or layer.name == submap_name) then
            local lx = layer.x * self.tilewidth + (layer.offsetx or 0)
            local ly = layer.y * self.tileheight + (layer.offsety or 0)
            local width, height = layer.width, layer.height
            local data = layer.data
            for t = 0, width * height - 1 do
                local gid = data[t + 1]
                local tile = self.tiles[gid]
                if tile then
                    local shape = tile.tileset:get_collision(tile.tilesetid)
                    if shape then
                        local ty, tx = util.divmod(t, width)
                        shape:move(
                            lx + tx * self.raw.tilewidth,
                            ly + ty * self.raw.tileheight)
                        self.shapes[shape] = true
                        collider:add(shape)
                    end
                end
            end
        end
    end
end

-- Draw the whole map
function TiledMap:draw(layer_name, origin, width, height)
    -- TODO origin unused.  is it in tiles or pixels?
    local tw, th = self.raw.tilewidth, self.raw.tileheight
    for _, layer in pairs(self.raw.layers) do
        if layer.name == layer_name then
        local x, y = layer.x, layer.y
        local width, height = layer.width, layer.height
        local data = layer.data
        for t = 0, width * height - 1 do
            local gid = data[t + 1]
            if gid ~= 0 then
                local tile = self.tiles[gid]
                local dy, dx = util.divmod(t, width)
                -- TODO don't draw tiles not on the screen
                love.graphics.draw(
                    tile.tileset.image,
                    tile.tileset.quads[tile.tilesetid],
                    -- convert tile offsets to pixels
                    (x + dx) * tw, (y + dy) * th,
                    0, 1, 1)
            end
        end
        end
    end
end

return {
    TiledMap = TiledMap,
    TiledTileset = TiledTileset,
}
