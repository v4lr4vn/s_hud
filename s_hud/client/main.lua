--[[ s_hud — per-player HUD layout manager.

     Any resource with a movable on-screen element opts in with a local event:

       TriggerEvent('s_hud:register', {
           id    = 'wyrd_health',      -- unique key
           label = 'Wyrd Health',      -- shown in the editor
           dx = 2, dy = 68,            -- default position, % of screen (top-left)
           w = 248, h = 96,            -- approx size in px (for the editor box)
       })

     s_hud merges in the player's saved position and fires back:

       AddEventHandler('s_hud:apply', function(id, x, y) ... position your UI ... end)

     Players run /hud to drag everything where they want. Positions persist
     per-player via KVP — no database, no server. Re-register on 's_hud:ready'
     so load order never matters. ]]

local KVP_KEY  = 's_hud:layout'
local registry = {}   -- id -> { label, dx, dy, w, h, x, y }
local saved    = {}   -- id -> { x, y }  (from KVP)
local editing  = false

local function loadSaved()
    local raw = GetResourceKvpString(KVP_KEY)
    if raw then
        local ok, t = pcall(json.decode, raw)
        if ok and type(t) == 'table' then saved = t end
    end
end

local function persist()
    local out = {}
    for id, e in pairs(registry) do out[id] = { x = e.x, y = e.y } end
    SetResourceKvp(KVP_KEY, json.encode(out))
end

-- merge a registration with any saved position (saved wins over default)
local function register(def)
    if type(def) ~= 'table' or not def.id then return end
    local s = saved[def.id]
    registry[def.id] = {
        label = def.label or def.id,
        dx = tonumber(def.dx) or 50, dy = tonumber(def.dy) or 50,
        w  = tonumber(def.w)  or 200, h = tonumber(def.h) or 60,
        x  = (s and tonumber(s.x)) or tonumber(def.dx) or 50,
        y  = (s and tonumber(s.y)) or tonumber(def.dy) or 50,
    }
    TriggerEvent('s_hud:apply', def.id, registry[def.id].x, registry[def.id].y)
end

AddEventHandler('s_hud:register', register)

local function openEditor()
    local els = {}
    for id, e in pairs(registry) do
        els[#els + 1] = { id = id, label = e.label, x = e.x, y = e.y, dx = e.dx, dy = e.dy, w = e.w, h = e.h }
    end
    if #els == 0 then
        lib.notify({ title = 'HUD', description = 'No movable HUD elements are registered yet.', type = 'inform' })
        return
    end
    table.sort(els, function(a, b) return a.label < b.label end)
    editing = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'hud:edit', elements = els })
end

RegisterNUICallback('hud:save', function(body, cb)
    if type(body) == 'table' and type(body.layout) == 'table' then
        for id, pos in pairs(body.layout) do
            local e = registry[id]
            if e and type(pos) == 'table' then
                local nx, ny = tonumber(pos.x), tonumber(pos.y)
                e.x = nx and math.max(0, math.min(100, nx)) or e.x
                e.y = ny and math.max(0, math.min(100, ny)) or e.y
                TriggerEvent('s_hud:apply', id, e.x, e.y)
            end
        end
        persist()
    end
    editing = false
    SetNuiFocus(false, false)
    cb({ ok = true })
    lib.notify({ title = 'HUD', description = 'Layout saved.', type = 'success' })
end)

RegisterNUICallback('hud:close', function(_, cb)
    editing = false
    SetNuiFocus(false, false)
    cb({ ok = true })
end)

RegisterCommand('hud', function() openEditor() end, false)
RegisterKeyMapping('hud', 'Open the HUD layout editor', 'keyboard', '')

exports('Get', function(id) local e = registry[id]; return e and { x = e.x, y = e.y } or nil end)
exports('OpenEditor', function() openEditor() end)
exports('IsEditing', function() return editing end)

-- ===== built-in player HUD (hunger / thirst / stamina / armour / IDs) =====
-- Hide the native GTA HUD chrome (cash, wanted, weapon, names). Minimap and
-- reticle stay. On-screen cash is gone — the wallet is /cash only.
local HIDE = { 1, 2, 3, 4, 6, 7, 8, 9, 13, 18, 19, 20, 21, 22 }
CreateThread(function()
    while true do
        Wait(0)
        for i = 1, #HIDE do HideHudComponentThisFrame(HIDE[i]) end
    end
end)

-- the player HUD is movable through the same editor
local PHUD_ID = 'player_hud'
AddEventHandler('s_hud:apply', function(id, x, y)
    if id == PHUD_ID then SendNUIMessage({ action = 'hud:pos', x = x, y = y }) end
end)

local stamina = 100.0
CreateThread(function()
    while true do
        Wait(250)
        local ped = PlayerPedId()
        if IsPedSprinting(ped) then stamina = math.max(0, stamina - 6)
        else stamina = math.min(100, stamina + 4) end
        local n = LocalPlayer.state['saga:needs'] or { hunger = 100, thirst = 100 }
        SendNUIMessage({
            action = 'hud:player', show = true,
            hunger = math.floor(n.hunger or 100), thirst = math.floor(n.thirst or 100),
            stamina = math.floor(stamina), armour = GetPedArmour(ped),
            sagaId = LocalPlayer.state['saga:id'] or '\u{2014}',
            playerId = GetPlayerServerId(PlayerId()),
        })
    end
end)

-- ===== minimap (replaces the native minimap; the streamed .gfx removes the
-- health/armour ring — the only way to do it). Movable through the editor like
-- the NUI panels, though as a native element its positioning is coarser.
-- Assets under stream/ are from ps-hud (GPL-3.0) — see NOTICE.md. =====
local MAP_ID   = 'minimap'
local mapBase  = { dx = 1.0, dy = 72.0, w = 230, h = 175 }
local mapShape = (Hud.config and Hud.config.minimapShape) or 'square'
local mapOff   = { x = 0.0, y = 0.0 }

local function applyMap()
    local defAspect = 1920 / 1080
    local rx, ry = GetActiveScreenResolution()
    local aspect = (rx > 0 and ry > 0) and (rx / ry) or defAspect
    local o = (aspect > defAspect) and (((defAspect - aspect) / 3.6) - 0.008) or 0.0
    local ox, oy = mapOff.x, mapOff.y
    if mapShape == 'circle' then
        RequestStreamedTextureDict('circlemap', false)
        local t = 0; while not HasStreamedTextureDictLoaded('circlemap') and t < 60 do Wait(50); t = t + 1 end
        SetMinimapClipType(1)
        AddReplaceTexture('platform:/textures/graphics', 'radarmasksm', 'circlemap', 'radarmasksm')
        AddReplaceTexture('platform:/textures/graphics', 'radarmask1g', 'circlemap', 'radarmasksm')
        SetMinimapComponentPosition('minimap',      'L', 'B', -0.0100 + o + ox, -0.030 + oy, 0.180, 0.258)
        SetMinimapComponentPosition('minimap_mask', 'L', 'B',  0.200  + o + ox,  0.0   + oy, 0.065, 0.20)
        SetMinimapComponentPosition('minimap_blur', 'L', 'B', -0.00   + o + ox,  0.015 + oy, 0.252, 0.338)
    else
        RequestStreamedTextureDict('squaremap', false)
        local t = 0; while not HasStreamedTextureDictLoaded('squaremap') and t < 60 do Wait(50); t = t + 1 end
        SetMinimapClipType(0)
        AddReplaceTexture('platform:/textures/graphics', 'radarmasksm', 'squaremap', 'radarmasksm')
        AddReplaceTexture('platform:/textures/graphics', 'radarmask1g', 'squaremap', 'radarmasksm')
        SetMinimapComponentPosition('minimap',      'L', 'B',  0.0  + o + ox, -0.047 + oy, 0.1638, 0.183)
        SetMinimapComponentPosition('minimap_mask', 'L', 'B',  0.0  + o + ox,  0.0   + oy, 0.128,  0.20)
        SetMinimapComponentPosition('minimap_blur', 'L', 'B', -0.01 + o + ox,  0.025 + oy, 0.262,  0.300)
    end
    SetBlipAlpha(GetNorthRadarBlip(), 0)
    SetRadarBigmapEnabled(true, false); Wait(50); SetRadarBigmapEnabled(false, false)
    DisplayRadar(true)
end

AddEventHandler('s_hud:apply', function(id, x, y)
    if id == MAP_ID then
        mapOff.x = (x - mapBase.dx) / 100.0
        mapOff.y = (mapBase.dy - y) / 100.0
        applyMap()
    end
end)

RegisterCommand('minimapshape', function(_, a)
    local s = (a[1] or ''):lower()
    if s == 'square' or s == 'circle' then mapShape = s; applyMap() end
end, false)

AddEventHandler('onResourceStart', function(res)
    if res == GetCurrentResourceName() then Wait(800); applyMap() end
end)

CreateThread(function()
    loadSaved()
    TriggerEvent('s_hud:ready')   -- nudge resources to (re)register now we're up
    register({ id = PHUD_ID, label = 'Player HUD', dx = 83, dy = 86, w = 210, h = 120 })
    while not NetworkIsSessionStarted() do Wait(250) end
    Wait(1000)
    applyMap()
    register({ id = MAP_ID, label = 'Minimap', dx = mapBase.dx, dy = mapBase.dy, w = mapBase.w, h = mapBase.h })
end)
