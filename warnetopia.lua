--[[
    Warnetopia — Auto Buy Rare Items (With Auto-TP, Anti-Spam & Auto Day Click)
    UI: LinoriaLib
    Credit : Realx
--]]

-- ─── LOAD LINORIA ─────────────────────────────────────────────────────────────
local repo = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'

local Library      = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()

-- ─── SERVICES ─────────────────────────────────────────────────────────────────
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
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

-- ─── TELEPORT LOCATIONS ───────────────────────────────────────────────────────
local STORE_LOCATIONS = {
    computer  = CFrame.new(-135.6, 2.7, -4.9),
    furniture = CFrame.new(-182.8, 2.7, -6.3),
    decor     = CFrame.new(-26.1, 2.7, -42.2),
    kitchen   = CFrame.new(-187.6, 2.7, -44.1),
    minimart  = CFrame.new(91.7, 2.7, -5.2),
}

-- ─── CONFIG ───────────────────────────────────────────────────────────────────
local cfg = {
    autoBuyEnabled  = false,
    autoOpenEnabled = false,
    autoDayEnabled  = false,

    store_computer  = true,
    store_furniture = true,
    store_decor     = true,
    store_kitchen   = false,
    store_minimart  = false,

    minTier         = 3,
    rarityLangka    = true,
    raritySangat    = true,

    reopenDelay     = 6,
    continueDelay   = 1.5,
}

-- ─── STATE ────────────────────────────────────────────────────────────────────
local lastStatus      = nil
local reopenPending   = false
local continuePending = false
local isBuying        = false
local lastBuyCooldown = 0

-- ─── HELPER: Fire remote & HRP ────────────────────────────────────────────────
local function fireAction(action, data)
    pcall(function() Action:FireServer(action, data or {}) end)
end

local function getHRP()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
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

-- ─── HELPER: Cari tombol DayReport ───────────────────────────────────────────
local function getDayReportButton()
    local gui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not gui then return nil end

    for _, obj in ipairs(gui:GetDescendants()) do
        if (obj:IsA("TextButton") or obj:IsA("TextLabel")) and (obj.Text or ""):find("Lanjut ke Hari") then
            local btn = obj:IsA("GuiButton") and obj or obj:FindFirstAncestorWhichIsA("GuiButton")
            if btn and btn.Visible then
                local isAllVisible = true
                local curr = btn.Parent
                while curr and curr:IsA("GuiObject") do
                    if not curr.Visible then
                        isAllVisible = false
                        break
                    end
                    curr = curr.Parent
                end
                if isAllVisible then
                    return btn
                end
            end
        end
    end
    return nil
end

-- ─── AUTO OPEN LOOP ───────────────────────────────────────────────────────────
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
    local dayBtn = cfg.autoDayEnabled and getDayReportButton() or nil
    if dayBtn and not continuePending then
        continuePending = true
        task.delay(cfg.continueDelay, function()
            local btn = getDayReportButton()
            if cfg.autoDayEnabled and btn then
                if firesignal then
                    pcall(function() firesignal(btn.MouseButton1Click) end)
                    pcall(function() firesignal(btn.Activated) end)
                end
                fireAction("dayContinue", {})
                print("[Auto] 📅 Tombol Lanjut Hari diklik!")

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
    if not cfg.autoOpenEnabled then
        lastStatus = nil
        return
    end

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

-- ─── AUTO BUY LOGIC (DENGAN AUTO-TP & COOLDOWN) ───────────────────────────────
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
    if not cfg.autoBuyEnabled or isBuying then return end
    if os.clock() - lastBuyCooldown < 4 then return end
    if not snap or not snap.shops then return end

    local purchaseQueue = {}
    for storeId, shelf in pairs(snap.shops.shelves or {}) do
        local cfgKey = STORE_CFG_MAP[storeId]
        if cfgKey and cfg[cfgKey] then
            for itemId, qty in pairs(shelf) do
                if qty and qty > 0 then
                    local item = BY_ID[itemId]
                    if itemMatches(item) then
                        purchaseQueue[storeId] = purchaseQueue[storeId] or {}
                        table.insert(purchaseQueue[storeId], { id = itemId, qty = qty })
                    end
                end
            end
        end
    end

    if next(purchaseQueue) == nil then return end

    local hrp = getHRP()
    if not hrp then return end

    isBuying = true
    lastBuyCooldown = os.clock()
    local originalCFrame = hrp.CFrame

    for storeId, items in pairs(purchaseQueue) do
        local targetCFrame = STORE_LOCATIONS[storeId]
        if targetCFrame then
            hrp.CFrame = targetCFrame
            task.wait(0.45)

            for _, itemData in ipairs(items) do
                if not cfg.autoBuyEnabled then break end
                for i = 1, itemData.qty do
                    fireAction("storeBuy", { store = storeId, item = itemData.id })
                    print("[AutoBuy] ✅ Dibeli jarak jauh: " .. itemData.id)
                    task.wait(0.25)
                end
            end
        end
    end

    task.wait(0.2)
    if getHRP() then
        getHRP().CFrame = originalCFrame
    end
    isBuying = false
end

Snapshot.OnClientEvent:Connect(function(snap)
    task.spawn(processSnap, snap)
end)

-- ─── BUILD LINORIA UI ─────────────────────────────────────────────────────────
local Window = Library:CreateWindow({
    Title    = 'Warnetopia Scripts',
    Center   = true,
    AutoShow = true,
})

-- ── TAB 1: Auto Buy ───────────────────────────────────────────────────────────
local BuyTab  = Window:AddTab('Auto Buy')
local BuyBox  = BuyTab:AddLeftGroupbox('⚙️ Pengaturan')

BuyBox:AddToggle('autoBuyEnabled', {
    Text     = 'Auto Buy ON/OFF',
    Default  = false,
    Tooltip  = 'Aktifkan auto beli item langka dari toko kota',
    Callback = function(val) cfg.autoBuyEnabled = val end,
})

BuyBox:AddSlider('minTier', {
    Text     = 'Minimum Tier',
    Min      = 1,
    Max      = 4,
    Default  = 3,
    Rounding = 0,
    Tooltip  = 'Hanya beli item dengan tier >= ini',
    Callback = function(val) cfg.minTier = val end,
})

local RarityBox = BuyTab:AddLeftGroupbox('✨ Rarity Filter')

RarityBox:AddToggle('rarityLangka', {
    Text     = 'Langka (★)',
    Default  = true,
    Callback = function(val) cfg.rarityLangka = val end,
})

RarityBox:AddToggle('raritySangat', {
    Text     = 'Sangat Langka (★★)',
    Default  = true,
    Callback = function(val) cfg.raritySangat = val end,
})

local TokoBox = BuyTab:AddRightGroupbox('🏪 Toko')

TokoBox:AddToggle('store_computer', {
    Text     = '💻 Toko Komputer Jaya',
    Default  = true,
    Callback = function(val) cfg.store_computer = val end,
})

TokoBox:AddToggle('store_furniture', {
    Text     = '🪑 Mebel Jati',
    Default  = true,
    Callback = function(val) cfg.store_furniture = val end,
})

TokoBox:AddToggle('store_decor', {
    Text     = '🌿 Galeri Dekorasi',
    Default  = true,
    Callback = function(val) cfg.store_decor = val end,
})

TokoBox:AddToggle('store_kitchen', {
    Text     = '☕ Toko Alat Kafe',
    Default  = false,
    Callback = function(val) cfg.store_kitchen = val end,
})

TokoBox:AddToggle('store_minimart', {
    Text     = '🛒 Minimart 24',
    Default  = false,
    Callback = function(val) cfg.store_minimart = val end,
})

-- ── TAB 2: Auto Open & Day ────────────────────────────────────────────────────
local OpenTab = Window:AddTab('Auto Open')
local OpenBox = OpenTab:AddLeftGroupbox('🏪 Warnet')

OpenBox:AddToggle('autoOpenEnabled', {
    Text     = 'Auto Buka Warnet',
    Default  = false,
    Tooltip  = 'Otomatis buka warnet kalau tiba-tiba TUTUP',
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
    Text     = 'Auto Lanjut Hari',
    Default  = false,
    Tooltip  = 'Otomatis pencet "Lanjut ke Hari X" saat popup muncul',
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
ThemeManager:ApplyToGroupbox(SettingsBox)

-- ── KEYBIND toggle UI ─────────────────────────────────────────────────────────
Library:SetWatermark('Warnetopia Hub 🖤')
Library.Toggled = true

print('[Hub] 🖤 Warnetopia LinoriaLib UI loaded! Tekan RightShift buat hide/show.')
