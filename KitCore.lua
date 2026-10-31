local addonName, ns = ...

---------------------------------------------------------------------------
-- Kit Core: the parts every kit shares, for WoW Forever.
--
-- A kit is a round button that opens into a ring of slots. Kit Core builds
-- and runs all of that from a description the kit hands it: the button,
-- its slots (with the small corner buttons some of them carry), opening and
-- closing, pinning a slot so it stays out with the kit closed, flyouts of
-- choices, dragging, keeping it on screen, laying it out on a screen edge,
-- the settings panel, the minimap button, slash commands and key bindings.
-- The kit itself only says what each slot does.
--
-- Kit Dock is optional. With it, a kit can join the gold pin with the other
-- kits and snap to the screen edges (or only the edges); without it, the kit
-- stands on its own.
--
-- Every kit ships its own copy of this file in Libs/KitCore. The newest copy
-- loaded runs for every kit (see VERSION), the same way Kit Dock works.
--
-- Flyouts are secure: their choices cast spells, use items or change what a
-- slot holds, and they open and close in combat too. Where the choices sit
-- is worked out out of combat, whenever the kit refreshes.
--
-- So does the kit button (from v5), for a kit that floats or sits on a screen
-- edge. The game won't let an addon move or show a secure slot in combat, so
-- every refresh works out both layouts, open and closed, and hands each slot
-- where it goes and whether it shows in each. A click on the button in combat
-- runs a secure snippet that switches the slots between the two. Kits on the
-- pin with other kits still open and close out of combat only.
--
-- From v6 the kit can be dragged in combat too (same kits): a faint copy of
-- the button (not secure) follows the mouse, and where you let go, a secure
-- snippet puts the real button (see GRIP_CLICK). When combat ends the drop
-- is finished like any other drag: saved, and snapped to an edge or another
-- kit if it's near one.
---------------------------------------------------------------------------

local VERSION = 9
local C = _G.KitCore
if C and (C.version or 0) >= VERSION then
    ns.Core = C
    return
end
C = C or {}
_G.KitCore = C
ns.Core = C
C.version = VERSION

-- Kits are tables with this as their metatable. A newer copy loaded later
-- replaces the methods in place, so kits made by an older copy pick them up.
C.proto = C.proto or {}
local Kit = C.proto
Kit.__index = Kit

---------------------------------------------------------------------------
-- Helpers (also for the kits: KitCore.U)
---------------------------------------------------------------------------

local U = {}
C.U = U

function U.Sealed(v)
    return type(issecretvalue) == "function" and issecretvalue(v)
end

function U.ItemCount(id)
    if not id then return 0 end
    if C_Item and C_Item.GetItemCount then return C_Item.GetItemCount(id) or 0 end
    if GetItemCount then return GetItemCount(id) or 0 end
    return 0
end

-- Uses left, counting charges rather than items, like bag slots do.
function U.ItemUses(id)
    if not id then return 0 end
    local n
    if C_Item and C_Item.GetItemCount then n = C_Item.GetItemCount(id, false, true)
    elseif GetItemCount then n = GetItemCount(id, false, true) end
    return n or U.ItemCount(id)
end

function U.Owned(id) return U.ItemCount(id) > 0 end

function U.ItemIcon(id)
    local icon = id and C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)
    return icon or 134400 -- question mark
end

function U.ItemName(id)
    return id and C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id) or nil
end

function U.SpellIcon(id)
    return id and C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id) or 134400
end

function U.SpellName(id)
    return id and C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id) or nil
end

-- A spell you know, looked up by name (the version in your spellbook), or nil.
function U.SpellByName(name)
    if not (name and C_Spell and C_Spell.GetSpellInfo) then return nil end
    local ok, info = pcall(C_Spell.GetSpellInfo, name)
    return ok and info and info.spellID or nil
end

function U.Known(spellID)
    if not spellID then return false end
    return (IsPlayerSpell and IsPlayerSpell(spellID))
        or (C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(spellID))
        or false
end

function U.ItemCooldown(id)
    if C_Container and C_Container.GetItemCooldown then return C_Container.GetItemCooldown(id) end
    if C_Item and C_Item.GetItemCooldown then return C_Item.GetItemCooldown(id) end
end

function U.SpellCooldown(id)
    if C_Spell and C_Spell.GetSpellCooldown then
        local ok, info = pcall(C_Spell.GetSpellCooldown, id)
        if ok and info then return info.startTime, info.duration, info.isEnabled end
        return
    end
    if GetSpellCooldown then return GetSpellCooldown(id) end
end

function U.SetCooldown(cd, start, duration, enable)
    if start and duration then
        if U.Sealed(start) or U.Sealed(duration) then
            pcall(cd.SetCooldown, cd, start, duration)
        elseif duration > 1.5 and enable ~= 0 and enable ~= false then -- (not the global cooldown)
            cd:SetCooldown(start, duration)
        else
            cd:Clear()
        end
    else
        cd:Clear()
    end
end

function U.FormatLeft(left)
    if left >= 3600 then return math.floor(left / 3600) .. "h" end
    if left >= 60 then return math.ceil(left / 60) .. "m" end
    return tostring(math.ceil(left))
end

function U.InList(list, v)
    for i, x in ipairs(list or {}) do if x == v then return i end end
end

function U.ApplyDefaults(t, d)
    for k, v in pairs(d) do
        if t[k] == nil then
            if type(v) == "table" then
                t[k] = {}
                U.ApplyDefaults(t[k], v)
            else
                t[k] = v
            end
        end
    end
end

-- A value, or what a function gives for it.
local function Val(x, ...)
    if type(x) == "function" then return x(...) end
    return x
end
U.Val = Val

-- Art ships in several sizes: WoW doesn't mipmap addon TGAs, and plain
-- bilinear sampling goes jagged once a texture is shrunk past 2x. Pick the
-- smallest size that's still at least the on-screen pixel size.
local ART_SIZES = { 32, 48, 64, 96, 128, 256 }  -- slot rings
local PROF_RING_SIZES = { 32, 48, 64, 128 }     -- the small round buttons' ring
local function ArtSize(px, sizes)
    for _, s in ipairs(sizes) do if px <= s then return s end end
    return sizes[#sizes]
end
local function ScreenPx(frame, units)
    local h = GetPhysicalScreenSize and select(2, GetPhysicalScreenSize()) -- (an "and" would keep only the width)
    if h and h > 0 then return units * frame:GetEffectiveScale() * h / 768 end
    return units
end

U.ArtSize, U.ScreenPx = ArtSize, ScreenPx
C.ART_SIZES = ART_SIZES

-- Things that only exist on newer clients: tried, and skipped if missing.
local function Try(f, ...) if f then return pcall(f, ...) end end

-- In a fight, or about to be: as combat starts (PLAYER_REGEN_DISABLED, when
-- First Aid Kit opens itself) the player is already in combat but frames
-- can still change for a moment. Anything that would hide at the end of an
-- animation must hide at once then: by the time the animation ends, combat
-- won't let it, and it pops back up instead.
local function Fighting()
    if InCombatLockdown() then return true end
    return UnitAffectingCombat and UnitAffectingCombat("player") and true or false
end
U.Fighting = Fighting

-- Slots part-way through sliding out or in: [btn] = its kit (see SlideTo).
local sliding = {}

-- Any of this kit's slots sliding right now.
function Kit:Sliding()
    for _, k in pairs(sliding) do
        if k == self then return true end
    end
    return false
end

---------------------------------------------------------------------------
-- Glows: one clock pulses every glow of every kit.
---------------------------------------------------------------------------

local GLOW_HALF = 0.7
C.glows = C.glows or setmetatable({}, { __mode = "k" })
C.glowClock = C.glowClock or CreateFrame("Frame")
C.glowClock:SetScript("OnUpdate", function()
    local t = GetTime() % (GLOW_HALF * 2) / GLOW_HALF
    local k = t <= 1 and t or (2 - t)
    k = 0.5 - 0.5 * math.cos(k * math.pi)
    local alpha = 0.35 + 0.65 * k
    for g in pairs(C.glows) do
        if g:IsShown() then g:SetAlpha(alpha) end
    end
end)

---------------------------------------------------------------------------
-- Saved settings every kit has. A kit's own defaults go on top.
---------------------------------------------------------------------------

C.BASE_DEFAULTS = {
    point = { "CENTER", "CENTER", 0, -160, "ui" },
    scale = 1,
    kitSize = 1,
    shown = true,          -- false: the whole kit is hidden (settings or the shared minimap menu)
    locked = false,
    fadeIdle = false,
    tooltipDefault = false, -- slot tooltips in the game's usual spot instead of beside the slot
    roundSlots = true,
    hideInCombat = false,
    chatNotices = true,    -- false: the kit's own notices stay out of chat (slash commands still answer)
    minimapButton = true,
    minimapAngle = 200,
    facing = "up",         -- which way the layout points while the kit floats: up, down, left, right
    flyoutHide = 0.5,      -- seconds a drawer stays open in combat after the mouse leaves it
}

C.BASE_CHAR = {
    pinned = {}, -- [slotKey] = true: out even with the kit closed
    picks = {},  -- [slotKey] = what the slot holds, when you chose it
    order = {},  -- [slotKey] = { value, ... } your order for that slot's flyout
}

---------------------------------------------------------------------------
-- Making a kit
--
-- cfg (the kit's description):
--   addon         the kit addon's folder name
--   key           short key for Kit Dock ("wk")
--   name          "Warlock Kit"
--   prefix        frame name prefix and saved-variable stem ("WarlockKit")
--   color         hex colour for chat ("9482c9")
--   media         the kit's media folder (rings, masks, glows)
--   db, charDb    saved variable names ("WarlockKitDB", "WarlockKitCharDB")
--   defaults, charDefaults   on top of the base ones
--   dock          ns.Dock (Kit Dock), or nil
--   edgesOnly     never joins the pin, only the screen edges
--   alwaysHideInCombat  the kit always hides in combat (nothing on it is any use
--                 in a fight): no "Hide in combat" setting for it
--   kitSize, slotSize  (60, 37)
--   roundKit      the kit button is a round icon with a ring
--   kitRing, kitIconInset  art name for that ring ("kit_ring": kit_ring_32..256,
--                 covering the whole button) and how far in the icon sits
--   AfterBuild(kit)  once the kit and its slots exist (add extra buttons)
--   OnFacing(kit)    the layout direction changed (kit:Face(x, y) turns a
--                    spot the same way; kit:FaceDir("down") a direction)
--   slots         { slot, ... } (below)
--   ring          { keys = { slotKey, ... }, from = deg, to = deg, radius = r }
--                 (or a list of them)
--                 slots spread evenly along this arc round the kit (degrees,
--                 0 = right, 90 = up), evenly spaced as if all were there;
--                 when some are hidden the rest close up round the middle of
--                 the arc, gliding over
--   edgeCols      { { slotKey, ... }, ... } columns on a screen edge, from the edge in
--   EdgeExtraCol(kit, hypothetical, asOpen)  one more column after those (non-slot
--                 frames, like timers): { { frame = f, size = n }, ... }
--   extraFrames(kit)  those frames (any that can show), so they're scaled
--                 and glide along when the kit moves
--   PlaceExtras(kit, angle)  place those frames off an edge: angle is nil
--                 normally, or the fan's direction while shrunk on the dock
--   PinSettings(kit, S)  more "Always show" boxes in the Slots section
--   menuOrder     { slotKey, ... } the order slots are listed in the settings
--   minimapArt    full-size art for the minimap button (it has its own rim)
--   glowColor     { r, g, b } the kit's glow colour
--   edgeBeside    { slotKey, ... } small slots that sit right beside the kit
--                 button on a screen edge, along the edge: the ones showing
--                 take turns before (above / left of) and after it, working
--                 outward; leave them out of edgeCols
--   divider       { y, width, texture, below = { slotKey, ... }, edgeAfter = n }
--                 a line across the kit at y while it's open and any of the
--                 "below" slots show; on an edge, between column n and n + 1
--   slash         { "/wk", "/warlockkit" }
--   bindingHeader "WARLOCKKIT" (as in Bindings.xml)
--   KitArt(kit), KitTooltip(kit), BeforeRefresh(kit), Tick(kit)
--                 (a refresh also runs BeforeRefresh and every slot's Update once
--                 as a trial, with kit.open flipped and kit.trial set, to work out
--                 the other layout; change frames only when kit.trial is nil)
--   OnCombatToggle(kit, open)  the kit button opened (true) or closed (false) the
--                 kit in combat: move or show the kit's own extra frames to match
--                 (the slots are already done; a refresh follows when combat ends)
--   OnShapes(kit)     after slot shapes / ring art are (re)applied
--   Busy(kit)         true while the kit shouldn't fade (fade when idle)
--   events        { EVENT = function(kit, ...) end }
--   unitEvents    { EVENT = { units = { "player" }, fn = function(kit, ...) end } }
--   Settings(kit, S)    the kit's own section of the settings panel
--   Menu(kit, root)     the kit's own lines in its right-click menu, between
--                 "Pin in place" and "Settings" (root is the game's menu
--                 description: root:CreateCheckbox, root:CreateButton, ...;
--                 kit:MenuToggle(root, label, dbKey, after) adds an on/off line)
--   Slash(kit, cmd, rest) true if it handled cmd;  helpLines { "..." }
--   minimapIcon   texture for the minimap button
--
-- A slot:
--   key, label, pos = { x, y } (from the kit's centre, +y up)
--   grid          which way its flyout opens: "up", "down", "left", "right"
--   small         a small round button (22) instead of a full slot
--   rim           (small slots) on a screen edge or shrunk on the dock it
--                 sits on the kit's rim: toward the middle of the screen, or
--                 away from the pin
--   flyGap        extra room between the slot and its flyout (a sub below it)
--   OnDrop(kit, btn)   something was dropped on the slot (cursor item)
--   Setup(kit, btn)    once, after the slot is made (extra scripts)
--   noPin         can't be pinned
--   tier          shrunk on the dock, lower tiers fan out nearest the button
--                 (before the pinned-first, slot-order rule)
--   binding       key binding label (default "Use <label>")
--   flyout        "right": right-click opens its flyout; "left": any click does
--   Choices(kit, btn)  the flyout's choices (out of combat; see LayoutFlyout)
--   assign        a click on the slot does its assigned choice: the last one
--                 you clicked in its flyout (saved), else default
--   default       the assigned choice's value until you pick one (or a function)
--   reorder       its flyout's choices (those with a value) can be dragged into
--                 your own order, saved per character
--   keepEmpty     with nothing to assign yet, the slot still shows (empty) rather
--                 than hiding (or a function deciding it)
--   Update(kit, btn)   out of combat: set its attributes; btn.hidden hides it
--   Paint(kit, btn)    cosmetic, any time: icon, count, glow, cooldown
--   Tooltip(kit, btn)  fill GameTooltip (already owned)
--   Pop(kit, btn)      true to show it with the kit closed (like a pin)
--   OnAttribute(kit, btn, name, value)  a flyout choice changed an attribute
--   OnPick(kit, btn, value)             a flyout "pick" choice (out of combat)
--   sub = { key, label, Update(kit, sb), Paint(kit, sb), Tooltip(kit, sb) }
--         a small round button on the slot's corner (below = true: under the
--         slot instead, except on a screen edge, where it's on the corner)
---------------------------------------------------------------------------

function C.NewKit(cfg)
    local self = setmetatable({}, Kit)
    self.cfg = cfg
    self.key, self.name, self.prefix = cfg.key, cfg.name, cfg.prefix
    self.media = cfg.media
    self.Dock = cfg.dock
    self.KIT = cfg.kitSize or 60
    self.BTN = cfg.slotSize or 37
    self.slots, self.slotByKey, self.order = {}, {}, {}
    for i, s in ipairs(cfg.slots) do
        self.slotByKey[s.key] = s
        self.order[s.key] = i
    end
    self.open, self.hovering = false, 0
    self.flyouts = {}
    self.snap = {} -- [true] = the open layout, [false] = the closed one (see StoreSnap)

    local events = CreateFrame("Frame")
    self.events = events
    events:RegisterEvent("ADDON_LOADED")
    events:RegisterEvent("PLAYER_LOGIN")
    events:SetScript("OnEvent", function(_, event, ...) self:OnEvent(event, ...) end)

    -- Key binding labels (the kit's Bindings.xml names the buttons).
    local H = cfg.bindingHeader
    if H then
        _G["BINDING_HEADER_" .. H] = cfg.name
        _G["BINDING_NAME_" .. H .. "_TOGGLE"] = "Open / close the kit"
        for _, slot in ipairs(cfg.slots) do
            _G["BINDING_NAME_CLICK " .. cfg.prefix .. "Slot_" .. slot.key .. ":LeftButton"] =
                slot.binding or ("Use " .. slot.label:lower())
        end
    end
    _G[cfg.prefix .. "_Toggle"] = function() self:Toggle() end
    _G[cfg.prefix .. "_OnCompartmentClick"] = function() self:OpenSettings() end

    if cfg.slash then
        local id = cfg.prefix:upper()
        for i, s in ipairs(cfg.slash) do _G["SLASH_" .. id .. i] = s end
        SlashCmdList[id] = function(msg) self:Slash(msg) end
    end
    return self
end

-- Chat messages. With "Chat messages" off in settings, only replies to a
-- slash command (and force, for something that's gone wrong) get through.
function Kit:Print(msg, force)
    if self.trial then return end -- (a trial layout says nothing)
    if not force and not self.inSlash and self.db and self.db.chatNotices == false then return end
    DEFAULT_CHAT_FRAME:AddMessage("|cff" .. (self.cfg.color or "ffd100") .. "[" .. self.name .. "]|r " .. msg)
end

-- Right-click and shift-right-click run through the secure template's custom
-- action types; kept from firing twice in a row.
function Kit:Debounced()
    local now = GetTime()
    if now - (self.lastCustom or 0) < 0.2 then return false end
    self.lastCustom = now
    return true
end

---------------------------------------------------------------------------
-- Tooltips
---------------------------------------------------------------------------

local function DefaultAnchor(owner)
    if GameTooltip_SetDefaultAnchor then
        GameTooltip_SetDefaultAnchor(GameTooltip, owner)
    else
        GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    end
end

-- Slot, sub and flyout tooltips sit beside what you're hovering, or where the
-- game puts its own ("Default tooltip position"). The kit button's always
-- goes in the game's spot.
function Kit:TipOwner(owner)
    if self.db.tooltipDefault then DefaultAnchor(owner) else GameTooltip:SetOwner(owner, "ANCHOR_RIGHT") end
end

-- Hovering the kit button, a slot or a sub. Leaving hides the tooltip,
-- unless the kit's slots are sliding: then the tooltip stays as it is until
-- they've settled (SettleTip), so it doesn't flicker as slots pass under a
-- still pointer.
function Kit:Hover(on)
    self.hovering = math.max(0, self.hovering + (on and 1 or -1))
    self:ApplyFade()
    if not on and not self:Sliding() then GameTooltip:Hide() end
end

-- Show a frame's tooltip when it's hovered, but not while the kit's slots are
-- sliding (they'd pass under the pointer one after another). frame.kcTip is
-- kept for SettleTip.
function Kit:HoverTip(frame, show)
    frame.kcKit, frame.kcTip = self, show
    frame:SetScript("OnEnter", function(b)
        self:Hover(true)
        if not self:Sliding() then show(b) end
    end)
    frame:SetScript("OnLeave", function() self:Hover(false) end)
end

-- The slides are over: the tooltip for whatever of this kit is under the
-- pointer now, or none if that's nothing of the kit's.
function Kit:SettleTip()
    if self:Sliding() then return end
    local foci = GetMouseFoci and GetMouseFoci()
    local focus = foci and foci[1] or (GetMouseFocus and GetMouseFocus()) or nil
    if focus and focus.kcKit == self and focus.kcTip and focus:IsVisible() then
        focus.kcTip(focus)
        return
    end
    local owner = GameTooltip:IsShown() and GameTooltip:GetOwner()
    if owner and owner.kcKit == self then GameTooltip:Hide() end
end

---------------------------------------------------------------------------
-- Glows
---------------------------------------------------------------------------

function Kit:AddGlow(frame, texture, sizeMul)
    local g = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    g:SetTexture(self.media .. texture)
    g:SetBlendMode("ADD")
    g:SetPoint("CENTER")
    g:SetSize(frame:GetWidth() * sizeMul, frame:GetHeight() * sizeMul)
    g:Hide()
    C.glows[g] = true
    frame.glow = g
end

-- color: { r, g, b }, or the kit's glow colour.
function Kit:SetGlow(frame, on, color)
    if not frame.glow then return end
    if on then
        local c = color or self.cfg.glowColor or { 1, 0.82, 0.3 }
        frame.glow:SetVertexColor(c[1], c[2], c[3])
        if not frame.glow:IsShown() then frame.glow:Show() end
    elseif frame.glow:IsShown() then
        frame.glow:Hide()
    end
end

---------------------------------------------------------------------------
-- Buttons
---------------------------------------------------------------------------

function Kit:MakeItemButton(name, parent, secure)
    local base = secure and "SecureActionButtonTemplate" or nil
    local ok, b = pcall(CreateFrame, "Button", name, parent, (base and (base .. ", ") or "") .. "ItemButtonTemplate")
    if not ok or not b then
        b = CreateFrame("Button", name, parent, base)
    end
    b:SetSize(self.BTN, self.BTN)
    local bg = b:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetAllPoints()
    local atlas = "bags-item-slot64"
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then
        bg:SetAtlas(atlas)
    else
        bg:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")
    end
    b.slotBg = bg

    local icon = b.icon or b.Icon or (name and _G[name .. "IconTexture"])
    local count = b.Count or (name and _G[name .. "Count"])
    if icon and count then
        b.icon, b.count = icon, count
    else
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetPoint("TOPLEFT", 2, -2)
        b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
        b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        b.count:SetPoint("BOTTOMRIGHT", -2, 2)
        b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        b:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    end
    b.border = b:CreateTexture(nil, "ARTWORK", nil, 7)
    b.border:SetTexture(self.media .. "slot_border")
    b.border:SetPoint("TOPLEFT", -1, 1)
    b.border:SetPoint("BOTTOMRIGHT", 1, -1)
    if secure then
        -- Act on the button's release only, mouse or key binding alike, so
        -- a flyout opened by a click isn't shut again by the same click.
        b:RegisterForClicks("AnyUp", "AnyDown")
        b:SetAttribute("useOnKeyDown", false)
    end
    return b
end

function Kit:RingArt(b)
    return self.media .. "ring_slot_" .. ArtSize(ScreenPx(b, b:GetWidth() + 2), ART_SIZES)
end

function Kit:SmallRingArt(b)
    return self.media .. "ring_prof_" .. ArtSize(ScreenPx(b, b:GetWidth()), PROF_RING_SIZES)
end

-- Key binding labels, shortened the way the default action bars show them.
local function ShortKey(key)
    local t = (GetBindingText and GetBindingText(key, true)) or key
    t = t:gsub("SHIFT%-", "s-"):gsub("CTRL%-", "c-"):gsub("ALT%-", "a-"):gsub("META%-", "m-")
    t = t:gsub("Mouse Button ", "M"):gsub("BUTTON", "M"):gsub("Middle Mouse", "M3")
    t = t:gsub("Num Pad ", "N"):gsub("NUMPAD", "N")
    t = t:gsub("Mouse Wheel Up", "WU"):gsub("Mouse Wheel Down", "WD")
    t = t:gsub("MOUSEWHEELUP", "WU"):gsub("MOUSEWHEELDOWN", "WD")
    return t
end

function Kit:UpdateHotkeys()
    for _, btn in pairs(self.slots) do
        if btn.hotkey then
            local key = GetBindingKey("CLICK " .. btn:GetName() .. ":LeftButton")
            btn.hotkey:SetText(key and ShortKey(key) or "")
        end
    end
end

-- Round (gold ring) or square (bag slot) look for a full-size slot.
function Kit:ApplyShape(b, round)
    if b.isSmall then return end
    round = round and true or false
    local MASK = self.media .. "circle_mask"
    if b.roundParts and round then
        b.roundParts.ring:SetTexture(self:RingArt(b), nil, nil, "LINEAR")
    end
    if b.isRound == round then return end
    b.isRound = round
    if not b.roundParts then
        local mask = b:CreateMaskTexture()
        mask:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetPoint("TOPLEFT", 1, -1)
        mask:SetPoint("BOTTOMRIGHT", -1, 1)
        local slotMask = b:CreateMaskTexture()
        slotMask:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        slotMask:SetPoint("TOPLEFT", 1, -1)
        slotMask:SetPoint("BOTTOMRIGHT", -1, 1)
        local ring = b:CreateTexture(nil, "OVERLAY", nil, 6)
        ring:SetTexture(self:RingArt(b), nil, nil, "LINEAR")
        ring:SetPoint("TOPLEFT", -1, 1)
        ring:SetPoint("BOTTOMRIGHT", 1, -1)
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetTexture(self.media .. "glow_ring")
        hl:SetBlendMode("ADD")
        hl:SetPoint("CENTER")
        hl:SetSize(b:GetWidth() * 1.35, b:GetHeight() * 1.35)
        b.roundParts = { mask = mask, slotMask = slotMask, ring = ring, hl = hl }
    end
    local p = b.roundParts
    p.ring:SetShown(round)
    p.hl:SetShown(round)
    if round then
        b.icon:AddMaskTexture(p.mask)
        b.slotBg:AddMaskTexture(p.slotMask)
    else
        b.icon:RemoveMaskTexture(p.mask)
        b.slotBg:RemoveMaskTexture(p.slotMask)
    end
    for _, t in ipairs({ b.border, b.IconBorder, b.GetNormalTexture and b:GetNormalTexture() }) do
        if t then t:SetAlpha(round and 0 or 1) end
    end
    for _, t in ipairs({ b.GetHighlightTexture and b:GetHighlightTexture(), b.GetPushedTexture and b:GetPushedTexture() }) do
        if t and t ~= p.hl then t:SetAlpha(round and 0 or 1) end
    end
    if b.glow then
        b.glow:SetTexture(self.media .. (round and "glow_ring" or "glow_square"))
        local mul = round and 1.6 or 1.9
        b.glow:SetSize(b:GetWidth() * mul, b:GetHeight() * mul)
    end
    if b.hotkey then
        b.hotkey:ClearAllPoints()
        b.hotkey:SetPoint("TOPRIGHT", b, "TOPRIGHT", round and -3 or -2, round and -4 or -3)
    end
    if b.pin then
        b.pin:ClearAllPoints()
        b.pin:SetPoint("CENTER", b, "CENTER", round and -11 or -13, round and 11 or 13)
    end
    if b.sel then b.sel:SetTexture(self.media .. (round and "glow_ring" or "glow_square")) end
    if b.cooldown then
        Try(b.cooldown.SetSwipeTexture, b.cooldown, round and MASK or "Interface\\Buttons\\WHITE8X8")
        Try(b.cooldown.SetUseCircularEdge, b.cooldown, round)
    end
end

-- The small round look (22 across, gold ring), for small slots and the
-- buttons on a slot's corner.
function Kit:MakeSmallRound(b)
    b:SetSize(22, 22)
    b.isSmall = true
    if b.slotBg then b.slotBg:Hide() end
    if b.border then b.border:SetAlpha(0) end
    for _, t in ipairs({ b.IconBorder, b.GetNormalTexture and b:GetNormalTexture(),
            b.GetHighlightTexture and b:GetHighlightTexture(), b.GetPushedTexture and b:GetPushedTexture() }) do
        if t then t:SetAlpha(0) end
    end
    if not b.icon then b.icon = b:CreateTexture(nil, "ARTWORK") end
    b.icon:ClearAllPoints()
    b.icon:SetPoint("TOPLEFT", 3, -3)
    b.icon:SetPoint("BOTTOMRIGHT", -3, 3)
    b.icon:SetTexCoord(0, 1, 0, 1)
    local mask = b:CreateMaskTexture()
    mask:SetTexture(self.media .. "circle_mask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(b.icon)
    b.icon:AddMaskTexture(mask)
    b.roundMask = mask
    b.ring = b:CreateTexture(nil, "OVERLAY", nil, 6)
    b.ring:SetAllPoints()
    b.ring:SetTexture(self:SmallRingArt(b), nil, nil, "LINEAR")
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture(self.media .. "glow_ring")
    hl:SetBlendMode("ADD")
    hl:SetPoint("CENTER")
    hl:SetSize(30, 30)
    b.roundHl = hl
    if b.hotkey then b.hotkey:Hide() end
    if b.count then b.count:Hide() end
end

function Kit:ApplyShapes()
    for _, btn in pairs(self.slots) do
        self:ApplyShape(btn, self.db.roundSlots)
        if btn.ring then btn.ring:SetTexture(self:SmallRingArt(btn), nil, nil, "LINEAR") end
        if btn.sub then btn.sub.ring:SetTexture(self:SmallRingArt(btn.sub), nil, nil, "LINEAR") end
    end
    for _, fly in pairs(self.flyouts) do
        for _, b in ipairs(fly.buttons) do self:ApplyShape(b, self.db.roundSlots) end
    end
    if self.cfg.OnShapes then self.cfg.OnShapes(self) end
end

-- Icon, greyed (and dimmed) when it can't be used right now.
function U.SetIcon(btn, texture, greyed)
    btn.icon:SetTexture(texture)
    btn.icon:SetDesaturated(greyed and true or false)
    local v = greyed and 0.6 or 1
    btn.icon:SetVertexColor(v, v, v)
end

---------------------------------------------------------------------------
-- The holder, the kit button and the secure header
---------------------------------------------------------------------------

-- A left click on the kit button in combat: switch every slot to the other
-- layout (where it goes and whether it shows, worked out out of combat and
-- left on each slot as attributes: kco* for the open layout, kcc* for the
-- closed one; see PushSnapshot), and close the flyouts, which belong to the
-- layout being left. Out of combat this does nothing: the click opens the
-- kit the usual way (animated, with the dock told). "kcready" is 0 when
-- this kit has no layouts to switch to (the kit open on the pin, or parked
-- in Kit Dock's box). A kit shrunk on the pin opens in its own slice there,
-- its slots fanned out in rings of 4 (from v8). Whether
-- it's combat comes from a state driver on the button itself ("kcincombat",
-- registered in BuildKit), which the game keeps right however early or late
-- combat's events arrive.
-- Switch the slots to the other layout. "kit" is the kit button's handle.
local TOGGLE_BODY = [[
    local want = "o"
    if kit:GetAttribute("kcisopen") == 1 then want = "c" end
    if want == "o" then kit:SetAttribute("kcisopen", 1) else kit:SetAttribute("kcisopen", 0) end
    for i = 1, NFLY do FLYOUTS[i]:Hide() end
    for i = 1, NSLOT do
        local b = SLOTS[i]
        if b:GetAttribute("kc" .. want .. "show") == 1 then
            b:ClearAllPoints()
            b:SetPoint("CENTER", kit, "CENTER", b:GetAttribute("kc" .. want .. "x") or 0, b:GetAttribute("kc" .. want .. "y") or 0)
            b:Show()
        else
            b:Hide()
        end
    end
]]
local KIT_PRE = [[
    if button ~= "LeftButton" or down then return end
    if self:GetAttribute("state-kcincombat") ~= "yes" then return end
    if self:GetAttribute("kcready") ~= 1 then return end
    local kit = self
]] .. TOGGLE_BODY

-- Moving the kit button in combat. Snippets only run from a few scripts
-- (OnClick among them, not OnMouseDown or OnMouseUp), and a click only
-- counts if you let go over the button you pressed. So in combat an unseen
-- secure "grip" button lies over the kit button (shown as combat starts,
-- see OnEvent), taking its left clicks on the press and on the release:
--   press    note where the mouse is (as a fraction across the holder, which
--            covers the screen) and, if the kit can move, stretch the grip
--            over the whole screen, so wherever you let go is still over it.
--   release  shrink the grip back onto the kit button. If the mouse moved
--            far enough, move the button by as much, kept on screen (its
--            slots are anchored to it, so they come too). If it hardly
--            moved, it was a click: open or close the kit (TOGGLE_BODY).
-- "kcmovable" is 1 for a kit that can move (pushed out of combat, see
-- PushMoveInfo); "kcks" is the button's scale against the holder's. Where it
-- put the button is left in "kcdropx"/"kcdropy" (holder units): asked
-- straight after, the game still gives the button's old spot. Each step
-- is noted in "kcmovestep", so when a move doesn't happen the kit can say
-- which part the game didn't allow.
local GRIP_CLICK = [[
    if button ~= "LeftButton" then return end
    local kit = self:GetFrameRef("kckit")
    local h = owner:GetFrameRef("kcholder")
    if down then
        GRABX, GRABY = nil, nil
        kit:SetAttribute("kcmovestep", "down")
        local mx, my = h:GetMousePosition()
        if mx and my then
            GRABX, GRABY = mx, my
            kit:SetAttribute("kcmovestep", "down-ok")
        end
        if kit:GetAttribute("kcmovable") == 1 then
            self:ClearAllPoints()
            self:SetAllPoints(h)
        end
        return
    end
    local x0, y0 = GRABX, GRABY
    GRABX, GRABY = nil, nil
    self:ClearAllPoints()
    self:SetAllPoints(kit)
    local drag = false
    if x0 then
        local mx, my = h:GetMousePosition()
        local W, H = h:GetWidth(), h:GetHeight()
        local dx, dy = 0, 0
        if mx and my then dx, dy = (mx - x0) * W, (my - y0) * H end
        drag = dx * dx + dy * dy >= 64 -- (moved 8 or more: a drag, not a click)
        local l, b, w, t = kit:GetRect()
        if drag and kit:GetAttribute("kcmovable") == 1 then
            kit:SetAttribute("kcmovestep", "up-pos")
            if l then
                kit:SetAttribute("kcmovestep", "up-rect")
                local ks = kit:GetAttribute("kcks") or 1
                local half = w * ks / 2
                local ox, oy = (l + w / 2) * ks, (b + t / 2) * ks
                local cx, cy = ox + dx, oy + dy
                if cx < half then cx = half elseif cx > W - half then cx = W - half end
                if cy < half then cy = half elseif cy > H - half then cy = H - half end
                local pin = kit:GetAttribute("kconpin") == 1 and self:GetFrameRef("kcpin")
                if pin then
                    -- On the pin with other kits: move every kit on it by as
                    -- much (this one kept on screen), then the pin. The kits
                    -- go to their own new spots first, read before anything
                    -- moves, so they get there whether or not they were
                    -- following the pin; after combat the dock puts them back
                    -- on it.
                    local mdx, mdy = cx - ox, cy - oy
                    local moves = newtable()
                    for i = 1, self:GetAttribute("kcdockn") or 0 do
                        local f = self:GetFrameRef("kcdock" .. i)
                        local fl, fb, fw, ft
                        if f then fl, fb, fw, ft = f:GetRect() end
                        if fl then
                            local fs = f:GetAttribute("kcks") or 1
                            moves[#moves + 1] = f
                            moves[#moves + 1] = ((fl + fw / 2) * fs + mdx) / fs
                            moves[#moves + 1] = ((fb + ft / 2) * fs + mdy) / fs
                        end
                    end
                    for i = 1, #moves, 3 do
                        local f = moves[i]
                        f:ClearAllPoints()
                        f:SetPoint("CENTER", h, "BOTTOMLEFT", moves[i + 1], moves[i + 2])
                    end
                    local pl, pb, pw, pt = pin:GetRect()
                    if pl then
                        local ps = kit:GetAttribute("kcpinks") or 1
                        local px, py = (pl + pw / 2) * ps + mdx, (pb + pt / 2) * ps + mdy
                        pin:ClearAllPoints()
                        pin:SetPoint("CENTER", h, "BOTTOMLEFT", px / ps, py / ps)
                        kit:SetAttribute("kcdropx", px)
                        kit:SetAttribute("kcdropy", py)
                        kit:SetAttribute("kcmovestep", "moved-pin")
                    end
                else
                    kit:ClearAllPoints()
                    kit:SetPoint("CENTER", h, "BOTTOMLEFT", cx / ks, cy / ks)
                    kit:SetAttribute("kcdropx", cx)
                    kit:SetAttribute("kcdropy", cy)
                    kit:SetAttribute("kcmovestep", "moved")
                end
            end
        end
    end
    if not drag and kit:GetAttribute("kcready") == 1 then
]] .. TOGGLE_BODY .. [[
    end
]]

function Kit:BuildKit()
    local cfg, P = self.cfg, self.prefix
    local holder = CreateFrame("Frame", P .. "Holder", UIParent, "SecureHandlerStateTemplate")
    holder:SetAllPoints(UIParent)
    holder:SetFrameStrata("MEDIUM")
    self.holder = holder

    -- Runs the flyouts' open and close, and the kit button's in combat.
    local header = CreateFrame("Frame", P .. "Secure", holder, "SecureHandlerBaseTemplate")
    header:Execute([[ FLYOUTS = newtable() FLYSLOTS = newtable() NFLY = 0 SLOTS = newtable() NSLOT = 0 ]])
    self.header = header

    -- The kit button is a secure button (with no action of its own) so its
    -- click can run a secure snippet that moves the slots (see KIT_PRE).
    local okk, kit = pcall(CreateFrame, "Button", P .. "Button", holder, "SecureActionButtonTemplate")
    if not okk or not kit then
        self.noSecureToggle = true
        kit = CreateFrame("Button", P .. "Button", holder)
    end
    kit:SetSize(self.KIT, self.KIT)
    kit:SetMovable(true)
    kit:SetClampedToScreen(true)
    kit:RegisterForDrag("LeftButton")
    kit:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    kit:SetFrameStrata("MEDIUM")
    kit:SetFrameLevel(10)
    kit:Hide()
    kit.icon = kit:CreateTexture(nil, "ARTWORK")
    kit.icon:SetAllPoints()
    if cfg.roundKit then
        -- A round icon in a ring. With cfg.kitRing (art covering the whole
        -- button, like the other kits' rim) the icon sits inside it;
        -- otherwise a slot's gold ring, 3 in from the edge, so it's the same
        -- size on screen as the other kits' art.
        local inset = cfg.kitRing and (cfg.kitIconInset or 7) or 5
        kit.icon:ClearAllPoints()
        kit.icon:SetPoint("TOPLEFT", inset, -inset)
        kit.icon:SetPoint("BOTTOMRIGHT", -inset, inset)
        local mask = kit:CreateMaskTexture()
        mask:SetTexture(self.media .. "circle_mask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(kit.icon)
        kit.icon:AddMaskTexture(mask)
        kit.shade = kit:CreateTexture(nil, "ARTWORK", nil, 2)
        kit.shade:SetAllPoints(kit.icon)
        kit.shade:SetColorTexture(0, 0, 0, 0.35)
        kit.shade:AddMaskTexture(mask)
        kit.ring = kit:CreateTexture(nil, "OVERLAY", nil, 6)
        if cfg.kitRing then
            kit.ring:SetAllPoints()
        else
            kit.ring:SetPoint("TOPLEFT", 3, -3)
            kit.ring:SetPoint("BOTTOMRIGHT", -3, 3)
        end
        kit.text = kit:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
        kit.text:SetPoint("CENTER", 0, 1)
        kit.text:SetTextColor(1, 1, 1)
        kit.text:SetShadowOffset(1, -1)
    end
    kit.hl = kit:CreateTexture(nil, "HIGHLIGHT")
    kit.hl:SetTexture(self.media .. "glow_ring")
    kit.hl:SetBlendMode("ADD")
    kit.hl:SetAllPoints()
    kit.hl:SetAlpha(0.35)
    self.kit = kit
    self:AddGlow(kit, "glow_ring", 1.35)

    -- A divider line between the slots round the kit and a row below it.
    local d = cfg.divider
    if d then
        local dv = CreateFrame("Frame", P .. "Divider", holder)
        dv:SetSize(d.width or 200, 16)
        dv:SetFrameLevel(11)
        dv.tex = dv:CreateTexture(nil, "ARTWORK")
        dv.tex:SetPoint("CENTER")
        dv.tex:SetSize(d.width or 200, 16)
        dv.tex:SetTexture(self.media .. (d.texture or "divider"), nil, nil, "LINEAR")
        dv:SetPoint("CENTER", kit, "CENTER", 0, d.y)
        dv:Hide()
        local ag = dv:CreateAnimationGroup()
        local a = ag:CreateAnimation("Alpha")
        a:SetFromAlpha(0)
        a:SetToAlpha(1)
        a:SetDuration(0.2)
        dv.fadeIn = ag
        self.divider = dv
    end

    kit:SetScript("OnDragStart", function(b)
        if self.db.locked then return end
        if InCombatLockdown() then
            return
        end
        self:CloseFlyouts()
        GameTooltip:Hide()
        if self.Dock then self.Dock.DragStart(self.key) else
            b.moving = true
            b:StartMoving()
        end
    end)
    kit:SetScript("OnDragStop", function(b)
        if InCombatLockdown() then return end
        if self.Dock and self.Dock.dragging then
            self.Dock.DragStop(self.key)
            return
        end
        -- The game reports the end of a drag even when it never started one
        -- here (locked, or in combat): nothing moved, so nothing to save.
        if not b.moving then return end
        b.moving = nil
        b:StopMovingOrSizing()
        self:SavePosition()
        self:KeepOnScreen()
    end)
    kit:SetScript("OnClick", function(_, button)
        if button == "RightButton" and IsShiftKeyDown() then
            self:OpenSettings()
            return
        end
        if button == "RightButton" then
            self:OpenMenu()
            return
        end
        -- In combat the secure snippet (KIT_PRE) has already switched the
        -- slots, if it could; this only catches the kit up.
        if InCombatLockdown() then
            self:CombatToggled()
            return
        end
        self:SetOpen(not self.open)
    end)
    self:HoverTip(kit, function(b)
        DefaultAnchor(b)
        GameTooltip:AddLine(self.name)
        if cfg.KitTooltip then cfg.KitTooltip(self) end
        GameTooltip:AddLine("Left-click: open / close", 1, 1, 1)
        if not self.db.locked then GameTooltip:AddLine("Drag: move", 1, 1, 1) end
        GameTooltip:AddLine("Right-click: menu   Shift-right-click: settings", 1, 1, 1)
        GameTooltip:Show()
    end)
    if not self.noSecureToggle then
        local okw = pcall(SecureHandlerWrapScript, kit, "OnClick", header, KIT_PRE)
        if not okw then
            self.noSecureToggle = true
        else
            Try(RegisterStateDriver, kit, "kcincombat", "[combat] yes; no")
            header:SetFrameRef("kcholder", holder)
            -- The grip (see GRIP_CLICK): over the kit button in combat, below
            -- the buttons a kit puts on it (those sit 6 or more levels up).
            local okg, grip = pcall(CreateFrame, "Button", P .. "Grip", kit, "SecureActionButtonTemplate")
            if okg and grip then
                grip:SetAllPoints(kit)
                grip:SetFrameLevel(kit:GetFrameLevel() + 1)
                grip:RegisterForClicks("LeftButtonDown", "LeftButtonUp", "RightButtonUp")
                grip:Hide()
                SecureHandlerSetFrameRef(grip, "kckit", kit)
                -- (these run after the snippet, and only follow along)
                grip:SetScript("OnMouseDown", function(_, mouse)
                    if mouse == "LeftButton" then self:NoteCombatPress() end
                end)
                grip:SetScript("OnMouseUp", function() self:StopGhost() end)
                grip:SetScript("OnClick", function(_, mouse, down) self:GripClicked(mouse, down) end)
                grip:SetScript("OnEnter", function() local f = kit:GetScript("OnEnter") if f then f(kit) end end)
                grip:SetScript("OnLeave", function() local f = kit:GetScript("OnLeave") if f then f(kit) end end)
                grip.kcKit, grip.kcTip = self, function() kit.kcTip(kit) end
                self.grip = grip
            end
            if not (okg and grip) or not pcall(SecureHandlerWrapScript, grip, "OnClick", header, GRIP_CLICK) then
                self.grip = nil
                self.noSecureMove = true
            end
        end
    end
end

---------------------------------------------------------------------------
-- The kit button's right-click menu, at the cursor: Pin in place, the
-- kit's own lines (cfg.Menu), Settings. Uses the game's menu system; on a
-- client without it, right-click locks and unlocks as it used to.
---------------------------------------------------------------------------

function Kit:SetLocked(on)
    if InCombatLockdown() then self:Print("That can only change out of combat.") return end
    self.db.locked = on and true or false
    self.kit:SetAttribute("kcmovable", self:CanSecureMove() and 1 or 0)
    self:Print(self.db.locked and "Pinned in place." or "Unpinned. Drag the kit to move it.")
    self:SettingsChanged()
end

-- An on/off line for a saved setting. after(kit) runs once it's changed.
function Kit:MenuToggle(root, label, key, after)
    root:CreateCheckbox(label,
        function() return self.db[key] and true or false end,
        function()
            self.db[key] = not self.db[key]
            if after then after(self) end
            self:SettingsChanged()
        end)
end

-- Where the kit lives: on the pin with the other kits, parked in the top
-- dock, or free where it stands. Only with Kit Dock v19 or newer, and not
-- for edges-only kits.
function Kit:PlacementMenu(root)
    local D = self.Dock
    if not (D and D.Pin and D.Park and D.Undock) or self.cfg.edgesOnly then return end
    local function where()
        if D.IsParked and D.IsParked(self.key) then return "top" end
        if D.IsDocked(self.key) then return "pin" end
        return "free"
    end
    local function Go(to)
        if InCombatLockdown() then self:Print("That can only change out of combat.") return end
        if to == "top" then D.Park(self.key)
        elseif to == "pin" then D.Pin(self.key)
        else D.Undock(self.key) end
    end
    local sub = root:CreateButton("Place")
    sub:CreateRadio("On the pin", function() return where() == "pin" end, function() Go("pin") end)
    sub:CreateRadio("Tuck box", function() return where() == "top" end, function() Go("top") end)
    sub:CreateRadio("Free", function() return where() == "free" end, function() Go("free") end)
end

function Kit:OpenMenu()
    GameTooltip:Hide()
    if not (MenuUtil and MenuUtil.CreateContextMenu) then
        self:SetLocked(not self.db.locked)
        return
    end
    MenuUtil.CreateContextMenu(self.kit, function(_, root)
        root:CreateTitle(self.name)
        self:PlacementMenu(root)
        root:CreateCheckbox("Pin in place",
            function() return self.db.locked and true or false end,
            function() self:SetLocked(not self.db.locked) end)
        if self.cfg.Menu then self.cfg.Menu(self, root) end
        root:CreateDivider()
        root:CreateButton("Settings", function() self:OpenSettings() end)
    end)
end

function Kit:SetKitArt()
    local kit = self.kit
    if kit.ring then
        local ring = self.cfg.kitRing
        local px = ArtSize(ScreenPx(kit, kit:GetWidth() - (ring and 0 or 6)), ART_SIZES)
        kit.ring:SetTexture(self.media .. (ring or "ring_slot") .. "_" .. px, nil, nil, "LINEAR")
    end
    if self.cfg.KitArt then self.cfg.KitArt(self) end
end

function Kit:ApplyCombatHide()
    if InCombatLockdown() then self.pending = true return end
    if self.db.hideInCombat then
        Try(RegisterStateDriver, self.holder, "visibility", "[combat] hide; show")
    else
        Try(UnregisterStateDriver, self.holder, "visibility")
        self.holder:Show()
    end
end

---------------------------------------------------------------------------
-- Slots
---------------------------------------------------------------------------

-- Opening or closing a flyout from a slot, in combat too. "right":
-- right-click (shift-right-click pins); "left": any click but shift-right.
-- Acts on the release only and swallows the press, so the slot's own action
-- doesn't run on a click that's meant for the flyout.
-- Out of combat a flyout closes when you click anywhere else (insecure, see
-- GLOBAL_MOUSE_DOWN). In combat that isn't allowed, so it closes itself a
-- moment after the mouse leaves it and its slot instead.
-- In combat a flyout closes itself this long after the mouse leaves it: the
-- kit's "flyoutHide" setting, handed to the secure code as the header's
-- "kchide" attribute when combat starts.
local TOGGLE_PRE = [[
    local fly = self:GetFrameRef("kcfly")
    if not fly then return end
    if button == "RightButton" and IsShiftKeyDown() then return end
    if button == "RightButton" or self:GetAttribute("kcflymode") == "left" then
        if not down then
            local show = not fly:IsShown()
            for i = 1, NFLY do FLYOUTS[i]:Hide() end
            if show then
                fly:Show()
                if owner:GetAttribute("kccombat") then
                    fly:RegisterAutoHide(owner:GetAttribute("kchide") or 0.5)
                    fly:AddToAutoHide(self)
                end
            end
        end
        return false
    end
]]

-- A choice clicked (on the release): one that's assigned to its slot copies
-- its action onto the slot, so a plain click on the slot repeats it. Runs
-- before the choice's own action (which uses the choice's attributes, so
-- the order doesn't matter). The game only runs an after-click snippet when
-- the before-click one returns a message, so closing (for choices that ask
-- for it) goes through that message.
-- The flyout stays open otherwise.
local ASSIGN_KEYS = { "type", "spell", "item", "macrotext", "shift-type1", "shift-macrotext1" }
local CHOICE_PRE = [[
    if down then return end
    if self:GetAttribute("kcassign") then
        local slot = self:GetFrameRef("kcslot")
        slot:SetAttribute("type", self:GetAttribute("type"))
        slot:SetAttribute("spell", self:GetAttribute("spell"))
        slot:SetAttribute("item", self:GetAttribute("item"))
        slot:SetAttribute("macrotext", self:GetAttribute("macrotext"))
        slot:SetAttribute("shift-type1", self:GetAttribute("shift-type1"))
        slot:SetAttribute("shift-macrotext1", self:GetAttribute("shift-macrotext1"))
        slot:SetAttribute("kcvalue", self:GetAttribute("kcvalue"))
    end
    if self:GetAttribute("kcclose") then return nil, "close" end
]]
local CHOICE_POST = [[
    if message == "close" then
        for i = 1, NFLY do FLYOUTS[i]:Hide() end
    end
]]

function Kit:CreateSlot(slot)
    local btn = self:MakeItemButton(self.prefix .. "Slot_" .. slot.key, self.holder, true)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(12)
    btn.slot = slot
    if not slot.noPin then
        btn:SetAttribute("shift-type2", "kcpin")
        btn:SetAttribute("_kcpin", function(b)
            if self:Debounced() then self:TogglePin(b.slot.key) end
        end)
    end

    btn.cooldown = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    btn.cooldown:SetAllPoints()
    Try(btn.cooldown.SetDrawEdge, btn.cooldown, false)

    btn.pin = btn:CreateTexture(nil, "OVERLAY", nil, 7)
    btn.pin:SetTexture(self.media .. "pin_dot", nil, nil, "LINEAR")
    btn.pin:SetSize(10, 10)
    btn.pin:SetPoint("CENTER", btn, "CENTER", -13, 13)

    btn.hotkey = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmallGray")
    btn.hotkey:SetJustifyH("RIGHT")

    btn.note = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    btn.note:SetPoint("TOP", btn, "BOTTOM", 0, -1)

    if slot.small then
        self:MakeSmallRound(btn)
        btn.pin:SetSize(8, 8)
        btn.pin:ClearAllPoints()
        btn.pin:SetPoint("CENTER", btn, "CENTER", -7, 7)
        self:AddGlow(btn, "glow_ring", 1.7)
    else
        self:AddGlow(btn, "glow_square", 1.9)
        self:ApplyShape(btn, self.db.roundSlots)
    end

    btn:HookScript("OnHide", function(b)
        -- (hidden some other way part-way through a slide: done with it)
        if sliding[b] then
            sliding[b] = nil
            b.slideTarget, b.slideWait, b.slideA, b.closing = nil, nil, nil, nil
            b.slideP = nil
            if not InCombatLockdown() then b:SetScale(self.db.scale) end
            if not self:Sliding() and C_Timer and C_Timer.After then
                C_Timer.After(0, function() self:SettleTip() end)
            end
        end
    end)
    local dx, dy = slot.pos[1], slot.pos[2]
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", self.kit, "CENTER", dx, dy)
    btn.homeX, btn.homeY, btn.placedX, btn.placedY = dx, dy, dx, dy

    if slot.sub then self:AddSub(btn, slot.sub) end
    if slot.Choices then self:AddFlyout(btn) end

    self:HoverTip(btn, function(b) self:SlotTooltip(b) end)
    btn:HookScript("OnAttributeChanged", function(b, name, value)
        -- A choice from the flyout became this slot's (maybe in combat).
        if name == "kcvalue" and slot.assign and not b.updating and value ~= nil then
            self.cdb.picks[slot.key] = value
            for _, fb in ipairs(b.fly and b.fly.buttons or {}) do
                if fb.choice and fb.choice.value == value then b.assigned = fb.choice end
            end
            self:PaintSlot(b)
            if b.fly and b.fly:IsShown() then self:PaintFlyout(b.fly) end
        end
        if slot.OnAttribute then slot.OnAttribute(self, b, name, value) end
    end)
    if slot.OnDrop then
        btn:SetScript("OnReceiveDrag", function(b) slot.OnDrop(self, b) end)
    end
    if slot.Setup then slot.Setup(self, btn) end
    btn:Hide()
    -- The kit button's secure snippet moves and shows the slots (KIT_PRE).
    self.header:SetFrameRef("kcnewbtn", btn)
    self.header:Execute([[ NSLOT = NSLOT + 1 SLOTS[NSLOT] = self:GetFrameRef("kcnewbtn") ]])
    self.slots[slot.key] = btn
    btn.order = self.order[slot.key]
    return btn
end

function Kit:SlotTooltip(btn)
    local slot = btn.slot
    self:TipOwner(btn)
    if slot.Tooltip then slot.Tooltip(self, btn) else GameTooltip:AddLine(slot.label) end
    local hints = {}
    if slot.flyout == "left" then hints[#hints + 1] = "Click: open" end
    if slot.flyout == "right" then hints[#hints + 1] = slot.flyoutHint or "Right-click: choose" end
    if #hints > 0 or not slot.noPin then GameTooltip:AddLine(" ") end
    for _, h in ipairs(hints) do GameTooltip:AddLine(h, 0.3, 1, 0.4) end
    if not slot.noPin then
        GameTooltip:AddLine(self.cdb.pinned[slot.key] and "Shift-right-click: stop always showing"
            or "Shift-right-click: always show", 1, 0.82, 0)
    end
    GameTooltip:Show()
end

-- Slots slide out of the kit as it opens and back in as it closes (from
-- v7) by really moving, a little each frame, not with the game's
-- animations. Those only move the picture: a slot's cooldown numbers didn't
-- go with it, and stopping one part-way (opening and closing quickly)
-- snapped the slot to its real spot for a moment before the next began. A
-- slide that turns round part-way now carries on from where the slot is.
--   btn.slideP       0 in the kit, 1 at its spot
--   btn.slideTarget  where it's heading (0 or 1); btn.closing while it's 0
--   btn.slideWait    seconds left before it starts (the stagger)
--   btn.slideA       its fade (ApplyFade multiplies it in)
-- Out of combat only: they're finished as combat starts (see OnEvent).
local OPEN_TIME, CLOSE_TIME = 0.22, 0.18
local slider = CreateFrame("Frame")
slider:Hide()
C.slider = slider -- (for testing)

local function Ease(p) return 1 - (1 - p) * (1 - p) end -- (fast out, slow in)

-- Put a sliding slot where its progress says: part-way between the kit and
-- its spot, shrunk toward the kit, faded in its first part.
function Kit:SlideApply(btn)
    local p = btn.slideP or 1
    local e = Ease(p)
    local sc = 0.3 + 0.7 * e
    local x, y = btn.placedX or btn.homeX or 0, btn.placedY or btn.homeY or 0
    btn:SetScale(self.db.scale * sc)
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", self.kit, "CENTER", x * e / sc, y * e / sc) -- (offsets are in its own, shrunk, units)
    btn.slideA = math.min(1, p * OPEN_TIME / 0.16)
    self:FadeSlot(btn)
end

-- The slide is over: the slot at its spot at full size, or hidden in the kit.
function Kit:FinishSlide(btn)
    sliding[btn] = nil
    if not self:Sliding() then
        -- (next frame, once the pointer has caught up with where things are)
        if C_Timer and C_Timer.After then C_Timer.After(0, function() self:SettleTip() end) else self:SettleTip() end
    end
    local target = btn.slideTarget or 1
    btn.slideP, btn.slideTarget, btn.slideWait, btn.slideA = target, nil, nil, nil
    if InCombatLockdown() then return end
    btn:SetScale(self.db.scale)
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", self.kit, "CENTER", btn.placedX or btn.homeX or 0, btn.placedY or btn.homeY or 0)
    if target == 0 then
        btn.closing = nil
        btn:Hide()
    end
    self:ApplyFade()
end

-- Finish every slide now (combat is starting).
function Kit:FinishSlides()
    for btn, kit in pairs(sliding) do
        if kit == self then self:FinishSlide(btn) end
    end
end

function Kit:SlideTo(btn, target, delay)
    if InCombatLockdown() then return end
    if self.Dock and self.Dock.StopTween then self.Dock.StopTween(btn) end -- (a dock glide left over)
    if btn.slideP == nil then btn.slideP = 1 - target end
    btn.slideTarget = target
    btn.slideWait = delay or 0
    btn.closing = target == 0 or nil
    sliding[btn] = self
    self:SlideApply(btn)
    slider:Show()
end

function Kit:IsSliding(btn) return sliding[btn] ~= nil end

slider:SetScript("OnUpdate", function(f, dt)
    if InCombatLockdown() then return end -- (finished as combat started; see FinishSlides)
    for btn, kit in pairs(sliding) do
        if (btn.slideWait or 0) > 0 then
            btn.slideWait = btn.slideWait - dt
        else
            local up = btn.slideTarget == 1
            local p = (btn.slideP or 0) + (up and dt / OPEN_TIME or -dt / CLOSE_TIME)
            if (up and p >= 1) or (not up and p <= 0) then
                kit:FinishSlide(btn)
            else
                btn.slideP = p
                kit:SlideApply(btn)
            end
        end
    end
    if not next(sliding) then f:Hide() end
end)

-- Slides go between the kit and wherever the slot actually sits (its home
-- spot, its place on the dock, or its column on a screen edge).
local function PlayClose(kit, btn, index, total)
    if InCombatLockdown() then return end
    -- (staggered when the whole kit closes; straight back from part-way)
    local atRest = not sliding[btn]
    kit:SlideTo(btn, 0, atRest and (total - index) * 0.02 or 0)
end

local function CancelClose(kit, btn)
    if btn.closing then kit:SlideTo(btn, 1, 0) end -- (back out from where it is)
end

-- A slot just shown as the kit opens: out from the kit.
function Kit:PlaySlide(btn, index)
    if InCombatLockdown() then return end
    btn.slideP = 0
    self:SlideTo(btn, 1, (self.slideDelay or 0) + index * 0.025)
end

-- A small round secure button on the slot's corner (away from the kit's
-- edge side when on a screen edge). A child of the slot, so it slides,
-- fades and hides with it.
local SUB_CORNER = { 16, -16 }
local SUB_EDGE = { left = { 16, -16 }, right = { -16, -16 }, top = { 16, -16 }, bottom = { 16, 16 } }

function Kit:AddSub(btn, sub)
    local sb = CreateFrame("Button", self.prefix .. "Sub_" .. sub.key, btn, "SecureActionButtonTemplate")
    sb:RegisterForClicks("AnyUp", "AnyDown")
    sb:SetAttribute("useOnKeyDown", false)
    sb:SetFrameLevel(btn:GetFrameLevel() + 4)
    sb.icon = sb:CreateTexture(nil, "ARTWORK")
    self:MakeSmallRound(sb)
    sb.cooldown = CreateFrame("Cooldown", nil, sb, "CooldownFrameTemplate")
    sb.cooldown:SetPoint("TOPLEFT", 2, -2)
    sb.cooldown:SetPoint("BOTTOMRIGHT", -2, 2)
    Try(sb.cooldown.SetSwipeTexture, sb.cooldown, self.media .. "circle_mask")
    Try(sb.cooldown.SetUseCircularEdge, sb.cooldown, true)
    Try(sb.cooldown.SetDrawEdge, sb.cooldown, false)
    sb:SetPoint("CENTER", btn, "CENTER", SUB_CORNER[1], SUB_CORNER[2])
    self:AddGlow(sb, "glow_ring", 1.7)
    sb.def, sb.parentBtn = sub, btn
    self:HoverTip(sb, function(b)
        self:TipOwner(b)
        if sub.Tooltip then sub.Tooltip(self, b) else GameTooltip:AddLine(sub.label) end
        GameTooltip:Show()
    end)
    sb:Hide()
    btn.sub = sb
    _G["BINDING_NAME_CLICK " .. sb:GetName() .. ":LeftButton"] = sub.binding or sub.label
end

local SUB_BELOW = 3 + 11 -- gap under the slot, plus half the sub

function Kit:PlaceSub(btn)
    local sb = btn.sub
    if not sb then return end
    local x, y
    if self.edgeSide then
        local c = SUB_EDGE[self.edgeSide]
        x, y = c[1], c[2]
    elseif sb.def.below then
        x, y = self:Face(0, -(btn:GetHeight() / 2 + SUB_BELOW))
    else
        x, y = SUB_CORNER[1], SUB_CORNER[2]
    end
    sb:ClearAllPoints()
    sb:SetPoint("CENTER", btn, "CENTER", x, y)
end

---------------------------------------------------------------------------
-- Flyouts: a slot's choices, out to one side of it. Secure, so they open
-- and close (and their choices work) in combat as well.
--
-- A choice: {
--   icon, label, tooltip = function(tip) end (or uses item / spell below),
--   item = itemID or spell = spellID   (for the tooltip)
--   attrs = { type = "spell", spell = ..., ["shift-type1"] = ..., ... }
--     the secure action, or:
--   pick = value       out of combat only: the slot's OnPick runs with it
--   set = value        sets the slot's "kcset" attribute (in combat too);
--                      the slot's OnAttribute sees it
--   setAttr = { name, value }   sets any attribute on the slot, in combat too
--   value, assign      (slots with assign = true) with attrs: clicking it does
--                      its action and makes it the slot's own, so a plain
--                      click on the slot repeats it; saved in picks[slot]
--   close              close the flyout after this choice
--   selected, dim, count   (values or functions; repainted any time).
--                      An assigned choice shows selected while it's the slot's.
-- }
-- A flyout stays open until it's toggled from its slot or you click
-- elsewhere (in combat: until the mouse has been off it for a moment).
---------------------------------------------------------------------------

function Kit:AddFlyout(btn)
    local slot = btn.slot
    local fly = CreateFrame("Frame", self.prefix .. "Fly_" .. slot.key, self.holder, "SecureHandlerBaseTemplate")
    fly:SetAllPoints(self.kit)
    fly:SetFrameStrata("HIGH")
    fly:Hide()
    fly.slotBtn, fly.buttons = btn, {}
    btn.fly = fly
    self.flyouts[slot.key] = fly

    -- A dark panel behind the choices, so they read clearly over the kit.
    local okp, pnl = pcall(CreateFrame, "Frame", nil, fly, "BackdropTemplate")
    if not okp or not pnl then pnl = CreateFrame("Frame", nil, fly) end
    pnl:SetFrameLevel(math.max(0, fly:GetFrameLevel()))
    if pnl.SetBackdrop then
        pnl:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 } })
        pnl:SetBackdropColor(0.04, 0.03, 0.05, 0.88)
        pnl:SetBackdropBorderColor(0.78, 0.64, 0.3, 0.9)
    else
        local t = pnl:CreateTexture(nil, "BACKGROUND")
        t:SetAllPoints()
        t:SetColorTexture(0.04, 0.03, 0.05, 0.88)
    end
    -- The flyout frame itself covers its choices (LayoutFlyout sizes it),
    -- so "the mouse is over it" means over the choices.
    pnl:SetAllPoints(fly)
    fly.panel = pnl

    self.header:SetFrameRef("kcnew", fly)
    self.header:SetFrameRef("kcnewslot", btn)
    self.header:Execute([[
        NFLY = NFLY + 1
        FLYOUTS[NFLY] = self:GetFrameRef("kcnew")
        FLYSLOTS[NFLY] = self:GetFrameRef("kcnewslot")
    ]])
    SecureHandlerSetFrameRef(btn, "kcfly", fly) -- (a plain secure button has no SetFrameRef of its own)
    btn:SetAttribute("kcflymode", slot.flyout or "right")
    SecureHandlerWrapScript(btn, "OnClick", self.header, TOGGLE_PRE)

    fly:SetScript("OnShow", function(f)
        self.flyOpen = f
        self:PaintFlyout(f)
        self:ApplyFade()
        if not InCombatLockdown() then
            if f.count == 0 then
                self:Print(f.nothing or "Nothing to choose from.")
                f:Hide()
                return
            end
            for i, b in ipairs(f.buttons) do
                if i <= f.count then
                    b.flyAnim:Stop()
                    b.flyHold:SetDuration(0.001 + (i - 1) * 0.02)
                    b.flyAnim:Play()
                end
            end
        end
    end)
    fly:SetScript("OnHide", function(f)
        if self.flyOpen == f then self.flyOpen = nil end
        self:ApplyFade()
    end)
end

function Kit:FlyButton(fly, i)
    local b = fly.buttons[i]
    if b then return b end
    b = self:MakeItemButton(fly:GetName() .. i, fly, true)
    b:SetFrameLevel(fly.panel:GetFrameLevel() + 2)
    SecureHandlerWrapScript(b, "OnClick", self.header, CHOICE_PRE, CHOICE_POST)
    SecureHandlerSetFrameRef(b, "kcslot", fly.slotBtn)
    b:SetAttribute("_kcpick", function(btn)
        if self:Debounced() and btn.choice then self:Pick(fly.slotBtn, btn.choice.pick) end
    end)
    b.cooldown = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    b.cooldown:SetAllPoints()
    Try(b.cooldown.SetDrawEdge, b.cooldown, false)
    b.sel = b:CreateTexture(nil, "OVERLAY")
    b.sel:SetTexture(self.media .. "glow_square")
    b.sel:SetBlendMode("ADD")
    b.sel:SetVertexColor(0.75, 0.55, 1)
    b.sel:SetPoint("CENTER")
    b.sel:SetSize(self.BTN * 1.5, self.BTN * 1.5)
    -- Flies out of the slot as the flyout opens (out of combat).
    local ag = b:CreateAnimationGroup()
    local back = ag:CreateAnimation("Translation")
    back:SetDuration(0.001)
    back:SetOrder(1)
    local hold = ag:CreateAnimation("Alpha")
    hold:SetFromAlpha(0)
    hold:SetToAlpha(0)
    hold:SetDuration(0.001)
    hold:SetOrder(1)
    local out = ag:CreateAnimation("Translation")
    out:SetDuration(0.18)
    out:SetSmoothing("OUT")
    out:SetOrder(2)
    local fade = ag:CreateAnimation("Alpha")
    fade:SetFromAlpha(0)
    fade:SetToAlpha(1)
    fade:SetDuration(0.14)
    fade:SetOrder(2)
    local grow = ag:CreateAnimation("Scale")
    grow:SetScaleFrom(0.4, 0.4)
    grow:SetScaleTo(1, 1)
    grow:SetDuration(0.18)
    grow:SetSmoothing("OUT")
    grow:SetOrder(2)
    b.flyAnim, b.flyBack, b.flyHold, b.flyOut = ag, back, hold, out
    -- (a cooldown's numbers don't go along with an animation: hidden for the
    -- moment the choice flies out)
    ag:SetScript("OnPlay", function() b.cooldown:SetAlpha(0) end)
    ag:SetScript("OnFinished", function() b.cooldown:SetAlpha(1) end)
    ag:SetScript("OnStop", function() b.cooldown:SetAlpha(1) end)
    b:SetScript("OnEnter", function(btn)
        self:TipOwner(btn)
        local c = btn.choice
        if c then
            if c.tooltip then c.tooltip(GameTooltip)
            elseif c.item then GameTooltip:SetItemByID(c.item)
            elseif c.spell then Try(GameTooltip.SetSpellByID, GameTooltip, c.spell)
            else GameTooltip:AddLine(c.label or "") end
            if c.hint then GameTooltip:AddLine(c.hint, 0.3, 1, 0.4, true) end
            if fly.slotBtn.slot.reorder and c.value ~= nil and not InCombatLockdown() then
                GameTooltip:AddLine("Drag: move it in this list", 1, 0.82, 0)
            end
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    self:ApplyShape(b, self.db.roundSlots)
    -- Drag a choice along its flyout to change the order (out of combat).
    if fly.slotBtn.slot.reorder then
        b:SetMovable(true)
        b:RegisterForDrag("LeftButton")
        b:SetScript("OnDragStart", function(btn)
            if InCombatLockdown() or not (btn.choice and btn.choice.value ~= nil) then return end
            GameTooltip:Hide()
            btn:SetFrameLevel(fly.panel:GetFrameLevel() + 6)
            btn.dragging = true
            self:DragBegin(fly, btn)
            btn:StartMoving()
            btn:SetScript("OnUpdate", function(f, dt) self:DragTick(fly, f, dt) end)
        end)
        b:SetScript("OnDragStop", function(btn)
            if not btn.dragging then return end
            btn.dragging = nil
            btn:SetScript("OnUpdate", nil)
            btn:StopMovingOrSizing()
            Try(btn.SetUserPlaced, btn, false) -- (the game mustn't remember where it was dropped)
            btn:SetFrameLevel(fly.panel:GetFrameLevel() + 2)
            self:DropChoice(fly, btn)
        end)
    end
    fly.buttons[i] = b
    return b
end

-- Dragging a choice along its flyout: the others slide aside, live, to show
-- where everything will end up; letting go there saves the new order.
-- Dropped away from the flyout, nothing changes.

-- Where a frame's centre is, in the choices' units from the kit's centre.
function Kit:FromKit(f)
    local x, y = f:GetCenter()
    local kx, ky = self.kit:GetCenter()
    if not (x and kx) then return nil end
    local k = self.kit:GetEffectiveScale() / f:GetEffectiveScale()
    return x - kx * k, y - ky * k
end

function Kit:DragBegin(fly, dragged)
    fly.dragFrom, fly.dragTo = nil, nil
    for i = 1, fly.count or 0 do
        local b = fly.buttons[i]
        if b == dragged then fly.dragFrom = i end
        local p = fly.pts and fly.pts[i]
        if p then b.curX, b.curY = p[1], p[2] end
    end
    fly.dragTo = fly.dragFrom
end

-- Which spot the dragged choice is over: the nearest one, if it's close
-- enough; else its own.
function Kit:DragTarget(fly, dragged)
    local x, y = self:FromKit(dragged)
    if not x or not fly.pts then return fly.dragFrom end
    local to, best
    for i = 1, fly.count or 0 do
        local p = fly.pts[i]
        local d = (p[1] - x) ^ 2 + (p[2] - y) ^ 2
        if not best or d < best then best, to = d, i end
    end
    local reach = self.BTN * 1.2
    if best and best <= reach * reach then return to end
    return fly.dragFrom
end

function Kit:DragTick(fly, dragged, dt)
    if InCombatLockdown() or not fly.dragFrom then return end
    local from, to = fly.dragFrom, self:DragTarget(fly, dragged)
    fly.dragTo = to
    local k = math.min(1, (dt or 0) * 14)
    for i = 1, fly.count or 0 do
        local b = fly.buttons[i]
        if b ~= dragged then
            -- Its place once the dragged one moves from "from" to "to".
            local j = i
            if from < to and i > from and i <= to then j = i - 1
            elseif from > to and i >= to and i < from then j = i + 1 end
            local p = fly.pts[j]
            b.curX = (b.curX or p[1]) + (p[1] - (b.curX or p[1])) * k
            b.curY = (b.curY or p[2]) + (p[2] - (b.curY or p[2])) * k
            b:ClearAllPoints()
            b:SetPoint("CENTER", fly.slotBtn, "CENTER", b.curX - (fly.sx or 0), b.curY - (fly.sy or 0))
        end
    end
end

function Kit:DropChoice(fly, dragged)
    if InCombatLockdown() then return end
    local slot = fly.slotBtn.slot
    local from, to = fly.dragFrom, self:DragTarget(fly, dragged)
    fly.dragFrom, fly.dragTo = nil, nil
    if from and to and from ~= to then
        local vals = {}
        for i = 1, fly.count or 0 do
            local b = fly.buttons[i]
            vals[i] = b.choice and b.choice.value
        end
        local v = table.remove(vals, from)
        table.insert(vals, to, v)
        self.cdb.order[slot.key] = vals
    end
    self:LayoutFlyout(fly.slotBtn) -- every choice back in line, in its (new) place
    if fly:IsShown() then self:PaintFlyout(fly) end
end

-- A slot's choices in your saved order (any not in it yet keep their place
-- after the ones that are).
function Kit:OrderChoices(slot, choices)
    local saved = slot.reorder and self.cdb.order[slot.key]
    if not saved then return choices end
    local rank, at = {}, {}
    for i, v in ipairs(saved) do rank[v] = i end
    for i, c in ipairs(choices) do at[c] = i end
    table.sort(choices, function(a, b)
        local ra = a.value ~= nil and rank[a.value] or (1000 + at[a])
        local rb = b.value ~= nil and rank[b.value] or (1000 + at[b])
        return ra < rb
    end)
    return choices
end

-- Keep a flyout on screen: flip it to the other side of its slot when it
-- would run off an edge (if that's better), then nudge what's still over.
-- pts are offsets from the kit centre, in the flyout's units.
function Kit:FitPoints(pts, sx, sy)
    local ps = (self.db.scale or 1) * UIParent:GetEffectiveScale()
    local kx, ky = self.kit:GetCenter()
    if not kx or #pts == 0 then return end
    local k = self.kit:GetEffectiveScale() / ps
    kx, ky = kx * k, ky * k
    local W = UIParent:GetWidth() * UIParent:GetEffectiveScale() / ps
    local H = UIParent:GetHeight() * UIParent:GetEffectiveScale() / ps
    local m = self.BTN / 2 + 10
    local function Bounds()
        local x0, x1, y0, y1 = math.huge, -math.huge, math.huge, -math.huge
        for _, p in ipairs(pts) do
            x0, x1 = math.min(x0, kx + p[1]), math.max(x1, kx + p[1])
            y0, y1 = math.min(y0, ky + p[2]), math.max(y1, ky + p[2])
        end
        return x0 - m, x1 + m, y0 - m, y1 + m
    end
    local function Over(a, b, size) return math.max(0, -a) + math.max(0, b - size) end
    local x0, x1 = Bounds()
    if Over(x0, x1, W) > 0 then
        for _, p in ipairs(pts) do p[1] = 2 * sx - p[1] end
        local a0, a1 = Bounds()
        if Over(a0, a1, W) >= Over(x0, x1, W) then
            for _, p in ipairs(pts) do p[1] = 2 * sx - p[1] end -- no better: flip back
        end
    end
    local _, _, y0, y1 = Bounds()
    if Over(y0, y1, H) > 0 then
        for _, p in ipairs(pts) do p[2] = 2 * sy - p[2] end
        local _, _, a0, a1 = Bounds()
        if Over(a0, a1, H) >= Over(y0, y1, H) then
            for _, p in ipairs(pts) do p[2] = 2 * sy - p[2] end
        end
    end
    local bx0, bx1, by0, by1 = Bounds()
    local dx = (bx0 < 0 and -bx0) or (bx1 > W and W - bx1) or 0
    local dy = (by0 < 0 and -by0) or (by1 > H and H - by1) or 0
    if dx ~= 0 or dy ~= 0 then
        for _, p in ipairs(pts) do p[1], p[2] = p[1] + dx, p[2] + dy end
    end
end

-- Which way a slot's flyout grows: its own direction; on a screen edge,
-- toward the middle of the screen; in the fan on the dock, away from the kit.
local TOWARD_MIDDLE = { left = "right", right = "left", top = "down", bottom = "up" }
local function FanDir(sx, sy)
    local a = math.deg(math.atan2(sy, sx))
    if a > -45 and a <= 45 then return "right"
    elseif a > 45 and a <= 135 then return "up"
    elseif a > -135 and a <= -45 then return "down"
    else return "left" end
end

-- Out of combat: fill a slot's flyout with its choices and place them.
function Kit:LayoutFlyout(btn)
    local fly = btn.fly
    if not fly then return end
    local slot = btn.slot
    local choices = self:OrderChoices(slot, slot.Choices(self, btn) or {})
    while #choices > 24 do table.remove(choices) end
    fly.nothing = slot.nothing
    local sx, sy = btn.placedX or slot.pos[1], btn.placedY or slot.pos[2]
    local grid = slot.grid and self:FaceDir(slot.grid) or FanDir(sx, sy)
    if self.compactAngle then grid = FanDir(sx, sy) end
    if self.edgeSide then grid = TOWARD_MIDDLE[self.edgeSide] end
    local BTN = self.BTN
    local step = BTN + 4
    local per = slot.perRow or 8
    local pts = {}
    for i = 1, #choices do
        local x, y
        local line, at = math.floor((i - 1) / per), (i - 1) % per
        local n = math.min(#choices - line * per, per)
        -- A sub under the slot (not on an edge, where it's on the corner)
        -- needs the flyout to clear it when it opens that way.
        local gap = BTN + 10
        if slot.flyGap and not self.edgeSide and grid == self:FaceDir("down") then gap = gap + slot.flyGap end
        if grid == "left" or grid == "right" then
            local dir = grid == "left" and -1 or 1
            x = sx + dir * (gap + at * step)
            y = sy - line * step
        else
            local dir = grid == "down" and -1 or 1
            x = sx + (at - (n - 1) / 2) * step
            y = sy + dir * (gap + line * step)
        end
        pts[i] = { x, y }
    end
    self:FitPoints(pts, sx, sy)

    for i, c in ipairs(choices) do
        local b = self:FlyButton(fly, i)
        b.choice = c
        -- Clear what the last choice in this spot set, then set this one's.
        for _, k in ipairs(b.attrKeys or {}) do b:SetAttribute(k, nil) end
        local keys = {}
        local function Set(k, v) b:SetAttribute(k, v) keys[#keys + 1] = k end
        if c.attrs then
            for k, v in pairs(c.attrs) do Set(k, v) end
        elseif c.pick ~= nil then
            Set("type", "kcpick")
        elseif c.set ~= nil or c.setAttr then
            Set("type", "attribute")
            Set("attribute-frame", btn)
            Set("attribute-name", c.setAttr and c.setAttr[1] or "kcset")
            Set("attribute-value", c.setAttr and c.setAttr[2] or c.set)
        end
        if c.assign and c.attrs then
            Set("kcassign", true)
            Set("kcvalue", c.value)
        end
        if c.close then Set("kcclose", true) end
        b.attrKeys = keys
        -- Anchored to the slot, not the kit, so the choices stay beside it
        -- when the kit button switches layouts in combat and the slot moves.
        local x, y = pts[i][1], pts[i][2]
        local dx, dy = x - sx, y - sy
        b:ClearAllPoints()
        b:SetPoint("CENTER", btn, "CENTER", dx, dy)
        b.flyBack:SetOffset(-dx, -dy)
        b.flyOut:SetOffset(dx, dy)
        b:Show()
    end
    for i = #choices + 1, #fly.buttons do
        fly.buttons[i].choice = nil
        fly.buttons[i]:Hide()
    end
    fly.count = #choices
    fly.pts = pts
    fly.sx, fly.sy = sx, sy -- (where the slot was when the points were worked out)
    fly:SetScale(self.db.scale)

    if #choices > 0 then
        local x0, x1, y0, y1 = math.huge, -math.huge, math.huge, -math.huge
        for _, p in ipairs(pts) do
            x0, x1 = math.min(x0, p[1]), math.max(x1, p[1])
            y0, y1 = math.min(y0, p[2]), math.max(y1, p[2])
        end
        local pad = BTN / 2 + 7
        fly:ClearAllPoints()
        fly:SetPoint("TOPLEFT", btn, "CENTER", x0 - pad - sx, y1 + pad - sy)
        fly:SetPoint("BOTTOMRIGHT", btn, "CENTER", x1 + pad - sx, y0 - pad - sy)
        fly.panel:Show()
    else
        fly:ClearAllPoints()
        fly:SetAllPoints(btn)
        fly.panel:Hide()
    end
    if fly:IsShown() then self:PaintFlyout(fly) end
end

-- Out of combat: a slot whose flyout choices are assigned to it does what
-- its chosen one does (your pick, else its default, else the first).
-- Copies the same attributes a choice copies when you click it in combat.
function Kit:ApplyAssigned(btn)
    local slot = btn.slot
    local choices = slot.Choices(self, btn) or {}
    local want = self.cdb.picks[slot.key]
    if want == nil then want = Val(slot.default, self, btn) end
    local found, first
    for _, c in ipairs(choices) do
        if c.assign and c.attrs then
            first = first or c
            if c.value == want then found = c end
        end
    end
    local c = found or first
    btn.assigned = c
    btn.updating = true
    local a = c and c.attrs or {}
    for _, k in ipairs(ASSIGN_KEYS) do btn:SetAttribute(k, a[k]) end
    btn:SetAttribute("kcvalue", c and c.value or nil)
    btn.updating = nil
    if not c and not Val(slot.keepEmpty, self, btn) then btn.hidden = true end
end

function Kit:LayoutFlyouts()
    for _, fly in pairs(self.flyouts) do self:LayoutFlyout(fly.slotBtn) end
end

-- Cosmetic, any time: icons, what's chosen, what can't be used, counts.
function Kit:PaintFlyout(fly)
    for i, b in ipairs(fly.buttons) do
        local c = i <= (fly.count or 0) and b.choice
        if c then
            U.SetIcon(b, Val(c.icon) or 134400, Val(c.dim))
            local sel = Val(c.selected)
            if sel == nil and c.assign then
                local a = fly.slotBtn.assigned
                sel = a and a.value == c.value
            end
            b.sel:SetShown(sel and true or false)
            local n = Val(c.count)
            b.count:SetText(n and n > 1 and n or "")
            if c.cooldown then U.SetCooldown(b.cooldown, c.cooldown()) else b.cooldown:Clear() end
        end
    end
end

-- Out of combat; in combat a flyout closes from its own slot or a choice.
function Kit:CloseFlyouts()
    if InCombatLockdown() then return end
    for _, fly in pairs(self.flyouts) do
        if fly:IsShown() then fly:Hide() end
    end
end

-- A "pick" choice (out of combat): the slot decides what it means.
function Kit:Pick(btn, value)
    if InCombatLockdown() then return end
    local slot = btn.slot
    if slot.OnPick then
        slot.OnPick(self, btn, value)
    else
        self.cdb.picks[slot.key] = value
    end
    self:Refresh(false)
end

---------------------------------------------------------------------------
-- Painting (cosmetic, safe in combat)
---------------------------------------------------------------------------

function Kit:PaintSlot(btn)
    local slot = btn.slot
    btn.pin:SetShown(self.cdb.pinned[slot.key] and true or false)
    btn.note:SetText("")
    if btn.count then btn.count:SetText("") end
    if slot.Paint then slot.Paint(self, btn) end
    local sb = btn.sub
    if sb and sb:IsShown() and sb.def.Paint then sb.def.Paint(self, sb) end
end

function Kit:ApplyFade()
    if not self.built then return end
    for _, btn in pairs(self.slots) do self:FadeSlot(btn) end
    local idle = self:FadeIdle()
    self.kit:SetAlpha(idle and 0.7 or 1)
    local fly = self.flyOpen
    if fly and fly:IsShown() then self.kit:SetAlpha(0.4) end
end

function Kit:FadeIdle()
    return self.db.fadeIdle and not self.open and self.hovering == 0
        and not (self.cfg.Busy and self.cfg.Busy(self))
end

-- One slot's alpha: faded when idle, dimmed while another slot's flyout is
-- open (so its choices stand out), times its slide's fade.
function Kit:FadeSlot(btn)
    local a = self:FadeIdle() and 0.4 or 1
    local fly = self.flyOpen
    if fly and fly:IsShown() and btn ~= fly.slotBtn then a = 0.3 end
    btn:SetAlpha(a * (btn.slideA or 1))
end

function Kit:PaintAll()
    if not self.built then return end
    for _, btn in pairs(self.slots) do
        if btn:IsShown() then self:PaintSlot(btn) end
    end
    for _, fly in pairs(self.flyouts) do
        if fly:IsShown() then self:PaintFlyout(fly) end
    end
    self:SetKitArt()
    self:ApplyFade()
end

---------------------------------------------------------------------------
-- Where the slots sit
---------------------------------------------------------------------------

function Kit:KitHalfUnits()
    return self.kit:GetWidth() * self.kit:GetScale() / 2 / self.db.scale
end

-- Which slots go in each column on a screen edge, from the edge in.
-- asOpen/hypothetical answer "what would show" (for the dock's spacing).
function Kit:EdgeCols(asOpen, hypothetical)
    local function on(btn)
        if hypothetical then return (asOpen and not btn.hidden) or btn.wouldShow end
        if self.trial then return self.trial.vis[btn] and true or false end -- (what would show in that layout)
        return btn:IsShown() and not btn.closing
    end
    local cols = {}
    for _, keys in ipairs(self.cfg.edgeCols or {}) do
        local col = {}
        for _, key in ipairs(keys) do
            local btn = self.slots[key]
            if btn and on(btn) then col[#col + 1] = { frame = btn, size = btn.isSmall and 22 or self.BTN } end
        end
        cols[#cols + 1] = col
    end
    if self.cfg.EdgeExtraCol then cols[#cols + 1] = self.cfg.EdgeExtraCol(self, hypothetical, asOpen) or {} end
    return cols
end

-- The kit's own extra frames (timers and such), if any.
function Kit:Extras()
    return self.cfg.extraFrames and self.cfg.extraFrames(self) or {}
end

-- Small "rim" slots: on the kit's rim, at this angle (degrees).
function Kit:PlaceRim(angle)
    local r = self:KitHalfUnits() - 3
    local placed = false
    for _, btn in pairs(self.slots) do
        if btn.slot.rim then
            self:PlaceAt(btn, r * math.cos(math.rad(angle)), r * math.sin(math.rad(angle)))
            if self:WouldShow(btn) then placed = true end
        end
    end
    return placed
end

function Kit:PlaceAt(f, x, y)
    if self.trial then -- a trial layout only notes where it would go
        self.trial.pos[f] = { x, y }
        return
    end
    if self.collect then -- in a Kit Dock box: noted, for the box's row (see PlaceSlots)
        if f:IsShown() and not f.closing then self.collect[#self.collect + 1] = f end
        return
    end
    if sliding[f] then -- (the slide puts it there; see SlideApply)
        f.placedX, f.placedY = x, y
        return
    end
    if f.placedX ~= x or f.placedY ~= y then
        -- (a dock glide still on its way to the old spot would finish there)
        if self.Dock and self.Dock.StopTween then self.Dock.StopTween(f) end
        f:ClearAllPoints()
        f:SetPoint("CENTER", self.kit, "CENTER", x, y)
        f.placedX, f.placedY = x, y
    end
end

-- The divider goes between two edge columns while the kit is open.
function Kit:EdgeDivAfter(asOpen)
    local d = self.cfg.divider
    return asOpen and d and d.edgeAfter or nil
end

-- The edgeBeside slots: either side of the kit button, along the edge.
-- The i-th one showing: odd before the button, even after, outward in pairs.
local BESIDE_GAP, BESIDE_STEP = 6, 26
function Kit:BesideSpot(side, i)
    local d = self:KitHalfUnits() + BESIDE_GAP + 11 + math.floor((i - 1) / 2) * BESIDE_STEP
    local sign = (i % 2 == 1) and -1 or 1
    if side == "left" or side == "right" then return 0, -sign * d end
    return sign * d, 0
end

-- In a Kit Dock box the button is small and the box sits around it, so
-- what shows (reminders, pinned slots) starts just past the box's inner edge.
local PARKED_INSET = 8

function Kit:PlaceEdge()
    local cols = self:EdgeCols(self.open, false)
    local half = self:KitHalfUnits()
    if self.parked then half = half + PARKED_INSET / self.db.scale end
    local pos, div = self.Dock.EdgeArrange(self.edgeSide, half, cols, self:EdgeDivAfter(self.open))
    for f, p in pairs(pos) do self:PlaceAt(f, p[1], p[2]) end
    local beside = self.cfg.edgeBeside
    if beside then
        local i = 0
        for _, key in ipairs(beside) do
            local btn = self.slots[key]
            if btn and not btn.hidden then
                i = i + 1
                self:PlaceAt(btn, self:BesideSpot(self.edgeSide, i))
            end
        end
    end
    local RIM = { left = 0, right = 180, top = 270, bottom = 90 } -- toward the middle of the screen
    self:PlaceRim(RIM[self.edgeSide] or 0)
    -- Where the divider goes (kept for the combat switch, which has to put it
    -- there without a refresh); false when it keeps its usual spot.
    local spec = div and { x = div[1], y = div[2], w = div[4] and 16 or div[3], h = div[4] and div[3] or 16,
        tw = div[3], rot = div[4] and math.pi / 2 or 0 } or false
    if self.trial then
        self.trial.div = spec
        return
    end
    self.liveDiv = spec
    for _, btn in pairs(self.slots) do self:PlaceSub(btn) end
    local dv = self.divider
    if dv then
        dv:ClearAllPoints()
        if div then
            dv:SetPoint("CENTER", self.kit, "CENTER", div[1], div[2])
            dv:SetSize(div[4] and 16 or div[3], div[4] and div[3] or 16)
            dv.tex:SetSize(div[3], 16)
            dv.tex:SetRotation(div[4] and math.pi / 2 or 0)
        else
            dv:SetPoint("CENTER", self.kit, "CENTER", 0, self.cfg.divider.y)
        end
        dv.edged = true
    end
end

-- Back from an edge: the divider in its usual spot across the kit.
function Kit:UnEdgeDivider()
    local dv = self.divider
    if not dv or not dv.edged then return end
    dv.edged = nil
    self:FaceDivider()
end

-- How much room along the edge the kit takes (UI units).
function Kit:EdgeExtent(side, asOpen)
    local cols = self:EdgeCols(asOpen, true)
    local _, _, ext = self.Dock.EdgeArrange(side, self:KitHalfUnits(), cols, self:EdgeDivAfter(asOpen))
    if self.cfg.edgeBeside then
        -- Room for the slots beside the button that would show.
        local n = 0
        for _, key in ipairs(self.cfg.edgeBeside) do
            local btn = self.slots[key]
            if btn and ((asOpen and not btn.hidden) or btn.wouldShow) then n = n + 1 end
        end
        if n > 0 then
            local pairsOut = math.ceil(n / 2)
            ext = math.max(ext, 2 * (self:KitHalfUnits() + BESIDE_GAP + 22 + (pairsOut - 1) * BESIDE_STEP))
        end
    end
    local any = next(self.slots) and select(2, next(self.slots))
    local k = any and (any:GetEffectiveScale() / UIParent:GetEffectiveScale()) or self.db.scale
    return ext * k
end

-- Where shown slots sit: their home spot round the kit; on a screen edge,
-- in columns toward the middle of the screen; shrunk on the dock, fanned
-- round the outside of the button in its own slice. Out of combat only.
-- Facing (the "Layout direction" setting): the whole layout turns so its
-- top points up, down, left or right. Down is the layout mirrored top to
-- bottom; left and right turn it on its side, with slots that read left to
-- right reading top to bottom.
local FACE = {
    up = function(x, y) return x, y end,
    down = function(x, y) return x, -y end,
    left = function(x, y) return -y, -x end,
    right = function(x, y) return y, -x end,
}
C.FACINGS = { "up", "down", "left", "right" }

-- The layout direction in use: the setting while floating; docked on the
-- pin with other kits, always up, so the merged layout stays as it was.
function Kit:Facing()
    local D = self.Dock
    if D and D.IsDocked and D.IsDocked(self.key) then return "up" end
    return FACE[self.db and self.db.facing] and self.db.facing or "up"
end

function Kit:Face(x, y)
    return FACE[self:Facing()](x, y)
end

function Kit:SetFacing(f)
    if not FACE[f] then return end
    if InCombatLockdown() then self:Print("That can only change out of combat.") return end
    self.db.facing = f
    self:Refresh(false)
    self:KeepOnScreen()
    if self.cfg.OnFacing then self.cfg.OnFacing(self) end
    self:SettingsChanged()
end

function Kit:Sideways()
    local f = self:Facing()
    return f == "left" or f == "right"
end

-- A direction ("up", "left", ...) in the layout, turned the way it faces.
local DIR_VEC = { up = { 0, 1 }, down = { 0, -1 }, left = { -1, 0 }, right = { 1, 0 } }
function Kit:FaceDir(dir)
    local v = DIR_VEC[dir]
    if not v then return dir end
    local x, y = self:Face(v[1], v[2])
    if x > 0.5 then return "right" elseif x < -0.5 then return "left" elseif y > 0.5 then return "up" end
    return "down"
end

-- cfg.ring: the slots that are there (not hidden) share the arc evenly.
-- Fills base[btn] = { x, y } (before facing).
function Kit:LayoutOneRing(ring, base)
    local avail = {}
    for _, key in ipairs(ring.keys) do
        local btn = self.slots[key]
        if btn and not btn.hidden then avail[#avail + 1] = btn end
    end
    -- The full ring's spacing, centred on the arc's middle: with fewer slots
    -- the whole set (ends included) gathers round the top.
    local n = #avail
    local full = #ring.keys
    local step = full > 1 and (ring.to - ring.from) / (full - 1) or 0
    local mid = (ring.from + ring.to) / 2
    for i, btn in ipairs(avail) do
        local a = mid + (i - (n + 1) / 2) * step
        base[btn] = { math.floor(ring.radius * math.cos(math.rad(a)) + 0.5), math.floor(ring.radius * math.sin(math.rad(a)) + 0.5) }
    end
end

-- Every slot's home spot: its place in a ring (cfg.ring) or its pos, turned
-- the way the layout faces. True if any moved.
function Kit:LayoutHomes()
    local base = {}
    local rings = self.cfg.ring
    if rings then
        if rings.keys then rings = { rings } end
        for _, ring in ipairs(rings) do self:LayoutOneRing(ring, base) end
    end
    local moved = false
    for _, btn in pairs(self.slots) do
        local b = base[btn] or btn.slot.pos
        local x, y = self:Face(b[1], b[2])
        if self.trial then
            self.trial.home[btn] = { x, y } -- (the real home spots stay as they are)
        elseif btn.homeX ~= x or btn.homeY ~= y then
            btn.homeX, btn.homeY = x, y
            moved = true
        end
    end
    return moved
end

-- The divider across the kit, turned with the layout.
function Kit:FaceDivider()
    local dv, d = self.divider, self.cfg.divider
    if not dv or dv.edged then return end
    local x, y = self:Face(0, d.y)
    local w = d.width or 200
    local side = self:Sideways()
    dv:ClearAllPoints()
    dv:SetPoint("CENTER", self.kit, "CENTER", x, y)
    dv:SetSize(side and 16 or w, side and w or 16)
    dv.tex:SetSize(w, 16)
    dv.tex:SetRotation(side and math.pi / 2 or 0)
end

-- Whether a slot is out in the layout being placed: the trial one (see
-- TrialLayout), or as it is on screen.
function Kit:WouldShow(btn)
    if self.trial then return self.trial.vis[btn] and true or false end
    return btn:IsShown() and not btn.closing and true or false
end

function Kit:PlaceSlots()
    local ringMoved = self:LayoutHomes()
    -- In a Kit Dock box and closed: what shows (reminders, pinned slots)
    -- goes in one row along the box with the other boxed kits' (Kit Dock
    -- places them), in the order the edge layout would put them.
    if self.parked and not self.open and self.edgeSide and self.Dock and self.Dock.BoxNotices and not self.trial then
        self.collect = {}
        local ok, err = pcall(self.PlaceEdge, self)
        local list = self.collect
        self.collect = nil
        if not ok then
            local h = geterrorhandler and geterrorhandler()
            if h then h(err) end
        end
        self.Dock.BoxNotices(self.key, list)
        return
    end
    if self.edgeSide and self.Dock then return self:PlaceEdge() end
    if self.trial and not self.compactAngle then
        for btn, h in pairs(self.trial.home) do self:PlaceAt(btn, h[1], h[2]) end
        return
    end
    if not self.trial then
        self.liveDiv = false
        self:UnEdgeDivider()
        self:FaceDivider()
        for _, btn in pairs(self.slots) do self:PlaceSub(btn) end
    end
    local angle, span = self.compactAngle, self.compactSpan
    if not angle then
        -- Slots already out glide to new home spots (the ring closing up
        -- round a slot that went away, or opening back out).
        local from
        if ringMoved and self.Dock and self.Dock.Glide then
            from = {}
            for _, btn in pairs(self.slots) do
                if btn:IsShown() and not btn.closing and not sliding[btn] then
                    local x, y = btn:GetCenter()
                    if x then from[btn] = { x, y, btn:GetEffectiveScale() } end
                end
            end
        end
        for _, btn in pairs(self.slots) do self:PlaceAt(btn, btn.homeX, btn.homeY) end
        if self.cfg.PlaceExtras then self.cfg.PlaceExtras(self) end
        if from then
            for f, b in pairs(from) do self.Dock.Glide(f, b[1], b[2], b[3]) end
        end
        return
    end
    -- Shrunk on the dock: whatever's out fans round the button in its slice,
    -- in rings of 4, by tier (if the kit gives them), then pinned slots
    -- first, then the rest, each in slot order. Opened there in combat, that's
    -- every slot (the trial layout works it out ahead of time).
    -- Small rim slots keep a place on the button's rim, on the side the
    -- fan opens toward (away from the pin); the fan starts a little further
    -- out so nothing lands on them.
    local rimOut = self:PlaceRim(angle)
    -- (a kit's extras don't change between open and closed in the fan, so a
    -- trial leaves them alone)
    if self.cfg.PlaceExtras and not self.trial then self.cfg.PlaceExtras(self, angle) end
    local shown = {}
    for _, btn in pairs(self.slots) do
        if self:WouldShow(btn) and not btn.slot.rim then shown[#shown + 1] = btn end
    end
    table.sort(shown, function(a, b)
        local ta, tb = a.slot.tier or 0, b.slot.tier or 0 -- (slot.tier: nearest ring first)
        if ta ~= tb then return ta < tb end
        local pa, pb = self.cdb.pinned[a.slot.key] and 1 or 0, self.cdb.pinned[b.slot.key] and 1 or 0
        if pa ~= pb then return pa > pb end
        return (a.order or 0) < (b.order or 0)
    end)
    local BTN, PER_RING = self.BTN, 4
    local half = self:KitHalfUnits() + (rimOut and 12 or 0)
    local r1 = math.max(half + (BTN / 2 + 4), (BTN + 4) * (PER_RING - 1) / math.rad(span or 115))
    local i = 0
    for ring = 1, math.ceil(#shown / PER_RING) do
        local n = math.min(PER_RING, #shown - (ring - 1) * PER_RING)
        local r = r1 + (ring - 1) * (BTN + 6)
        local step = math.deg((BTN + 4) / r)
        for j = 1, n do
            i = i + 1
            local a = math.rad(angle + (j - (n + 1) / 2) * step)
            self:PlaceAt(shown[i], r * math.cos(a), r * math.sin(a))
        end
    end
end

-- How far the open kit reaches from its centre (its slots and their corner
-- buttons), in UI units: left, right, top, bottom. The kit is kept at least
-- that far from the screen edges so everything fits.
function Kit:Reach()
    local s = self.db.scale
    local half = self.BTN / 2 + 4
    local ks = (self.kit:GetWidth() / 2) * s * (self.db.kitSize or 1) + 4
    local l, r, t, b = ks, ks, ks, ks
    for _, slot in ipairs(self.cfg.slots) do
        local btn = self.slots[slot.key]
        if not (btn and btn.hidden) then -- (a slot that isn't there doesn't need room)
        local x, y = self:Face(slot.pos[1], slot.pos[2])
        local h = slot.small and 15 or half
        local extra = slot.sub and 8 or 0
        local below = slot.sub and slot.sub.below and 26 or 0
        local bx, by = self:Face(0, -below)
        l = math.max(l, (h - math.min(x, x + bx)) * s)
        r = math.max(r, (math.max(x, x + bx) + h + extra) * s)
        t = math.max(t, (math.max(y, y + by) + h) * s)
        b = math.max(b, (h + extra - math.min(y, y + by)) * s)
        end
    end
    return l, r, t, b
end

---------------------------------------------------------------------------
-- Refresh: what each slot holds and whether it shows (out of combat)
---------------------------------------------------------------------------

-- What each slot is and holds right now: the kit's BeforeRefresh, then every
-- slot's Update (and its assigned choice, and its corner button's Update).
function Kit:RunUpdates()
    local cfg = self.cfg
    if cfg.BeforeRefresh then cfg.BeforeRefresh(self) end
    for _, slot in ipairs(cfg.slots) do
        local btn = self.slots[slot.key]
        btn.hidden = nil
        if slot.Update then slot.Update(self, btn) end
        if slot.assign and not btn.hidden then self:ApplyAssigned(btn) end
        local sb = btn.sub
        if sb then
            sb.hidden = nil
            if sb.def.Update then sb.def.Update(self, sb) end
            sb:SetShown(not sb.hidden)
        end
    end
end

-- Whether a slot shows, with the kit open or closed as self.open says.
-- Also whether it's there at all, and whether something pops it out.
function Kit:SlotVisible(slot, btn)
    local pop = slot.Pop and not btn.hidden and slot.Pop(self, btn) or false
    local available = self.db.shown ~= false and not btn.hidden
    local visible = available and (self.open or ((self.cdb.pinned[slot.key] or pop) and not self.tucked)) and true or false
    return visible, available, pop
end

-- Can the kit button open and close this kit in combat? Shrunk on the pin
-- with other kits: yes, in place, every slot fanned out in its slice away
-- from the pin (nothing else moves; out of combat it takes the pin as
-- usual once combat ends). Parked in Kit Dock's box: no, its fan points off
-- the screen. Open on the pin (taking it, the others tucked): no, closing
-- would leave the others tucked.
function Kit:CanSecureToggle()
    if self.noSecureToggle then return false end
    local D = self.Dock
    if self.compactAngle then
        return not (D and D.IsParked and D.IsParked(self.key)) and true or false
    end
    if D and D.IsDocked and D.IsDocked(self.key) and not self.edgeSide then return false end
    return true
end

-- Can the kit be dragged in combat? The same kits as open there, while it
-- isn't pinned in place.
function Kit:CanSecureMove()
    return not self.noSecureMove and not self.db.locked and (self:CanSecureToggle() or self:OnProtectedPin()) and true or false
end

-- On Kit Dock's pin with other kits, and the pin is a protected frame (Kit
-- Dock v19), so the grip can move the pin, and the whole dock with it.
function Kit:OnProtectedPin()
    local D = self.Dock
    if not (D and D.IsDocked and D.IsDocked(self.key)) then return false end
    if D.EdgeSide and D.EdgeSide(self.key) then return false end
    local pin = D.pin
    return pin and pin.IsProtected and pin:IsProtected() and D.SavePinAt and true or false
end

-- What the drag snippets need (out of combat): whether this kit may move,
-- and the button's scale against the holder's.
function Kit:PushMoveInfo()
    if InCombatLockdown() then return end
    local kit = self.kit
    kit:SetAttribute("kcmovable", self:CanSecureMove() and 1 or 0)
    local hs = self.holder:GetEffectiveScale()
    kit:SetAttribute("kcks", hs > 0 and kit:GetEffectiveScale() / hs or 1)
    kit:SetAttribute("kcmovestep", nil)
    local onPin = self.grip and self:OnProtectedPin()
    kit:SetAttribute("kconpin", onPin and 1 or 0)
    if onPin then
        local D = self.Dock
        local pin = D.pin
        SecureHandlerSetFrameRef(self.grip, "kcpin", pin)
        kit:SetAttribute("kcpinks", hs > 0 and pin:GetEffectiveScale() / hs or 1)
        -- Every kit on the pin (their buttons are secure: Kit Core v5 on),
        -- for the grip to move together (see GRIP_CLICK).
        local n = 0
        for key, api in pairs(D.kits or {}) do
            local b = api.kit
            if b and b.IsProtected and b:IsProtected() and D.IsDocked(key) and not (D.EdgeSide and D.EdgeSide(key)) then
                n = n + 1
                SecureHandlerSetFrameRef(self.grip, "kcdock" .. n, b)
                if b ~= kit then
                    local bs = b:GetEffectiveScale()
                    b:SetAttribute("kcks", hs > 0 and bs / hs or 1) -- (its own kit sets this too)
                end
            end
        end
        self.grip:SetAttribute("kcdockn", n)
    end
end

-- Where a frame's centre is, in UIParent units.
local function UICenter(f)
    local x, y = f:GetCenter()
    if not x then return nil end
    local k = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
    return x * k, y * k
end

-- The faint copy of the kit button that follows the mouse while you drag it
-- in combat (not secure, so it can move). It starts where the button is,
-- and moves as the mouse has since you pressed.
function Kit:StartGhost()
    local g = self.ghost
    if not g then
        g = CreateFrame("Frame", nil, UIParent)
        g:SetFrameStrata("TOOLTIP")
        g.icon = g:CreateTexture(nil, "ARTWORK")
        g.icon:SetAllPoints()
        local mask = g:CreateMaskTexture()
        mask:SetTexture(self.media .. "circle_mask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(g.icon)
        g.icon:AddMaskTexture(mask)
        g.ring = g:CreateTexture(nil, "OVERLAY")
        g.ring:SetAllPoints()
        g.ring:SetTexture(self.media .. "glow_ring")
        g.ring:SetBlendMode("ADD")
        g:Hide()
        g:SetScript("OnUpdate", function(f)
            -- (let go somewhere the release didn't reach: stop following)
            if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then f:Hide() return end
            local cx, cy = GetCursorPosition()
            local s = UIParent:GetEffectiveScale()
            local dx, dy = cx / s - f.downX, cy / s - f.downY
            if not f.active then
                if dx * dx + dy * dy < 64 then return end -- (a click so far)
                f.active = true
                f:SetAlpha(0.55)
                GameTooltip:Hide()
            end
            f:ClearAllPoints()
            f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", f.fromX + dx, f.fromY + dy)
        end)
        self.ghost = g
    end
    local kit = self.kit
    local x, y = UICenter(kit)
    if not x then return end
    local s = UIParent:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    g.fromX, g.fromY = x, y
    g.downX, g.downY = cx / s, cy / s
    local size = kit:GetWidth() * kit:GetEffectiveScale() / s
    g:SetSize(size, size)
    g.icon:SetTexture(kit.icon:GetTexture())
    g.icon:SetTexCoord(kit.icon:GetTexCoord())
    g.active = false
    g:SetAlpha(0) -- (shows once the mouse has moved: until then it's a click)
    g:ClearAllPoints()
    g:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
    g:Show()
end

function Kit:StopGhost()
    if self.ghost then self.ghost:Hide() end
end

-- In combat, the grip's press and click (after GRIP_CLICK): follow along.
function Kit:NoteCombatPress()
    self.combatPress = { UICenter(self.kit) }
    if self:CanSecureMove() then self:StartGhost() end
end

local MOVE_FAIL = {
    [""] = "the press didn't reach the kit's secure code",
    down = "the game didn't give the kit the mouse position",
    ["down-ok"] = "the game didn't give the kit the mouse position on release",
    ["up-pos"] = "the game didn't give the kit the button's position",
    ["up-rect"] = "the game didn't let the kit move the button",
}

function Kit:GripClicked(mouse, down)
    if mouse == "RightButton" then
        if IsShiftKeyDown() then self:OpenSettings() else self:OpenMenu() end
        return
    end
    if mouse ~= "LeftButton" or down then return end
    local dragged = self.ghost and self.ghost:IsShown() and self.ghost.active
    self:StopGhost()
    local press = self.combatPress
    self.combatPress = nil
    -- (where GRIP_CLICK put the button: the game's own answer lags behind)
    local kit = self.kit
    local step = kit:GetAttribute("kcmovestep")
    if step == "moved-pin" then
        -- The whole dock moved: the pin's new spot is saved for the dock, which
        -- lays everything out there after combat (see FinishCombatMove).
        local hs = self.holder:GetEffectiveScale() / UIParent:GetEffectiveScale()
        self.Dock.SavePinAt((kit:GetAttribute("kcdropx") or 0) * hs, (kit:GetAttribute("kcdropy") or 0) * hs)
        self.pinMoved = true
    end
    local moved = step == "moved" or step == "moved-pin"
    local toggled = (kit:GetAttribute("kcisopen") == 1) ~= self.open
    if step == "moved" then
        local hs = self.holder:GetEffectiveScale() / UIParent:GetEffectiveScale()
        local x, y = (kit:GetAttribute("kcdropx") or 0) * hs, (kit:GetAttribute("kcdropy") or 0) * hs
        self.combatDrop = { x, y }
        -- Saved now, so anything that puts the kit at its saved spot as
        -- combat ends puts it here.
        self:SavePositionAt(x, y)
    end
    if toggled then self:CombatToggled() end -- (a click: GRIP_CLICK opened or closed it)
    if dragged and not moved and self:CanSecureMove() and not self.moveFailSaid then
        self.moveFailSaid = true
        local step = self.kit:GetAttribute("kcmovestep") or ""
        self:Print("Couldn't move the kit in combat: " .. (MOVE_FAIL[step] or ("stopped at " .. step)) .. ".", true)
    elseif not (dragged or moved or toggled) then
        self:CombatToggled() -- (a click that didn't open it: says why)
    end
end

-- After combat: finish a drop made in combat as an ordinary drag would.
-- Called a frame after combat ends (see OnEvent), once the game has worked
-- out where everything is: read straight after a frame's anchor changes,
-- its position can come back as the screen's corner, and the kit and its
-- slots would glide in from there. The button is put back where it was
-- dropped first, in case the dock laid the kits out again as combat ended.
-- With Kit Dock, its own drag start and stop do the rest (snap to an edge
-- or another kit, save), with the button's StartMoving and
-- StopMovingOrSizing stood in for: there's no mouse drag to follow, and
-- those would re-anchor the button from wherever the game thinks it is.
function Kit:FinishCombatMove()
    if self.pinMoved and not InCombatLockdown() then
        self.pinMoved = nil
        if self.Dock and self.Dock.Layout then self.Dock.Layout() end -- (the pin to its saved spot, the kits round it)
    end
    local drop = self.combatDrop
    self.combatDrop = nil
    if not drop or InCombatLockdown() then return end
    local kit = self.kit
    local k = kit:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local x, y = UICenter(kit)
    if not x or math.abs(x - drop[1]) > 1 or math.abs(y - drop[2]) > 1 then
        kit:ClearAllPoints()
        kit:SetPoint("CENTER", UIParent, "BOTTOMLEFT", drop[1] / k, drop[2] / k)
    end
    local D = self.Dock
    if D and D.DragStart and D.DragStop and D.kits and D.kits[self.key] then
        local function Still() end
        kit.StartMoving, kit.StopMovingOrSizing = Still, Still
        local ok, err = pcall(function()
            D.DragStart(self.key)
            D.DragStop(self.key)
        end)
        kit.StartMoving, kit.StopMovingOrSizing = nil, nil -- (the real ones again)
        if not ok then
            local h = geterrorhandler and geterrorhandler()
            if h then h(err) end
        end
    else
        self:SavePosition()
        self:KeepOnScreen()
    end
end

-- A layout (open or closed) for the combat switch: for every slot whether it
-- shows and where it goes, and for the divider whether it shows and where.
-- t = { vis = { [btn] = bool }, pos = { [btn] = { x, y } }, div = spec | false }
function Kit:StoreSnap(open, t)
    local snap = { vis = t.vis, pos = {}, div = t.div or false, rowOut = false }
    for btn, v in pairs(t.vis) do
        if v then
            local p = t.pos[btn]
            snap.pos[btn] = p and { p[1], p[2] } or { btn.placedX or btn.homeX or 0, btn.placedY or btn.homeY or 0 }
        end
    end
    local d = self.cfg.divider
    if open and d and not self.compactAngle then -- (no divider in a fan on the pin)
        for _, key in ipairs(d.below or {}) do
            local b = self.slots[key]
            if b and t.vis[b] then snap.rowOut = true end
        end
    end
    self.snap[open and true or false] = snap
end

-- The layout the kit isn't in right now, worked out without touching a frame:
-- the kit's own updates run again with kit.open flipped (kit.trial set), and
-- the placement code notes where each slot would go instead of moving it.
-- The refresh that follows runs the updates again for the real layout, so
-- nothing is left in the flipped state.
function Kit:TrialLayout()
    local real = self.open
    local t = { vis = {}, pos = {}, home = {}, div = false }
    self.trial, self.open = t, not real
    local ok, err = pcall(function()
        self:RunUpdates()
        for _, slot in ipairs(self.cfg.slots) do
            local btn = self.slots[slot.key]
            t.vis[btn] = (self:SlotVisible(slot, btn))
        end
        self:PlaceSlots()
    end)
    self.trial, self.open = nil, real
    if ok then
        self:StoreSnap(not real, t)
    else
        self.snap[not real] = nil
        if not self.trialFailed then -- (said once: it would come up on every refresh)
            self.trialFailed = true
            local h = geterrorhandler and geterrorhandler()
            if h then h(err) end
        end
    end
end

-- Hand every slot its two layouts as attributes, for the kit button's secure
-- snippet to use in combat (KIT_PRE). Out of combat only.
function Kit:PushSnapshot()
    local kit = self.kit
    local ready = self:CanSecureToggle() and self.snap[true] and self.snap[false] and true or false
    for _, slot in ipairs(self.cfg.slots) do
        local btn = self.slots[slot.key]
        for _, which in ipairs({ { true, "o" }, { false, "c" } }) do
            local s = ready and self.snap[which[1]]
            local p = s and s.pos[btn]
            btn:SetAttribute("kc" .. which[2] .. "show", p and 1 or 0)
            btn:SetAttribute("kc" .. which[2] .. "x", p and p[1] or 0)
            btn:SetAttribute("kc" .. which[2] .. "y", p and p[2] or 0)
        end
    end
    kit:SetAttribute("kcisopen", self.open and 1 or 0)
    kit:SetAttribute("kcready", ready and 1 or 0)
    self:PushMoveInfo()
end

function Kit:Refresh(animate)
    if not self.built or self.trial then return end
    self.snap = self.snap or {} -- (a kit made by an older copy's NewKit, before this one loaded)
    if InCombatLockdown() then
        self.pending = true
        self:PaintAll()
        return
    end
    self.pending = false
    if self.opening then animate = "open" end -- a refresh from the dock's layout while this kit is opening
    local cfg, db, cdb = self.cfg, self.db, self.cdb

    local canToggle = self:CanSecureToggle()
    if canToggle then
        self:TrialLayout()
    else
        self.snap[true], self.snap[false] = nil, nil
    end
    self:RunUpdates()

    -- On an edge, slots already out (pinned or popped) move between the
    -- closed strip and their open columns: note where they are so they glide.
    local from
    if self.edgeSide and (animate == "open" or animate == "close") then
        from = {}
        local function Note(f)
            if f:IsShown() and not f.closing then
                local x, y = f:GetCenter()
                if x then from[f] = { x, y, f:GetEffectiveScale() } end
            end
        end
        for _, btn in pairs(self.slots) do Note(btn) end
        for _, f in ipairs(self:Extras()) do Note(f) end
    end

    local slides, total = {}, #cfg.slots
    local vis = {}
    for i, slot in ipairs(cfg.slots) do
        local btn = self.slots[slot.key]
        local visible, available, pop = self:SlotVisible(slot, btn)
        vis[btn] = visible
        if visible then
            CancelClose(self, btn)
            if not btn:IsShown() then
                btn:Show()
                if animate == "open" then
                    slides[#slides + 1] = { btn, i } -- once it knows where it's going
                elseif animate == "untuck" and self.Dock and self.Dock.Fade and not Fighting() then
                    self.Dock.Fade(btn, false)
                end
            end
        elseif btn:IsShown() and not btn.closing then
            if btn.fly and btn.fly:IsShown() then btn.fly:Hide() end
            if btn.hidden or Fighting() then btn:Hide() else PlayClose(self, btn, i, total) end -- (see Fighting)
        end
        btn.wouldShow = available and (cdb.pinned[slot.key] or pop) and true or false
    end

    -- The divider shows while the kit is open and its row below is out.
    local dv = self.divider
    if dv then
        local rowOut = false
        if self.open and not self.compactAngle then
            for _, key in ipairs(cfg.divider.below or {}) do
                local b = self.slots[key]
                if b and b:IsShown() and not b.closing then rowOut = true end
            end
        end
        if rowOut and not dv:IsShown() then
            dv:Show()
            dv.fadeIn:Play()
        elseif not rowOut then
            dv:Hide()
        end
    end

    self:PlaceSlots()
    self:LayoutFlyouts()
    for _, sl in ipairs(slides) do self:PlaySlide(sl[1], sl[2]) end
    if from and self.Dock and self.Dock.Glide then
        for f, b in pairs(from) do
            if f:IsShown() and not f.closing then self.Dock.Glide(f, b[1], b[2], b[3]) end
        end
    end
    -- This layout, for the combat switch, beside the other one worked out above.
    if canToggle then self:StoreSnap(self.open, { vis = vis, pos = {}, div = self.liveDiv }) end
    self:PushSnapshot()
    self:PaintAll()
end

function Kit:SetOpen(want)
    if InCombatLockdown() then return end
    self.open = want and true or false
    self:CloseFlyouts()
    local D = self.Dock
    if D and self.open then
        -- Docked: the kit glides onto the pin first, then its slots fan out.
        -- The dock's layout refreshes this kit on the way; self.opening makes
        -- that refresh slide the slots out rather than just show them.
        if D.IsDocked(self.key) then self.slideDelay = 0.18 end
        self.opening = true
        D.Opening(self.key)
        self.opening = nil
    end
    self:Refresh(self.open and "open" or "close")
    self.slideDelay = nil
    if D and not self.open then D.Closed(self.key) end
end

function Kit:Toggle()
    -- (a key binding or the minimap button: only a click on the kit button
    -- itself can run the secure snippet that opens it in combat)
    if InCombatLockdown() then
        self:Print(self:CanSecureToggle() and "Click the kit button to open or close it in combat."
            or "That can only change out of combat.")
        return
    end
    self:SetOpen(not self.open)
end

-- The kit button was clicked in combat. Its secure snippet (KIT_PRE) has
-- already switched the slots, if it could, and said so in "kcisopen". This
-- catches up what a snippet can't reach: where the kit thinks everything is,
-- the divider, the fade, the paint, and the kit's own extras. Anything moved
-- is tidied by the refresh when combat ends.
function Kit:CombatToggled()
    local kit = self.kit
    self.snap = self.snap or {}
    local now = kit:GetAttribute("kcisopen") == 1
    local s = self.snap[now]
    if kit:GetAttribute("kcready") ~= 1 or now == self.open or not s then
        self:Print("That can only change out of combat.")
        return
    end
    self.open = now
    self.combatToggled = true
    for btn, p in pairs(s.pos) do btn.placedX, btn.placedY = p[1], p[2] end
    local dv = self.divider
    if dv then
        dv:SetShown(s.rowOut and true or false)
        if s.rowOut then
            local sp = s.div
            dv:ClearAllPoints()
            if sp then
                dv:SetPoint("CENTER", kit, "CENTER", sp.x, sp.y)
                dv:SetSize(sp.w, sp.h)
                dv.tex:SetSize(sp.tw, 16)
                dv.tex:SetRotation(sp.rot)
                dv.edged = true
            else
                dv:SetPoint("CENTER", kit, "CENTER", self:Face(0, self.cfg.divider.y))
            end
        end
    end
    self:ApplyFade()
    self:PaintAll()
    if self.cfg.OnCombatToggle then self.cfg.OnCombatToggle(self, now) end
end

function Kit:TogglePin(key)
    local slot = self.slotByKey[key]
    if InCombatLockdown() or not slot or slot.noPin then return end
    self.cdb.pinned[key] = not self.cdb.pinned[key]
    self:Print(slot.label .. (self.cdb.pinned[key] and ": always shown." or ": hides when the kit closes."))
    self:Refresh(false)
    if self.Dock then self.Dock.Layout() end -- an edge strip grows or shrinks
    self:SettingsChanged()
end

---------------------------------------------------------------------------
-- Position, moving, tucking, showing
---------------------------------------------------------------------------

-- The kit's spot is saved as its centre, measured from the nearest part of
-- the screen (a corner, an edge's middle, or the middle) in UIParent units,
-- marked "ui". Anchor offsets are in a frame's own scale, so a spot saved in
-- the kit's own units moved whenever its size changed: the kit slid toward
-- or away from its anchor instead of growing and shrinking where it stands.
-- Spots saved before (no "ui" mark) are in the kit's own units; PlaceFree
-- puts those back as they were and saves them again the new way.
function Kit:SavePosition()
    local kit = self.kit
    local x, y = kit:GetCenter()
    if not x then return end
    local k = kit:GetEffectiveScale() / UIParent:GetEffectiveScale()
    self:SavePositionAt(x * k, y * k)
end

-- The same, for a centre given in UIParent units.
function Kit:SavePositionAt(x, y)
    local W, H = UIParent:GetWidth(), UIParent:GetHeight()
    local h = x < W / 3 and "LEFT" or x > W * 2 / 3 and "RIGHT" or ""
    local v = y < H / 3 and "BOTTOM" or y > H * 2 / 3 and "TOP" or ""
    local rel = (v .. h ~= "") and (v .. h) or "CENTER"
    local ax = h == "LEFT" and 0 or h == "RIGHT" and W or W / 2
    local ay = v == "BOTTOM" and 0 or v == "TOP" and H or H / 2
    self.db.point = { "CENTER", rel, x - ax, y - ay, "ui" }
end

-- Pinned slots stay out while the kit is closed, anchored to its button, so
-- when the button moves in one go they'd jump while the button glides.
-- BeginMove notes where each showing slot is; EndMove, after the move,
-- slides each one from there in step with the button. Brackets can nest.
function Kit:BeginMove()
    self.moveDepth = (self.moveDepth or 0) + 1
    if self.moveDepth > 1 then return end
    self.slotSnap = {}
    local function Note(f)
        if f:IsShown() then
            local x, y = f:GetCenter()
            if x then self.slotSnap[f] = { x, y, f:GetEffectiveScale() } end
        end
    end
    for _, btn in pairs(self.slots) do Note(btn) end
    for _, f in ipairs(self:Extras()) do Note(f) end
end

function Kit:EndMove()
    self.moveDepth = math.max(0, (self.moveDepth or 1) - 1)
    if self.moveDepth > 0 then return end
    local snap = self.slotSnap or {}
    if self.Dock and self.Dock.Glide then
        for f, s in pairs(snap) do
            if f:IsShown() and not sliding[f] then
                self.Dock.Glide(f, s[1], s[2], s[3])
            end
        end
    end
    self.slotSnap = nil
end

-- Slide a free-standing kit in from the edge if its slots wouldn't fit.
function Kit:KeepOnScreen()
    if InCombatLockdown() then return end
    local kit = self.kit
    local l, r, t, b = self:Reach()
    local x, y = kit:GetCenter()
    if not x then return end
    local bx, by, bs = x, y, kit:GetEffectiveScale()
    local k = bs / UIParent:GetEffectiveScale()
    x, y = x * k, y * k
    local W, H = UIParent:GetWidth(), UIParent:GetHeight()
    local nx = math.min(math.max(x, l), math.max(l, W - r))
    local ny = math.min(math.max(y, b), math.max(b, H - t))
    if math.abs(nx - x) > 0.5 or math.abs(ny - y) > 0.5 then
        self:BeginMove()
        kit:ClearAllPoints()
        kit:SetPoint("CENTER", UIParent, "BOTTOMLEFT", nx / k, ny / k)
        self:SavePosition()
        if self.Dock and self.Dock.Glide then self.Dock.Glide(kit, bx, by, bs) end
        self:EndMove()
    end
end

-- This kit's own saved spot (when the dock isn't placing it).
function Kit:PlaceFree()
    local p = self.db.point
    local kit = self.kit
    kit:ClearAllPoints()
    if p[5] == "ui" then
        local k = kit:GetEffectiveScale() / UIParent:GetEffectiveScale()
        kit:SetPoint(p[1], UIParent, p[2], p[3] / k, p[4] / k)
    else
        kit:SetPoint(p[1], UIParent, p[2], p[3], p[4])
        self:SavePosition()
    end
    self:KeepOnScreen()
end

-- Hide (or bring back) the kit and its pinned slots while another docked
-- kit is open on the pin. Out of combat only (the dock makes sure).
function Kit:Tuck(on)
    on = on and true or false
    if self.tucked == on then return end
    self.tucked = on
    if InCombatLockdown() then return end
    local kit = self.kit
    local want = not on and self.db.shown ~= false
    if self.Dock and self.Dock.Fade and kit:IsShown() ~= want and not Fighting() then
        if want then
            kit:Show()
            self.Dock.Fade(kit, false)
        else
            self.Dock.Fade(kit, true, function()
                if self.tucked and not InCombatLockdown() then kit:Hide() end
            end)
        end
    else
        kit:SetShown(want)
    end
    self:Refresh(not on and "untuck" or false)
end

-- Parked in a Kit Dock box (a small button in a row): its pinned and popped
-- slots show just inside the box, laid out as on that edge. Out of combat
-- (the dock makes sure).
function Kit:Park(on)
    on = on and true or false
    if self.parked == on then return end
    self.parked = on
    self:Refresh(false)
end

-- Show or hide the whole kit (settings, the shared minimap menu, slash).
function Kit:SetShownKit(show)
    if InCombatLockdown() then self:Print("That can only change out of combat.") return end
    self.db.shown = show and true or false
    if not show and self.open then self:SetOpen(false) end
    self.kit:SetShown(show and not self.tucked)
    self:Refresh(false)
    if self.Dock then self.Dock.Layout() end
    self:SettingsChanged()
end

-- A docked kit (on the pin or a screen edge) is anchored by offsets in its
-- own scale, so resizing it before the dock places it would fling it away,
-- and the dock would then glide it back from there. The dock resizes it
-- itself (BaseScale) as it lays it out, from where it really stood. Slots
-- are resized inside one BeginMove / EndMove, so they glide to their new
-- spots with the button instead of snapping.
function Kit:ApplyPosition()
    if InCombatLockdown() then self.pending = true return end
    local db = self.db
    local scale = db.scale * (db.kitSize or 1)
    self:BeginMove()
    for _, btn in pairs(self.slots) do btn:SetScale(db.scale) end
    for _, fly in pairs(self.flyouts) do fly:SetScale(db.scale) end
    if self.divider then self.divider:SetScale(db.scale) end
    for _, f in ipairs(self:Extras()) do f:SetScale(db.scale) end
    if self.Dock and self.Dock.IsDocked(self.key) then
        -- (the dock glides the kit from its old size, so its scale is short
        -- of the new one until the glide ends: never set it here)
        self.Dock.Layout()
    else
        self.kit:SetScale(scale)
        self:PlaceFree()
    end
    self:SetKitArt()
    self:ApplyShapes()
    self:EndMove()
end

function Kit:SettingsChanged()
    if self.OnSettingsChanged then self:OnSettingsChanged() end
end

---------------------------------------------------------------------------
-- Kit Dock
---------------------------------------------------------------------------

function Kit:RegisterDock()
    local D = self.Dock
    if not D then return end
    D.Register(self.key, {
        kit = self.kit,
        name = self.name,
        edgesOnly = self.cfg.edgesOnly,
        IsOpen = function() return self.open end,
        Close = function() self:SetOpen(false) end,
        Tuck = function(on) self:Tuck(on) end,
        PlaceFree = function() self:PlaceFree() end,
        SaveFree = function() self:SavePosition() end,
        BaseScale = function() return self.db.scale * (self.db.kitSize or 1) end,
        Reach = function() return self:Reach() end,
        IsHidden = function() return self.db.shown == false end,
        SetHidden = function(hide) self:SetShownKit(not hide) end,
        OpenSettings = function() self:OpenSettings() end,
        ApplyMinimap = function() self:ApplyMinimap() end,
        BeginMove = function() self:BeginMove() end,
        EndMove = function() self:EndMove() end,
        SettingsChanged = function() self:SettingsChanged() end,
        HidesInCombat = function() return self.db.hideInCombat and true or false end,
        UiScale = function() return self.db.scale end,
        Park = function(on) self:Park(on) end,
        Refresh = function() if not InCombatLockdown() then self:Refresh(false) end end,
        Compact = function(on, angle, span)
            self.compactAngle, self.compactSpan = on and angle or nil, span
            self:Refresh(false)
        end,
        Edge = function(side)
            self.edgeSide = side
            self:Refresh(false)
        end,
        EdgeExtent = function(side, asOpen) return self:EdgeExtent(side, asOpen) end,
    })
end

---------------------------------------------------------------------------
-- Minimap button: left-click settings, right-click open / close, drag to
-- slide it round the minimap. Steps aside for Kit Dock's shared button.
---------------------------------------------------------------------------

function Kit:PlaceMinimap()
    local b = self.minimap
    if not b then return end
    local angle = math.rad(self.db.minimapAngle or 200)
    local r = (Minimap:GetWidth() / 2) + 6
    b:ClearAllPoints()
    b:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * r, math.sin(angle) * r)
end

function Kit:ApplyMinimap()
    local b = self.minimap
    if not b then return end
    local shared = self.Dock and self.Dock.SharedMinimap and self.Dock.SharedMinimap()
    b:SetShown(self.db.minimapButton and not shared and true or false)
    self:PlaceMinimap()
end

function Kit:SetupMinimap()
    if self.minimap or not Minimap then return end
    local b = CreateFrame("Button", self.prefix .. "MinimapButton", Minimap)
    b:SetSize(31, 31)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    local icon = b:CreateTexture(nil, "ARTWORK")
    if self.cfg.minimapArt then
        -- The kit's own art, which has its own rim: 27 across inside the 31
        -- button, the same size as other addons' minimap buttons.
        icon:SetPoint("TOPLEFT", 2, -2)
        icon:SetPoint("BOTTOMRIGHT", -2, 2)
        icon:SetTexture(Val(self.cfg.minimapArt, self), nil, nil, "LINEAR")
    else
        icon:SetPoint("TOPLEFT", 7, -7)
        icon:SetPoint("BOTTOMRIGHT", -7, 7)
        icon:SetTexture(Val(self.cfg.minimapIcon, self) or 134400)
        local mask = b:CreateMaskTexture()
        mask:SetTexture(self.media .. "circle_mask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(icon)
        icon:AddMaskTexture(mask)
        local ring = b:CreateTexture(nil, "OVERLAY")
        ring:SetPoint("TOPLEFT", 2, -2)
        ring:SetPoint("BOTTOMRIGHT", -2, 2)
        ring:SetTexture(self.media .. "ring_prof_64", nil, nil, "LINEAR")
    end
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture(self.media .. "glow_ring")
    hl:SetBlendMode("ADD")
    hl:SetPoint("TOPLEFT", 2, -2)
    hl:SetPoint("BOTTOMRIGHT", -2, 2)
    hl:SetAlpha(0.5)
    b:SetScript("OnClick", function(_, mouse)
        if mouse == "RightButton" then self:Toggle() else self:OpenSettings() end
    end)
    b:SetScript("OnDragStart", function(btn)
        btn:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local px, py = GetCursorPosition()
            local sc = Minimap:GetEffectiveScale()
            self.db.minimapAngle = math.deg(math.atan2(py / sc - my, px / sc - mx)) % 360
            self:PlaceMinimap()
        end)
        GameTooltip:Hide()
    end)
    b:SetScript("OnDragStop", function(btn) btn:SetScript("OnUpdate", nil) end)
    b:SetScript("OnEnter", function(btn)
        GameTooltip:SetOwner(btn, "ANCHOR_LEFT")
        GameTooltip:AddLine(self.name)
        GameTooltip:AddLine("Left-click: settings", 1, 1, 1)
        GameTooltip:AddLine("Right-click: open / close the kit", 1, 1, 1)
        GameTooltip:AddLine("Drag: move around the minimap", 1, 1, 1)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    self.minimap = b
    self:ApplyMinimap()
end

---------------------------------------------------------------------------
-- Settings panel (Esc > Options > AddOns > the kit), modern Settings API.
-- If this build's API differs, the kit still works through its slash command.
---------------------------------------------------------------------------

function Kit:OpenSettings()
    if self.openSettings then
        self.openSettings()
    else
        self:Print("The settings panel isn't available on this build. " .. (self.cfg.slash and self.cfg.slash[1] or "") .. " help lists the slash commands.", true)
    end
end

function Kit:BuildSettings()
    local cfg, db, cdb = self.cfg, self.db, self.cdb
    local registered = {}
    local VAR_BOOL = (Settings.VarType and Settings.VarType.Boolean) or "boolean"
    local VAR_NUM = (Settings.VarType and Settings.VarType.Number) or "number"
    local category, layout = Settings.RegisterVerticalLayoutCategory(self.name)
    local P = self.prefix

    local function OnChange(setting, fn)
        if not fn then return end
        if Settings.SetOnValueChangedCallback then
            Settings.SetOnValueChangedCallback(setting:GetVariable(), function() fn() end)
        elseif setting.SetValueChangedCallback then
            setting:SetValueChangedCallback(function() fn() end)
        end
    end

    local S = {}
    function S.Header(text)
        if CreateSettingsListSectionHeaderInitializer then
            layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
        end
    end
    function S.Checkbox(tbl, key, name, tooltip, default, fn, id)
        local s = Settings.RegisterAddOnSetting(category, P .. "_" .. (id or key), key, tbl, VAR_BOOL, name, default)
        Settings.CreateCheckbox(category, s, tooltip)
        OnChange(s, fn)
        registered[#registered + 1] = { setting = s, tbl = tbl, key = key }
        return s
    end
    function S.Slider(tbl, key, name, tooltip, default, min, max, step, fmt, fn)
        local s = Settings.RegisterAddOnSetting(category, P .. "_" .. key, key, tbl, VAR_NUM, name, default)
        local opts = Settings.CreateSliderOptions(min, max, step)
        if MinimalSliderWithSteppersMixin and fmt then
            opts:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, fmt)
        end
        Settings.CreateSlider(category, s, opts, tooltip)
        OnChange(s, fn)
        registered[#registered + 1] = { setting = s, tbl = tbl, key = key }
        return s
    end
    -- list: { { value, label }, ... } (string values)
    function S.Dropdown(tbl, key, name, tooltip, default, list, fn)
        if not (Settings.CreateDropdown and Settings.CreateControlTextContainer) then return end
        local VAR_STR = (Settings.VarType and Settings.VarType.String) or "string"
        local s = Settings.RegisterAddOnSetting(category, P .. "_" .. key, key, tbl, VAR_STR, name, default)
        local function Options()
            local c = Settings.CreateControlTextContainer()
            for _, o in ipairs(list) do c:Add(o[1], o[2]) end
            return c:GetData()
        end
        Settings.CreateDropdown(category, s, Options, tooltip)
        OnChange(s, fn)
        registered[#registered + 1] = { setting = s, tbl = tbl, key = key }
        return s
    end
    function S.Button(name, text, tooltip, fn)
        if CreateSettingsButtonInitializer then
            layout:AddInitializer(CreateSettingsButtonInitializer(name, text, fn, tooltip, true))
        end
    end
    local pct = function(v) return math.floor(v * 100 + 0.5) .. "%" end
    local refresh = function() self:Refresh(false) end

    S.Header("Kit")
    S.Checkbox(db, "shown", "Show " .. self.name,
        "Turn off to hide the whole kit (its button and every slot) without uninstalling it.",
        true, function() self:SetShownKit(db.shown) end)
    S.Checkbox(db, "locked", "Pin in place", "Stop the kit from being dragged. Also in the kit's right-click menu.", false)
    S.Slider(db, "scale", "Size", "Scales the kit and its slots together.", 1, 0.6, 1.6, 0.05, pct,
        function() self:ApplyPosition() end)
    S.Slider(db, "kitSize", "Kit button size", "Makes the button in the middle smaller without changing the slots around it.",
        1, 0.5, 1, 0.05, pct, function() self:ApplyPosition() end)
    S.Checkbox(db, "minimapButton", "Show minimap button",
        "Left-click for these settings, right-click to open the kit, drag to move it.", true,
        function() self:ApplyMinimap() end)
    S.Checkbox(db, "chatNotices", "Chat messages",
        "Notices in chat when something changes (pinned in place, always shown, snoozed and the like). Slash commands still answer in chat.", true)
    S.Checkbox(db, "tooltipDefault", "Default tooltip position",
        "Show slot tooltips where the game normally shows tooltips, instead of beside the slot.", false)
    S.Checkbox(db, "roundSlots", "Round slots",
        "Round icons with a gold ring instead of square bag slots.", true, function() self:ApplyShapes() end)
    S.Checkbox(db, "fadeIdle", "Fade when idle",
        "The kit and pinned slots fade until you mouse over them.", false, refresh)
    if not self.cfg.alwaysHideInCombat then
        S.Checkbox(db, "hideInCombat", "Hide in combat", "Hide the kit while you're in combat.", false,
            function() self:ApplyCombatHide() end)
    end
    S.Dropdown(db, "facing", "Layout direction",
        "Which way the slots lay out round the kit while it's floating (on a screen edge they always face the middle of the screen).",
        "up", {
            { "up", "Up (as made)" },
            { "down", "Down (upside down)" },
            { "left", "Left (on its side)" },
            { "right", "Right (on its side)" },
        }, function() self:SetFacing(db.facing) end)
    S.Slider(db, "flyoutHide", "Drawer close delay in combat",
        "In combat a drawer can't close when you click elsewhere, so it closes by itself this long after the mouse leaves it and its slot.",
        0.5, 0.2, 2, 0.1, function(v) return ("%.1fs"):format(v) end)

    if cfg.Settings then cfg.Settings(self, S) end

    S.Header("Slots (this character)")
    local listed = cfg.slots
    if cfg.menuOrder then
        listed = {}
        for _, key in ipairs(cfg.menuOrder) do listed[#listed + 1] = self.slotByKey[key] end
    end
    for _, slot in ipairs(listed) do
        if not slot.noPin then
            S.Checkbox(cdb.pinned, slot.key, "Always show: " .. slot.label,
                "Keep this slot out when the kit is closed. You can also shift-right-click the slot.",
                false, refresh, "pin_" .. slot.key)
        end
    end
    if cfg.PinSettings then cfg.PinSettings(self, S) end
    S.Button("Slot choices", "Reset", "Put every slot back to its starting choice, and every list back in its starting order.", function()
        if InCombatLockdown() then self:Print("That can only change out of combat.") return end
        wipe(cdb.picks)
        wipe(cdb.order)
        self:Refresh(false)
        self:Print("Slot choices reset.")
    end)

    S.Header("Key bindings")
    S.Button("Key bindings", "Open", "Bind each slot, and opening the kit.", function()
        if Settings.KEYBINDINGS_CATEGORY_ID then
            Settings.OpenToCategory(Settings.KEYBINDINGS_CATEGORY_ID)
        else
            self:Print("Open Esc > Options > Keybindings and look for " .. self.name .. ".")
        end
    end)

    Settings.RegisterAddOnCategory(category)
    self.openSettings = function() Settings.OpenToCategory(category:GetID()) end
    self.OnSettingsChanged = function()
        for _, r in ipairs(registered) do
            if r.setting.GetValue and r.setting:GetValue() ~= r.tbl[r.key] then
                pcall(r.setting.SetValue, r.setting, r.tbl[r.key])
            end
        end
    end
end

function Kit:SetupSettings()
    if not (Settings and Settings.RegisterVerticalLayoutCategory and Settings.RegisterAddOnSetting) then return end
    local ok, err = pcall(self.BuildSettings, self)
    if not ok then
        self.openSettings = nil
        self:Print("Settings panel failed to load (" .. tostring(err) .. "). " .. (self.cfg.slash and self.cfg.slash[1] or "") .. " help lists the slash commands.", true)
    end
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------

-- Anything printed while a slash command runs is its answer, so it shows
-- even with "Chat messages" off.
function Kit:Slash(msg)
    self.inSlash = true
    local ok, err = pcall(self.RunSlash, self, msg)
    self.inSlash = nil
    if not ok then error(err, 0) end
end

function Kit:RunSlash(msg)
    local cfg = self.cfg
    local slash = cfg.slash and cfg.slash[1] or ""
    local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    cmd = (cmd or ""):lower()
    if cfg.Slash and cfg.Slash(self, cmd, rest) then return end
    if cmd == "" or cmd == "options" or cmd == "settings" then
        self:OpenSettings()
    elseif cmd == "help" then
        self:Print(slash .. " - settings   " .. slash .. " lock | unlock | show | hide | reset")
        self:Print(slash .. " minimap - show or hide the minimap button")
        self:Print(slash .. " face up | down | left | right - which way the layout points")
        if self.Dock and not cfg.edgesOnly then self:Print(slash .. " dock - dock every kit on the pin   " .. slash .. " flip") end
        for _, line in ipairs(cfg.helpLines or {}) do self:Print(line) end
    elseif InCombatLockdown() then
        self:Print("That can only change out of combat.")
    elseif cmd == "lock" or cmd == "unlock" then
        self.db.locked = (cmd == "lock")
        self:Print(self.db.locked and "Locked." or "Unlocked. Drag the kit to move it.")
        self:SettingsChanged()
    elseif cmd == "show" or cmd == "hide" then
        self:SetShownKit(cmd == "show")
    elseif cmd == "dock" and self.Dock and not cfg.edgesOnly then
        if self.Dock.Active() then
            self.Dock.DockAll(self.key)
            self:Print("Kits docked together on the pin.")
        else
            self:Print("Docking needs another kit installed.")
        end
    elseif cmd == "face" then
        local f = (rest or ""):lower():match("^(%a+)")
        if f and FACE[f] then
            self:SetFacing(f)
        else
            self:Print(slash .. " face up | down | left | right   (now " .. (self.db.facing or "up") .. ")")
        end
    elseif cmd == "flip" and self.Dock and not cfg.edgesOnly then
        self.Dock.Flip()
    elseif cmd == "reset" then
        local d = cfg.defaults and cfg.defaults.point or C.BASE_DEFAULTS.point
        self.db.point = { d[1], d[2], d[3], d[4], "ui" } -- (starting spots are in screen units)
        if self.Dock and self.Dock.Undock then self.Dock.Undock(self.key) end
        self:ApplyPosition()
        self:Print("Kit moved back to its starting spot.")
    elseif cmd == "minimap" then
        self.db.minimapButton = not self.db.minimapButton
        self:ApplyMinimap()
        self:SettingsChanged()
        self:Print("Minimap button " .. (self.db.minimapButton and "shown." or ("hidden. " .. slash .. " minimap brings it back.")))
    else
        self:Print("Unknown command. " .. slash .. " help lists them.")
    end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local BASE_EVENTS = {
    "PLAYER_ENTERING_WORLD", "BAG_UPDATE_DELAYED", "SPELLS_CHANGED", "BAG_UPDATE_COOLDOWN",
    "SPELL_UPDATE_COOLDOWN", "UPDATE_BINDINGS", "ITEM_DATA_LOAD_RESULT", "UI_SCALE_CHANGED",
    "DISPLAY_SIZE_CHANGED", "GLOBAL_MOUSE_DOWN", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
}

function Kit:OnEvent(event, ...)
    local cfg = self.cfg
    if event == "ADDON_LOADED" then
        if ... ~= cfg.addon then return end
        local db = _G[cfg.db] or {}
        local cdb = _G[cfg.charDb] or {}
        _G[cfg.db], _G[cfg.charDb] = db, cdb
        if cfg.defaults then U.ApplyDefaults(db, cfg.defaults) end
        U.ApplyDefaults(db, C.BASE_DEFAULTS)
        if cfg.alwaysHideInCombat then db.hideInCombat = true end
        if cfg.charDefaults then U.ApplyDefaults(cdb, cfg.charDefaults) end
        U.ApplyDefaults(cdb, C.BASE_CHAR)
        self.db, self.cdb = db, cdb
        for _, slot in ipairs(cfg.slots) do
            cdb.pinned[slot.key] = (not slot.noPin and cdb.pinned[slot.key]) and true or false
        end
        self.events:UnregisterEvent("ADDON_LOADED")
        return
    elseif event == "PLAYER_LOGIN" then
        return self:Build()
    end
    if not self.built then return end

    local h = cfg.events and cfg.events[event]
    if h then h(self, ...) end
    local uh = cfg.unitEvents and cfg.unitEvents[event]
    if uh then uh.fn(self, ...) end

    if event == "PLAYER_ENTERING_WORLD" or event == "BAG_UPDATE_DELAYED" or event == "SPELLS_CHANGED" then
        self:Refresh(false)
    elseif event == "BAG_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_COOLDOWN" then
        self:PaintAll()
    elseif event == "UPDATE_BINDINGS" then
        self:UpdateHotkeys()
    elseif event == "ITEM_DATA_LOAD_RESULT" then
        -- Item info arriving (often in bursts at login): one refresh shortly after.
        if self.refreshQueued or not C_Timer then return end
        self.refreshQueued = true
        C_Timer.After(0.5, function()
            self.refreshQueued = false
            self:Refresh(false)
        end)
    elseif event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" then
        self:PaintAll()
        self:ApplyShapes()
    elseif event == "GLOBAL_MOUSE_DOWN" then
        local fly = self.flyOpen
        if fly and fly:IsShown() and not InCombatLockdown() then
            local focus = GetMouseFoci and GetMouseFoci()[1] or (GetMouseFocus and GetMouseFocus())
            local inside = false
            while focus do
                if focus == fly or focus == fly.slotBtn then inside = true break end
                focus = focus.GetParent and focus:GetParent()
            end
            if not inside then fly:Hide() end
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        GameTooltip:Hide()
        if self.db.hideInCombat and not InCombatLockdown() then self.holder:Hide() end
        -- Combat is about to start (still allowed now): flyouts opened from
        -- here on, and any open already, close themselves once the mouse
        -- leaves them, since a click elsewhere can't close them in combat.
        if not InCombatLockdown() then
            -- Anything part-way through hiding hides now (see Fighting): a
            -- slot closing, or the kit fading out as another kit opens.
            self:FinishSlides()
            if self.tucked and self.kit:IsShown() then
                if self.kit.fadeAG then self.kit.fadeAG:Stop() end
                self.kit:Hide()
            end
            self:PushMoveInfo() -- (the button's scale, as it is now)
            if self.grip then self.grip:SetShown(self:CanSecureToggle() or self:CanSecureMove()) end -- (see GRIP_CLICK)
            local delay = tonumber(self.db.flyoutHide) or 0.5
            delay = math.min(2, math.max(0.2, delay))
            self.header:SetAttribute("kchide", delay)
            self.header:SetAttribute("kccombat", true)
            pcall(self.header.Execute, self.header, ([[
                for i = 1, NFLY do
                    local f = FLYOUTS[i]
                    if f:IsShown() then
                        f:RegisterAutoHide(%s)
                        f:AddToAutoHide(FLYSLOTS[i])
                    end
                end
            ]]):format(delay))
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        self.header:SetAttribute("kccombat", false)
        pcall(self.header.Execute, self.header, [[ for i = 1, NFLY do FLYOUTS[i]:UnregisterAutoHide() end ]])
        if self.db.hideInCombat then self.holder:Show() end
        if self.pending then
            self:ApplyPosition()
            self:ApplyCombatHide()
        end
        if self.grip then
            self.grip:Hide()
            self.grip:ClearAllPoints()
            self.grip:SetAllPoints(self.kit)
        end
        self:StopGhost()
        self.combatPress = nil
        self:Refresh(false)
        -- Moved or opened in combat: catch the dock up a frame from now (see
        -- FinishCombatMove), the move first, so the dock lays the kit out
        -- where it was dropped, then where it opened or closed.
        if self.combatDrop or self.combatToggled or self.pinMoved then
            local function After()
                if InCombatLockdown() then return end -- (in a fight again: next time)
                self:FinishCombatMove()
                if self.combatToggled then
                    self.combatToggled = nil
                    local D = self.Dock
                    if D and D.Opening and D.Closed then
                        if self.open then D.Opening(self.key) else D.Closed(self.key) end
                    end
                    self:KeepOnScreen()
                end
            end
            if C_Timer and C_Timer.After then C_Timer.After(0, After) else After() end
        end
    end
end

function Kit:Build()
    local cfg = self.cfg
    self:BuildKit()
    for _, slot in ipairs(cfg.slots) do self:CreateSlot(slot) end
    self.built = true
    self:UpdateHotkeys()
    self:ApplyPosition()
    self:RegisterDock()
    self:ApplyCombatHide()
    self.kit:SetShown(self.db.shown ~= false)
    if cfg.AfterBuild then cfg.AfterBuild(self) end
    self:SetupSettings()
    self:SetupMinimap()

    for _, e in ipairs(BASE_EVENTS) do pcall(self.events.RegisterEvent, self.events, e) end
    for e in pairs(cfg.events or {}) do pcall(self.events.RegisterEvent, self.events, e) end
    for e, u in pairs(cfg.unitEvents or {}) do
        pcall(self.events.RegisterUnitEvent, self.events, e, unpack(u.units))
    end

    -- Twice a second: anything the kit watches that raises no event.
    if cfg.Tick then
        local ticker = CreateFrame("Frame", nil, self.holder)
        ticker:SetScript("OnUpdate", function(f, elapsed)
            f.acc = (f.acc or 0) + elapsed
            if f.acc < 0.5 then return end
            f.acc = 0
            cfg.Tick(self)
        end)
    end
    self:Refresh(false)
end
