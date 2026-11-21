--[[
    Warnetopia — Auto Buy, All Stores Manual Buy, Restock Timer, WalkSpeed, Anti AFK & Discord Webhook
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
local VirtualUser       = game:GetService("VirtualUser")
local HttpService       = game:GetService("HttpService")
local LocalPlayer       = Players.LocalPlayer

-- ─── HTTP REQUEST FUNCTION (MULTI-EXECUTOR) ───────────────────────────────────
local httpRequest = (syn and syn.request) or (http and http.request) or http_request or request

-- ─── REMOTES ──────────────────────────────────────────────────────────────────
local Remotes  = ReplicatedStorage:WaitForChild("Remotes", 10)
local Action   = Remotes:WaitForChild("Action", 10)
local Snapshot = Remotes:WaitForChild("Snapshot", 10)

-- ─── CATALOG LOOKUP (BY ID & BY NAME) ─────────────────────────────────────────
local Catalog = require(ReplicatedStorage.Shared.Data.Catalog)
local BY_ID   = {}
local BY_NAME = {}
for _, item in ipairs(Catalog.ITEMS) do
    BY_ID[item.id] = item
    if item.name then
        BY_NAME[item.name:lower()] = item
    end
end

-- ─── TELEPORT LOCATIONS & STORE INFO ──────────────────────────────────────────
local STORE_LOCATIONS = {
    computer  = CFrame.new(-135.6, 2.7, -4.9),
    furniture = CFrame.new(-182.8, 2.7, -6.3),
    decor     = CFrame.new(-26.1, 2.7, -42.2),
    kitchen   = CFrame.new(-187.6, 2.7, -44.1),
    minimart  = CFrame.new(91.7, 2.7, -5.2),
}

local STORE_DISPLAY_TO_ID = {
    ["💻 Toko Komputer Jaya"] = "computer",
    ["🪑 Mebel Jati"]         = "furniture",
    ["🌿 Galeri Dekorasi"]    = "decor",
    ["☕ Toko Alat Kafe"]     = "kitchen",
    ["🛒 Minimart 24"]        = "minimart",
}

local STORE_ID_TO_NAME = {
    computer  = "Toko Komputer Jaya",
    furniture = "Mebel Jati",
    decor     = "Galeri Dekorasi",
    kitchen   = "Toko Alat Kafe",
    minimart  = "Minimart 24",
}

local UI_TITLE_TO_STORE_ID = {
    ["Toko Komputer Jaya"] = "computer",
    ["Mebel Jati"]         = "furniture",
    ["Galeri Dekorasi"]    = "decor",
    ["Toko Alat Kafe"]     = "kitchen",
    ["Minimart 24"]        = "minimart",
}

local MAX_SLOTS = 15

-- ─── CONFIG ───────────────────────────────────────────────────────────────────
local cfg = {
    autoBuyEnabled      = false,
    autoMinimartEnabled = false,
    autoOpenEnabled     = false,
    autoDayEnabled      = false,

    walkSpeedEnabled    = false,
    walkSpeedValue      = 32,
    antiAfkEnabled      = true,

    -- Webhook config
    webhookUrl          = "", -- Bisa diisi langsung di sini atau lewat UI Settings
    webhookEnabled      = false,

    store_computer      = true,
    store_furniture     = true,
    store_decor         = true,

    minTier             = 3,
    rarityLangka        = true,
    raritySangat        = true,

    reopenDelay         = 6,
    continueDelay       = 1.5,
}

-- ─── STATE ────────────────────────────────────────────────────────────────────
local lastStatus       = nil
local reopenPending    = false
local continuePending  = false
local isBuying         = false
local lastBuyCooldown  = 0
local latestSnap       = nil
local restockEndClock  = nil
local discountPercent  = 0

local selectedStoreId  = "computer"
local storeOrderedUI   = {}
local activeSlotItems  = {}

-- ─── WEBHOOK SENDER ───────────────────────────────────────────────────────────
local function sendWebhook(title, description, colorHex)
    if not httpRequest then return false, "Executor tidak mendukung HTTP request" end
    local url = (cfg.webhookUrl or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if url == "" or not url:find("^https://") then
        return false, "URL Webhook kosong atau tidak valid"
    end

    local payload = {
        username = "Warnetopia Notifier",
        embeds = {{
            title = title,
            description = description,
            color = colorHex or 3447003,
            footer = {
                text = "Player: " .. LocalPlayer.Name .. " • " .. os.date("%H:%M:%S")
            }
        }}
    }

    local ok, res = pcall(function()
        return httpRequest({
            Url = url,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(payload)
        })
    end)

    if ok and res and (res.StatusCode == 200 or res.StatusCode == 204) then
        return true, "Terkirim!"
    end
    return false, "Gagal mengirim ke Discord"
end

-- ─── ANTI AFK LISTENER ────────────────────────────────────────────────────────
LocalPlayer.Idled:Connect(function()
    if cfg.antiAfkEnabled then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end
end)

-- ─── HELPER: Format Harga Singkat ─────────────────────────────────────────────
local function formatShortPrice(num)
    if not num or type(num) ~= "number" then return "" end
    if num >= 1000000 then
        local jt = num / 1000000
        return (jt % 1 == 0) and string.format("$%dJt", jt) or string.format("$%.2fJt", jt):gsub("0Jt$", "Jt")
    elseif num >= 1000 then
        local k = num / 1000
        return (k % 1 == 0) and string.format("$%dK", k) or string.format("$%.1fK", k)
    end
    return "$" .. tostring(num)
end

local function parsePriceText(txt)
    if not txt then return nil end
    local digits = txt:gsub("[^%d]", "")
    return tonumber(digits)
end

-- ─── HELPER: Ubah teks, ukuran & visibilitas tombol LinoriaLib ───────────────
local function setButtonState(btnObj, newText, isVisible)
    if not btnObj then return end
    pcall(function()
        local container = btnObj.Container
        if container and container:IsA("GuiObject") then
            container.Visible = isVisible
            container.Size = UDim2.new(1, 0, 0, 24)
            for _, child in ipairs(container:GetChildren()) do
                if child:IsA("GuiButton") or child:IsA("Frame") then
                    child.Size = UDim2.new(1, 0, 1, 0)
                end
            end
        end

        local lbl = btnObj.Label
        if not lbl and container then
            for _, d in ipairs(container:GetDescendants()) do
                if d:IsA("TextLabel") then
                    lbl = d
                    break
                end
            end
        end

        if lbl and lbl:IsA("TextLabel") then
            lbl.Text = newText
            lbl.TextScaled = true
            local constraint = lbl:FindFirstChildOfClass("UITextSizeConstraint")
            if not constraint then
                constraint = Instance.new("UITextSizeConstraint")
                constraint.Parent = lbl
            end
            constraint.MaxTextSize = 15
            constraint.MinTextSize = 12
        end
    end)
end

-- ─── HELPER: Fire remote, HRP & Humanoid ──────────────────────────────────────
local function fireAction(action, data)
    pcall(function() Action:FireServer(action, data or {}) end)
end

local function getHRP()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
    local char = LocalPlayer.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

-- ─── HELPER: Beli 1 Item Manual dari Tombol UI ────────────────────────────────
local function buySingleItemManual(storeId, itemId, priceStr)
    if isBuying then
        Library:Notify("Sedang proses beli lain, tunggu sebentar...", 2)
        return
    end

    local hrp = getHRP()
    local targetCFrame = STORE_LOCATIONS[storeId]
    if not hrp or not targetCFrame then return end

    isBuying = true
    local originalCFrame = hrp.CFrame
    local itemInfo = BY_ID[itemId]
    local itemName = (itemInfo and itemInfo.name) or itemId

    hrp.CFrame = targetCFrame
    task.wait(0.4)
    fireAction("storeBuy", { store = storeId, item = itemId })
    local infoHarga = (priceStr and priceStr ~= "") and (" (" .. priceStr .. ")") or ""
    Library:Notify("✅ Membeli: " .. itemName .. infoHarga, 2.5)
    task.wait(0.25)

    if getHRP() then
        getHRP().CFrame = originalCFrame
    end
    isBuying = false
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

-- ─── BUILD LINORIA UI ─────────────────────────────────────────────────────────
local Window = Library:CreateWindow({
    Title    = 'Warnetopia Scripts',
    Center   = true,
    AutoShow = true,
    Size     = UDim2.fromOffset(780, 650),
})

-- ── TAB 1: Auto Buy ───────────────────────────────────────────────────────────
local BuyTab  = Window:AddTab('Auto Buy')
local BuyBox  = BuyTab:AddLeftGroupbox('⚙️ Auto Buy Rare')

BuyBox:AddToggle('autoBuyEnabled', {
    Text     = 'Auto Buy Rare ON/OFF',
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
    Tooltip  = 'Hanya beli item bertier dengan tier >= ini',
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

local TokoBox = BuyTab:AddRightGroupbox('🏪 Toko Rare Items')

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

local MinimartBox = BuyTab:AddRightGroupbox('🛒 Minimart 24')

MinimartBox:AddToggle('autoMinimartEnabled', {
    Text     = 'Auto Restock Minimart',
    Default  = false,
    Tooltip  = 'Otomatis borong semua stok Snack, Mie, Kopi, dll di Minimart 24',
    Callback = function(val) cfg.autoMinimartEnabled = val end,
})

-- ── TAB 2: Toko Kota ──────────────────────────────────────────────────────────
local CafeTab   = Window:AddTab('Toko Kota')
local TimerBox  = CafeTab:AddLeftGroupbox('⏰ Jadwal Restock Toko')

local RestockTimerLabel = TimerBox:AddLabel('Stok baru dalam: Buka 1x toko dulu')
TimerBox:AddDivider()
TimerBox:AddLabel('Semua toko kota reset bersamaan', true)
TimerBox:AddLabel('saat timer menyentuh 00:00.', true)
TimerBox:AddDivider()
TimerBox:AddButton({
    Text = '🚀 TP ke Toko Terpilih',
    Func = function()
        local hrp = getHRP()
        local target = STORE_LOCATIONS[selectedStoreId]
        if hrp and target then
            hrp.CFrame = target
        end
    end,
    Tooltip = 'Teleport manual ke toko yang sedang dipilih di sebelah kanan',
})

local ManualShopBox = CafeTab:AddRightGroupbox('🛍️ Beli Manual (Semua Toko)')

local StoreSlotButtons = {}
local function buildButtonLabel(name, qty, priceStr, discPct)
    local statusStr = (qty > 0) and ("x" .. qty) or "HABIS"
    local discTag   = (discPct and discPct > 0) and string.format(" (-%d%%)", discPct) or ""
    local pricePart = (priceStr and priceStr ~= "") and (" • " .. priceStr .. discTag) or discTag
    return string.format("%s (%s)%s", name, statusStr, pricePart)
end

local function refreshManualStoreSlots()
    table.clear(activeSlotItems)
    local orderedList = storeOrderedUI[selectedStoreId]
    local snapShelf   = latestSnap and latestSnap.shops and latestSnap.shops.shelves and latestSnap.shops.shelves[selectedStoreId]
    local mult        = (discountPercent > 0) and (1 - (discountPercent / 100)) or 1

    local finalItems = {}
    local seenIds = {}

    if orderedList and #orderedList > 0 then
        for _, entry in ipairs(orderedList) do
            local liveQty = (entry.id and snapShelf and snapShelf[entry.id] ~= nil) and snapShelf[entry.id] or entry.qty
            entry.qty = liveQty

            local itemDisc = (discountPercent > 0) and discountPercent or (entry.discPct or 0)
            local finalPriceStr = entry.priceStr

            if entry.basePrice and itemDisc > 0 then
                finalPriceStr = formatShortPrice(math.floor(entry.basePrice * (1 - (itemDisc / 100)) + 0.5))
            end

            table.insert(finalItems, {
                id = entry.id,
                name = entry.name,
                qty = liveQty,
                priceStr = finalPriceStr,
                discPct = itemDisc,
            })

            if entry.id then
                seenIds[entry.id] = true
            end
        end
    end

    if snapShelf then
        local extraIds = {}
        for itemId, _ in pairs(snapShelf) do
            if not seenIds[itemId] then
                table.insert(extraIds, itemId)
            end
        end
        table.sort(extraIds)

        for _, itemId in ipairs(extraIds) do
            local qty = snapShelf[itemId] or 0
            local itemInfo = BY_ID[itemId]
            local displayName = (itemInfo and itemInfo.name) or itemId
            local basePrice = itemInfo and itemInfo.price
            local finalPriceStr = basePrice and formatShortPrice(math.floor(basePrice * mult + 0.5)) or ""

            table.insert(finalItems, {
                id = itemId,
                name = displayName,
                qty = qty,
                priceStr = finalPriceStr,
                discPct = discountPercent,
            })
        end
    end

    if #finalItems > 0 then
        for i = 1, MAX_SLOTS do
            local item = finalItems[i]
            if item then
                activeSlotItems[i] = item
                local btnText = buildButtonLabel(item.name, item.qty, item.priceStr, item.discPct)
                setButtonState(StoreSlotButtons[i], btnText, true)
            else
                setButtonState(StoreSlotButtons[i], "", false)
            end
        end
    else
        for i = 1, MAX_SLOTS do
            if i <= 4 then
                setButtonState(StoreSlotButtons[i], string.format("Slot %d: Buka toko / tunggu reset", i), true)
            else
                setButtonState(StoreSlotButtons[i], "", false)
            end
        end
    end
end

ManualShopBox:AddDropdown('selectedManualStore', {
    Values   = {
        '💻 Toko Komputer Jaya',
        '🪑 Mebel Jati',
        '🌿 Galeri Dekorasi',
        '☕ Toko Alat Kafe',
        '🛒 Minimart 24',
    },
    Default  = 1,
    Multi    = false,
    Text     = 'Pilih Toko:',
    Tooltip  = 'Pilih toko untuk melihat semua isi rak, harga diskon & beli satuan',
    Callback = function(val)
        selectedStoreId = STORE_DISPLAY_TO_ID[val] or "computer"
        refreshManualStoreSlots()
    end,
})

ManualShopBox:AddDivider()

for i = 1, MAX_SLOTS do
    StoreSlotButtons[i] = ManualShopBox:AddButton({
        Text = ('Slot %d: Menunggu data...'):format(i),
        Func = function()
            local slotData = activeSlotItems[i]
            if slotData and slotData.id then
                if slotData.qty and slotData.qty <= 0 then
                    Library:Notify("❌ Stok " .. slotData.name .. " sudah HABIS!", 2)
                else
                    task.spawn(buySingleItemManual, selectedStoreId, slotData.id, slotData.priceStr)
                end
            else
                Library:Notify("Data toko belum terbaca! Buka UI tokonya 1x atau tunggu reset.", 2.5)
            end
        end,
        Tooltip = 'Klik untuk teleport & beli item ini 1x',
    })
    if i > 4 then
        setButtonState(StoreSlotButtons[i], "", false)
    else
        setButtonState(StoreSlotButtons[i], ('Slot %d: Menunggu data...'):format(i), true)
    end
end

-- ── TAB 3: Auto Open & Player ─────────────────────────────────────────────────
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

local PlayerBox = OpenTab:AddRightGroupbox('🏃 Player & AFK')

PlayerBox:AddToggle('antiAfkEnabled', {
    Text     = '🛡️ Anti AFK (Anti Kick 20m)',
    Default  = true,
    Tooltip  = 'Mencegah disconnect otomatis dari Roblox saat ditinggal AFK',
    Callback = function(val) cfg.antiAfkEnabled = val end,
})

PlayerBox:AddDivider()

PlayerBox:AddToggle('walkSpeedEnabled', {
    Text     = 'Custom WalkSpeed',
    Default  = false,
    Tooltip  = 'Aktifkan kecepatan lari custom',
    Callback = function(val)
        cfg.walkSpeedEnabled = val
        local hum = getHumanoid()
        if hum then
            hum.WalkSpeed = val and cfg.walkSpeedValue or 16
        end
    end,
})

PlayerBox:AddSlider('walkSpeedValue', {
    Text     = 'WalkSpeed',
    Min      = 16,
    Max      = 150,
    Default  = 32,
    Rounding = 0,
    Tooltip  = 'Atur kecepatan jalan karakter (default normal: 16)',
    Callback = function(val)
        cfg.walkSpeedValue = val
        if cfg.walkSpeedEnabled then
            local hum = getHumanoid()
            if hum then hum.WalkSpeed = val end
        end
    end,
})

-- ── TAB 4: Settings & Discord Webhook ─────────────────────────────────────────
local SettingsTab = Window:AddTab('Settings')
local SettingsBox = SettingsTab:AddLeftGroupbox('Theme')
ThemeManager:SetLibrary(Library)
ThemeManager:ApplyToGroupbox(SettingsBox)

local WebhookBox = SettingsTab:AddRightGroupbox('🔔 Discord Webhook')

WebhookBox:AddToggle('webhookEnabled', {
    Text     = 'Kirim Notif Auto Buy',
    Default  = false,
    Tooltip  = 'Kirim laporan ke Discord setiap kali Auto Buy membeli item',
    Callback = function(val) cfg.webhookEnabled = val end,
})

WebhookBox:AddInput('webhookUrlInput', {
    Default     = '',
    Numeric     = false,
    Finished    = false,
    Text        = 'Webhook URL',
    Tooltip     = 'Tempel URL Discord Webhook kamu di sini',
    Placeholder = 'https://discord.com/api/webhooks/...',
    Callback    = function(val) cfg.webhookUrl = val end,
})

WebhookBox:AddButton({
    Text = '📨 Test Kirim Webhook',
    Func = function()
        task.spawn(function()
            local ok, msg = sendWebhook(
                "✅ Webhook Terhubung!",
                "Notifikasi **Warnetopia Hub** siap mengirim laporan belanja otomatis.",
                5763719 -- Warna Hijau
            )
            Library:Notify((ok and "✅ " or "❌ ") .. msg, 3)
        end)
    end,
    Tooltip = 'Kirim pesan percobaan ke Discord untuk cek apakah URL berfungsi',
})

-- ─── SINKRONISASI DATA DARI UI GAME & SNAPSHOT ────────────────────────────────
local function formatTime(sec)
    sec = math.max(0, math.floor(sec))
    local m = math.floor(sec / 60)
    local s = sec % 60
    return string.format("%02d:%02d", m, s)
end

local function resolveItemByDisplayName(rawName)
    if not rawName then return nil end
    local clean = rawName:gsub("%.%.%.", ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if clean == "" then return nil end

    if BY_NAME[clean] then return BY_NAME[clean] end

    for nameLower, item in pairs(BY_NAME) do
        if nameLower:sub(1, #clean) == clean then
            return item
        end
    end
    return nil
end

local function syncFromGameUI()
    local gui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not gui then return end
    local ui = gui:FindFirstChild("WarnetopiaUI")
    if not ui then return end

    local detectedStoreId = nil
    local foundDiscNum = nil

    for _, obj in ipairs(ui:GetDescendants()) do
        if obj:IsA("TextLabel") and obj.Visible then
            local txt = obj.Text or ""

            local mStr, sStr = txt:match("Stok baru dalam%s*(%d+):(%d+)")
            if mStr and sStr then
                local totalSec = (tonumber(mStr) * 60) + tonumber(sStr)
                restockEndClock = os.clock() + totalSec
            end

            if txt:find("Harga toko") or txt:find("Diskon") or txt:match("^%-%d+%%$") then
                local pct = tonumber(txt:match("(%d+)%%"))
                if pct and pct > 0 and pct < 100 then
                    foundDiscNum = pct
                end
            end

            if UI_TITLE_TO_STORE_ID[txt] then
                detectedStoreId = UI_TITLE_TO_STORE_ID[txt]
            end
        end
    end

    if foundDiscNum then
        discountPercent = foundDiscNum
    elseif detectedStoreId then
        discountPercent = 0
    end

    if detectedStoreId then
        local cards = {}
        local seenParents = {}

        for _, obj in ipairs(ui:GetDescendants()) do
            if (obj:IsA("TextButton") or obj:IsA("TextLabel")) and obj.Visible then
                local t = obj.Text or ""
                if t == "Beli" or t == "Habis" then
                    local cardFrame = obj.Parent
                    while cardFrame and cardFrame:IsA("GuiObject") do
                        if cardFrame.AbsoluteSize.X >= 85 and cardFrame.AbsoluteSize.X <= 260 and cardFrame.AbsoluteSize.Y >= 115 then
                            break
                        end
                        cardFrame = cardFrame.Parent
                    end

                    if cardFrame and not seenParents[cardFrame] then
                        seenParents[cardFrame] = true
                        local qtyNum = (t == "Habis") and 0 or nil
                        local bestTitle = nil
                        local bestY = math.huge
                        local lowestPrice = nil
                        local highestPrice = nil

                        for _, child in ipairs(cardFrame:GetDescendants()) do
                            if child:IsA("TextLabel") and child.Visible then
                                local ct = child.Text or ""
                                if ct:match("^Sisa%s*(%d+)") then
                                    qtyNum = tonumber(ct:match("^Sisa%s*(%d+)"))
                                elseif ct:match("^%$[%d%.%,]+") then
                                    local parsed = parsePriceText(ct)
                                    if parsed then
                                        if not lowestPrice or parsed < lowestPrice then
                                            lowestPrice = parsed
                                        end
                                        if not highestPrice or parsed > highestPrice then
                                            highestPrice = parsed
                                        end
                                    end
                                elseif ct ~= "" and ct ~= "Beli" and ct ~= "Habis" and not ct:match("^x%d+") and not ct:match("^T%d+$") and not ct:find("Rare") and not ct:find("Tip") then
                                    if child.AbsolutePosition.Y < bestY then
                                        bestY = child.AbsolutePosition.Y
                                        bestTitle = ct
                                    end
                                end
                            end
                        end

                        local cardDisc = discountPercent
                        if highestPrice and lowestPrice and highestPrice > lowestPrice then
                            cardDisc = math.floor(((highestPrice - lowestPrice) / highestPrice) * 100 + 0.5)
                            if cardDisc > 0 and discountPercent == 0 then
                                discountPercent = cardDisc
                            end
                        end

                        if bestTitle then
                            table.insert(cards, {
                                x = cardFrame.AbsolutePosition.X,
                                y = cardFrame.AbsolutePosition.Y,
                                title = bestTitle,
                                qty = qtyNum or 0,
                                price = lowestPrice,
                                discPct = cardDisc,
                            })
                        end
                    end
                end
            end
        end

        if #cards > 0 then
            table.sort(cards, function(a, b)
                if math.abs(a.y - b.y) > 25 then
                    return a.y < b.y
                end
                return a.x < b.x
            end)

            storeOrderedUI[detectedStoreId] = storeOrderedUI[detectedStoreId] or {}

            local existingMap = {}
            for idx, oldEntry in ipairs(storeOrderedUI[detectedStoreId]) do
                if oldEntry.id then
                    existingMap[oldEntry.id] = idx
                end
            end

            for _, c in ipairs(cards) do
                local resolved = resolveItemByDisplayName(c.title)
                local itemId = resolved and resolved.id or nil
                local displayName = (resolved and resolved.name) or c.title
                local basePrice = resolved and resolved.price
                local finalPrice = c.price or basePrice
                local pStr = finalPrice and formatShortPrice(finalPrice) or ""

                local newEntry = {
                    id = itemId,
                    name = displayName,
                    qty = c.qty,
                    basePrice = basePrice,
                    priceStr = pStr,
                    discPct = c.discPct,
                }

                if itemId and existingMap[itemId] then
                    storeOrderedUI[detectedStoreId][existingMap[itemId]] = newEntry
                else
                    table.insert(storeOrderedUI[detectedStoreId], newEntry)
                    if itemId then
                        existingMap[itemId] = #storeOrderedUI[detectedStoreId]
                    end
                end
            end

            if selectedStoreId == detectedStoreId then
                refreshManualStoreSlots()
            end
        end
    end
end

local function updateFromSnapshot(snap)
    if not snap or not snap.shops then return end

    for k, v in pairs(snap.shops) do
        if type(v) == "number" and v > 0 then
            if v > 1000000 then
                local rem = v - workspace:GetServerTimeNow()
                if rem > 0 and rem < 3600 then
                    restockEndClock = os.clock() + rem
                end
            elseif v <= 600 then
                restockEndClock = os.clock() + v
            end
        end
    end

    refreshManualStoreSlots()
end

-- ─── MAIN HEARTBEAT LOOP ──────────────────────────────────────────────────────
local uiTimer = 0
local checkTimer = 0

RunService.Heartbeat:Connect(function(dt)
    if cfg.walkSpeedEnabled then
        local hum = getHumanoid()
        if hum and hum.WalkSpeed ~= cfg.walkSpeedValue then
            hum.WalkSpeed = cfg.walkSpeedValue
        end
    end

    uiTimer = uiTimer + dt
    if uiTimer >= 0.5 then
        uiTimer = 0
        pcall(syncFromGameUI)

        if restockEndClock then
            local rem = restockEndClock - os.clock()
            if rem > 0 then
                RestockTimerLabel:SetText("⏰ Stok baru dalam: " .. formatTime(rem))
            else
                table.clear(storeOrderedUI)
                RestockTimerLabel:SetText("⏰ Sedang Restock (00:00)...")
            end
        end
    end

    if not cfg.autoOpenEnabled and not cfg.autoDayEnabled then
        lastStatus = nil
        return
    end

    checkTimer = checkTimer + dt
    if checkTimer < 2 then return end
    checkTimer = 0

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
                task.delay(cfg.reopenDelay, function()
                    if cfg.autoOpenEnabled and getStatus() == "TUTUP" then
                        fireAction("setOpen", { open = true })
                    end
                end)
            end
            continuePending = false
        end)
        return
    end

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

-- ─── AUTO BUY LOGIC + WEBHOOK REPORT ──────────────────────────────────────────
local function rareItemMatches(item)
    if not item then return false end
    local r = item.rarity or "biasa"
    local wantLangka  = cfg.rarityLangka  and r == "langka"
    local wantSangat  = cfg.raritySangat  and r == "sangat_langka"
    if not wantLangka and not wantSangat then return false end

    if item.tier ~= nil and cfg.minTier and cfg.minTier > 0 then
        local tier = tonumber(item.tier)
        if tier and tier < cfg.minTier then return false end
    end

    return true
end

local RARE_STORE_MAP = {
    computer  = "store_computer",
    furniture = "store_furniture",
    decor     = "store_decor",
}

local function processSnap(snap)
    if not snap or not snap.shops then return end
    latestSnap = snap
    updateFromSnapshot(snap)

    if (not cfg.autoBuyEnabled and not cfg.autoMinimartEnabled) or isBuying then return end
    if os.clock() - lastBuyCooldown < 4 then return end

    local purchaseQueue = {}

    for storeId, shelf in pairs(snap.shops.shelves or {}) do
        if storeId == "minimart" and cfg.autoMinimartEnabled then
            for itemId, qty in pairs(shelf) do
                if qty and qty > 0 then
                    purchaseQueue[storeId] = purchaseQueue[storeId] or {}
                    table.insert(purchaseQueue[storeId], { id = itemId, qty = qty })
                end
            end
        elseif cfg.autoBuyEnabled then
            local cfgKey = RARE_STORE_MAP[storeId]
            if cfgKey and cfg[cfgKey] then
                for itemId, qty in pairs(shelf) do
                    if qty and qty > 0 then
                        local item = BY_ID[itemId]
                        if rareItemMatches(item) then
                            purchaseQueue[storeId] = purchaseQueue[storeId] or {}
                            table.insert(purchaseQueue[storeId], { id = itemId, qty = qty })
                        end
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
    local boughtLog = {}

    for storeId, items in pairs(purchaseQueue) do
        local targetCFrame = STORE_LOCATIONS[storeId]
        if targetCFrame then
            hrp.CFrame = targetCFrame
            task.wait(0.45)

            for _, itemData in ipairs(items) do
                local stillEnabled = (storeId == "minimart" and cfg.autoMinimartEnabled) or (storeId ~= "minimart" and cfg.autoBuyEnabled)
                if not stillEnabled then break end

                local boughtCount = 0
                for i = 1, itemData.qty do
                    fireAction("storeBuy", { store = storeId, item = itemData.id })
                    boughtCount = boughtCount + 1
                    task.wait(0.25)
                end

                if boughtCount > 0 then
                    local itemInfo = BY_ID[itemData.id]
                    local itemName = (itemInfo and itemInfo.name) or itemData.id
                    local rarityTag = (itemInfo and itemInfo.rarity == "sangat_langka" and " [★★]")
                                   or (itemInfo and itemInfo.rarity == "langka" and " [★]")
                                   or ""
                    local storeName = STORE_ID_TO_NAME[storeId] or storeId
                    table.insert(boughtLog, string.format("• **%s**%s (x%d) — *%s*", itemName, rarityTag, boughtCount, storeName))
                end
            end
        end
    end

    task.wait(0.2)
    if getHRP() then
        getHRP().CFrame = originalCFrame
    end
    isBuying = false

    -- Kirim laporan ringkasan belanja ke Discord Webhook jika aktif
    if cfg.webhookEnabled and #boughtLog > 0 then
        task.spawn(sendWebhook,
            "🛒 Laporan Auto Buy Warnetopia",
            table.concat(boughtLog, "\n"),
            15844367 -- Warna Emas
        )
    end
end

Snapshot.OnClientEvent:Connect(function(snap)
    task.spawn(processSnap, snap)
end)

-- ── KEYBIND toggle UI ─────────────────────────────────────────────────────────
Library:SetWatermark('Warnetopia Hub 🖤')
Library.Toggled = true

print('[Hub] 🖤 Warnetopia LinoriaLib UI loaded! Tekan RightShift buat hide/show.')
