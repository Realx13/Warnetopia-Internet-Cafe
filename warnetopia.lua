--[[
    Warnetopia — Auto Buy Rare Items
    UI: LinoriaLib
    Credit : Realx
--]]

-- ─── LOAD LINORIA ─────────────────────────────────────────────────────────────
local repo = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'

local Library    = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager  = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()

-- ─── SERVICES ─────────────────────────────────────────────────────────────────
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer       = Players.LocalPlayer

-- ─── REMOTES ──────────────────────────────────────────────────────────────────
local Remotes  = ReplicatedStorage:WaitForChild("Remotes", 10)
local Action   = Remotes:WaitForChild("Action", 10)
local Snapshot = Remotes:WaitForChild("Snapshot", 10)

-- ─── CATALOG LOOKUP ───────────────────────────────────────────────────────────
local Catalog = require(ReplicatedStorage.Shared.Data.Catalog)
local BY_ID   = {}
for _, item in ipairs(Catalog.ITEMS) do
    BY_ID[item.id] = item
end

-- ─── CONFIG (driven by toggles) ───────────────────────────────────────────────
local cfg = {
    -- master
    autoBuyEnabled  = false,
    autoOpenEnabled = false,
    autoDayEnabled  = false,

    -- store toggles
    store_computer  = true,
    store_furniture = true,
    store_decor     = true,
    store_kitchen   = false,
    store_minimart  = false,

    -- filters
    minTier         = 3,
    rarityLangka    = true,   -- langka
    raritySangat    = true,   -- sangat_langka

    -- auto-open config
    reopenDelay     = 6,
    continueDelay   = 1.5,
}

-- ─── STATE ────────────────────────────────────────────────────────────────────
local boughtThisSnap = {}
local lastStatus     = nil
local reopenPending  = false
local continuePending= false

-- ─── HELPER: Fire remote ──────────────────────────────────────────────────────
local function fireAction(action, data)
    pcall(function() Action:FireServer(action, data or {}) end)
end

-- ─── HELPER: Get warnet status dari UI ───────────────────────────────────────
local function getStatus()
    local gui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not gui then return nil end
    local ok, card = pcall(function()
        return gui.WarnetopiaUI.Root.TL.TopRow.CafeCard
    end)
    if not ok or not card then return nil end
    for _, d in ipairs(card:GetDescendants()) do
        if d:IsA("TextLabel") then
            local t = d.Text:upper()
            if t == "BUKA" or t == "OPEN" then return "BUKA"
            elseif t == "TUTUP" or t == "CLOSED" then return "TUTUP" end
        end
    end
    return nil
end

-- ─── HELPER: Cek DayReport button ────────────────────────────────────────────
local function isDayReportOpen()
    local gui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not gui then return false end
    for _, btn in ipairs(gui:GetDescendants()) do
        if btn:IsA("TextButton") and (btn.Text or ""):find("Lanjut ke Hari") then
            return true
        end
    end
    return false
end

-- ─── AUTO OPEN LOOP ───────────────────────────────────────────────────────────
local RunService = game:GetService("RunService")
local checkTimer = 0

RunService.Heartbeat:Connect(function(dt)
    if not cfg.autoOpenEnabled and not cfg.autoDayEnabled then
        lastStatus = nil
        return
    end

    checkTimer = checkTimer + dt
    if checkTimer < 2 then return end
    checkTimer = 0

    -- Auto-continue day
    if cfg.autoDayEnabled and not continuePending and isDayReportOpen() then
        continuePending = true
        task.delay(cfg.continueDelay, function()
            if cfg.autoDayEnabled then
                fireAction("dayContinue", {})
                print("[Auto] 📅 dayContinue fired!")
                task.delay(cfg.reopenDelay, function()
                    if cfg.autoOpenEnabled and getStatus() == "TUTUP" then
                        fireAction("setOpen", { open = true })
                        print("[Auto] 🌅 Warnet dibuka setelah hari baru!")
                    end
                end)
            end
            continuePending = false
        end)
        return
    end

    -- Auto-open
    if not cfg.autoOpenEnabled then lastStatus = nil return end

    local status = getStatus()
    if not status then return end

    if lastStatus == "BUKA" and status == "TUTUP" and not reopenPending then
        reopenPending = true
        task.delay(cfg.reopenDelay, function()
            if cfg.autoOpenEnabled and getStatus() == "TUTUP" then
                fireAction("setOpen", { open = true })
                print("[Auto] ✅ Warnet dibuka otomatis!")
            end
            reopenPending = false
        end)
    end

    if status == "TUTUP" and lastStatus == nil and not reopenPending then
        reopenPending = true
        task.delay(1, function()
            if cfg.autoOpenEnabled and getStatus() == "TUTUP" then
                fireAction("setOpen", { open = true })
            end
            reopenPending = false
        end)
    end

    lastStatus = status
end)

-- ─── AUTO BUY LOGIC ───────────────────────────────────────────────────────────
local function itemMatches(item)
    if not item or not item.town then return false end
    local r = item.rarity or "biasa"
    local wantLangka  = cfg.rarityLangka  and r == "langka"
    local wantSangat  = cfg.raritySangat  and r == "sangat_langka"
    if not wantLangka and not wantSangat then return false end
    if cfg.minTier and cfg.minTier > 0 then
        local tier = tonumber(item.tier)
        if not tier or tier < cfg.minTier then return false end
    end
    return true
end

local STORE_CFG_MAP = {
    computer  = "store_computer",
    furniture = "store_furniture",
    decor     = "store_decor",
    kitchen   = "store_kitchen",
    minimart  = "store_minimart",
}

local function processSnap(snap)
    if not cfg.autoBuyEnabled then return end
    if not snap or not snap.shops then return end
    boughtThisSnap = {}

    for storeId, shelf in pairs(snap.shops.shelves or {}) do
        local cfgKey = STORE_CFG_MAP[storeId]
        if not cfgKey or not cfg[cfgKey] then continue end

        for itemId, qty in pairs(shelf) do
            if qty and qty > 0 then
                local item = BY_ID[itemId]
                if itemMatches(item) and not boughtThisSnap[itemId] then
                    boughtThisSnap[itemId] = true
                    print(("[AutoBuy] 🛒 %s/%s | Tier%s | %s | qty:%d"):format(
                        storeId, itemId,
                        tostring(item.tier or "?"),
                        tostring(item.rarity),
                        qty
                    ))
                    task.delay(0.3, function()
                        if cfg.autoBuyEnabled then
                            fireAction("storeBuy", { store = storeId, item = itemId })
                            print("[AutoBuy] ✅ Dibeli: " .. itemId)
                        end
                    end)
                end
            end
        end
    end
end

Snapshot.OnClientEvent:Connect(function(snap)
    task.spawn(processSnap, snap)
end)

-- ─── BUILD LINORIA UI ─────────────────────────────────────────────────────────
local Window = Library:CreateWindow({
    Title   = 'Warnetopia Scripts',
    Center  = true,
    AutoShow= true,
})

-- ── TAB 1: Auto Buy ───────────────────────────────────────────────────────────
local BuyTab  = Window:AddTab('Auto Buy')
local BuyBox  = BuyTab:AddLeftGroupbox('⚙️ Pengaturan')

BuyBox:AddToggle('autoBuyEnabled', {
    Text    = 'Auto Buy ON/OFF',
    Default = false,
    Tooltip = 'Aktifkan auto beli item langka dari toko kota',
    Callback = function(val) cfg.autoBuyEnabled = val end,
})

BuyBox:AddSlider('minTier', {
    Text    = 'Minimum Tier',
    Min     = 1,
    Max     = 4,
    Default = 3,
    Rounding= 0,
    Tooltip = 'Hanya beli item dengan tier >= ini',
    Callback = function(val) cfg.minTier = val end,
})

-- Rarity
local RarityBox = BuyTab:AddLeftGroupbox('✨ Rarity Filter')

RarityBox:AddToggle('rarityLangka', {
    Text    = 'Langka (★)',
    Default = true,
    Callback = function(val) cfg.rarityLangka = val end,
})

RarityBox:AddToggle('raritySangat', {
    Text    = 'Sangat Langka (★★)',
    Default = true,
    Callback = function(val) cfg.raritySangat = val end,
})

-- Toko
local TokoBox = BuyTab:AddRightGroupbox('🏪 Toko')

TokoBox:AddToggle('store_computer', {
    Text    = '💻 Toko Komputer Jaya',
    Default = true,
    Callback = function(val) cfg.store_computer = val end,
})

TokoBox:AddToggle('store_furniture', {
    Text    = '🪑 Mebel Jati',
    Default = true,
    Callback = function(val) cfg.store_furniture = val end,
})

TokoBox:AddToggle('store_decor', {
    Text    = '🌿 Galeri Dekorasi',
    Default = true,
    Callback = function(val) cfg.store_decor = val end,
})

TokoBox:AddToggle('store_kitchen', {
    Text    = '☕ Toko Alat Kafe',
    Default = false,
    Callback = function(val) cfg.store_kitchen = val end,
})

TokoBox:AddToggle('store_minimart', {
    Text    = '🛒 Minimart 24',
    Default = false,
    Callback = function(val) cfg.store_minimart = val end,
})

-- ── TAB 2: Auto Open & Day ────────────────────────────────────────────────────
local OpenTab = Window:AddTab('Auto Open')
local OpenBox = OpenTab:AddLeftGroupbox('🏪 Warnet')

OpenBox:AddToggle('autoOpenEnabled', {
    Text    = 'Auto Buka Warnet',
    Default = false,
    Tooltip = 'Otomatis buka warnet kalau tiba-tiba TUTUP',
    Callback = function(val)
        cfg.autoOpenEnabled = val
        lastStatus = nil
        if val then
            local s = getStatus()
            if s == "TUTUP" then
                task.delay(1, function()
                    fireAction("setOpen", { open = true })
                end)
            end
        end
    end,
})

OpenBox:AddToggle('autoDayEnabled', {
    Text    = 'Auto Lanjut Hari',
    Default = false,
    Tooltip = 'Otomatis pencet "Lanjut ke Hari X" saat popup muncul',
    Callback = function(val) cfg.autoDayEnabled = val end,
})

local DelayBox = OpenTab:AddLeftGroupbox('⏱️ Delay')

DelayBox:AddSlider('reopenDelay', {
    Text     = 'Reopen Delay (detik)',
    Min      = 1,
    Max      = 15,
    Default  = 6,
    Rounding = 0,
    Callback = function(val) cfg.reopenDelay = val end,
})

DelayBox:AddSlider('continueDelay', {
    Text     = 'Continue Delay (detik)',
    Min      = 1,
    Max      = 10,
    Default  = 2,
    Rounding = 0,
    Callback = function(val) cfg.continueDelay = val end,
})

-- ── TAB 3: Settings ───────────────────────────────────────────────────────────
local SettingsTab = Window:AddTab('Settings')
local SettingsBox = SettingsTab:AddLeftGroupbox('Theme')
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
ThemeManager:ApplyToGroupbox(SettingsBox)
SaveManager:SetFolder('WarnetopiaScripts')
SaveManager:SetIgnoreIndexes({'minTier', 'reopenDelay', 'continueDelay'})

local SaveBox = SettingsTab:AddRightGroupbox('Config')
SaveManager:BuildConfigSection(SaveBox)

-- ── KEYBIND toggle UI ─────────────────────────────────────────────────────────
Library:SetWatermark('Warnetopia Hub 🖤')
Library.Toggled = true

print('[Hub] 🖤 Warnetopia LinoriaLib UI loaded! Tekan RightShift buat hide/show.')
