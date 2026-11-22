--[[
    Warnetopia Hub — Full Script
    UI: Fluent
    Features:
    ✅ Auto Buy Rare Items
    ✅ Auto Restock Minimart
    ✅ Manual Buy Semua Toko (+ rarity badge + detail diskon)
    ✅ Auto Buka Warnet
    ✅ Auto Lanjut Hari (EN & ID)
    ✅ Auto Tempatkan Pelanggan
    ✅ Auto Bersih Sampah
    ✅ Auto Layani Semua Menu
    ✅ Auto Buff Es Teh Segar (EN & ID detect)
    ✅ Auto Restock Kafe dari Menu Kafe
    ✅ Stats Dashboard Real-time
    ✅ Low Stock Alert + Discord Webhook
    ✅ WalkSpeed Custom
    ✅ Anti AFK
    ✅ Save/Load Config
    ✅ Mobile Toggle Button
    Credit: Realx13
--]]

-- ─── LOAD FLUENT ──────────────────────────────────────────────────
local function safeLoad(urls, name)
    for _, url in ipairs(urls) do
        local ok, body = pcall(function() return game:HttpGet(url) end)
        if ok and type(body) == "string" and #body > 100 and not body:find("404: Not Found") then
            local fn, err = loadstring(body)
            if type(fn) == "function" then
                local okRun, res = pcall(fn)
                if okRun and res then return res end
            else
                warn("[Hub] Gagal compile " .. name .. ": " .. tostring(err))
            end
        end
    end
    return nil
end

local Fluent = safeLoad({
    "https://raw.githubusercontent.com/dawid-scripts/Fluent/master/main.lua",
    "https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua",
    "https://raw.githubusercontent.com/Footagesus/Fluent/main/main.lua"
}, "Fluent")

if not Fluent then warn("[Hub] Fluent gagal dimuat!") return end

local SaveManager = safeLoad({
    "https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"
}, "SaveManager")

local InterfaceManager = safeLoad({
    "https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"
}, "InterfaceManager")

-- ─── SERVICES ─────────────────────────────────────────────────────
local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local RunService          = game:GetService("RunService")
local VirtualUser         = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")
local HttpService         = game:GetService("HttpService")
local UserInputService    = game:GetService("UserInputService")
local LocalPlayer         = Players.LocalPlayer

local httpRequest = (syn and syn.request) or (http and http.request) or http_request or request

-- ─── REMOTES ──────────────────────────────────────────────────────
local Remotes  = ReplicatedStorage:WaitForChild("Remotes", 10)
local Action   = Remotes:WaitForChild("Action", 10)
local Snapshot = Remotes:WaitForChild("Snapshot", 10)

-- ─── CATALOG ──────────────────────────────────────────────────────
local BY_ID   = {}
local BY_NAME = {}
pcall(function()
    local Catalog = require(ReplicatedStorage.Shared.Data.Catalog)
    for _, item in ipairs(Catalog.ITEMS) do
        BY_ID[item.id] = item
        if item.name then BY_NAME[item.name:lower()] = item end
    end
end)

-- ─── KONSTANTA ────────────────────────────────────────────────────
local STORE_LOCATIONS = {
    computer  = CFrame.new(-135.6, 2.7, -4.9),
    furniture = CFrame.new(-182.8, 2.7, -6.3),
    decor     = CFrame.new(-26.1,  2.7, -42.2),
    kitchen   = CFrame.new(-187.6, 2.7, -44.1),
    minimart  = CFrame.new(91.7,   2.7, -5.2),
    esteh     = CFrame.new(305.1,  2.7, -46.9),
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

local ESTEH_DISPLAY_TO_ID = {
    ["🧊 Es Teh Manis ($5.000 • 4 Jam)"] = "es_teh",
    ["🍊 Es Jeruk ($7.000 • 5.5 Jam)"]  = "es_jeruk",
}
local ESTEH_ID_TO_LABEL = {
    es_teh   = "Es Teh Manis ($5.000)",
    es_jeruk = "Es Jeruk ($7.000)",
}

local COOK_DURATION = {
    ["Buat Mie Telur"]   = 2.5,
    ["Buat Nasi Goreng"] = 2.5,
    ["Buat Snack"]       = 0.5,
    ["Buat Kopi Hitam"]  = 1.0,
    ["Buat Es Teh"]      = 0.8,
    ["Buat Soda"]        = 0.8,
}

local FOOD_MAP = {
    ["mie telur"]    = { cook = "Buat Mie Telur",  station = "stove",          switchNeeded = false },
    ["egg noodles"]  = { cook = "Buat Mie Telur",  station = "stove",          switchNeeded = false },
    ["nasi goreng"]  = { cook = "Buat Nasi Goreng", station = "stove",          switchNeeded = true  },
    ["fried rice"]   = { cook = "Buat Nasi Goreng", station = "stove",          switchNeeded = true  },
    ["snack"]        = { cook = "Buat Snack",       station = "snack_rack",     switchNeeded = false },
    ["kopi hitam"]   = { cook = "Buat Kopi Hitam",  station = "coffee_machine", switchNeeded = false },
    ["black coffee"] = { cook = "Buat Kopi Hitam",  station = "coffee_machine", switchNeeded = false },
    ["es teh"]       = { cook = "Buat Es Teh",      station = "fridge",         switchNeeded = false },
    ["iced tea"]     = { cook = "Buat Es Teh",      station = "fridge",         switchNeeded = false },
    ["soda"]         = { cook = "Buat Soda",        station = "fridge",         switchNeeded = true  },
}

local DELIVER_ACTIONS = {
    "Antar Mie Telur", "Antar Nasi Goreng", "Antar Snack",
    "Antar Kopi Hitam", "Antar Es Teh", "Antar Soda",
    "Deliver Egg Noodles", "Deliver Fried Rice", "Deliver Snack",
    "Deliver Black Coffee", "Deliver Iced Tea", "Deliver Soda",
}

local RARE_STORE_MAP = {
    computer  = "store_computer",
    furniture = "store_furniture",
    decor     = "store_decor",
}

-- Map: snap.stock key → catalog item ID buat beli dari menu kafe
local CAFE_STOCK_MAP = {
    snack  = "stock_snack",
    tea    = "stock_tea",
    soda   = "stock_soda",
    coffee = "stock_coffee",
    noodle = "stock_noodle",
    rice   = "stock_rice",
}

local STOCK_LABELS = {
    snack  = "Snack",
    tea    = "Es Teh",
    soda   = "Soda",
    coffee = "Kopi Hitam",
    noodle = "Mie Telur/Nasi Goreng",
    rice   = "Nasi (Minimart)",
}

local MAX_SLOTS = 15

-- ─── CONFIG ───────────────────────────────────────────────────────
local cfg = {
    autoBuyEnabled      = false,
    autoMinimartEnabled = false,
    autoOpenEnabled     = false,
    autoDayEnabled      = false,
    autoPlaceEnabled    = false,
    autoCleanEnabled    = false,
    autoServeEnabled    = false,
    autoEsTehEnabled    = false,
    autoRestockKafe     = false,
    esTehChoice         = "es_jeruk",
    walkSpeedEnabled    = false,
    walkSpeedValue      = 32,
    antiAfkEnabled      = true,
    webhookUrl          = "",
    webhookEnabled      = false,
    webhookStockAlert   = false,
    stockAlertEnabled   = true,
    stockThreshold      = 10,
    store_computer      = true,
    store_furniture     = true,
    store_decor         = true,
    minTier             = 3,
    rarityLangka        = true,
    raritySangat        = true,
    reopenDelay         = 6,
    continueDelay       = 2,
}

-- ─── STATE ────────────────────────────────────────────────────────
local lastStatus        = nil
local reopenPending     = false
local continuePending   = false
local isBuying          = false
local isCleaning        = false
local isServing         = false
local lastBuyCooldown   = 0
local lastEsTehCooldown = 0
local latestSnap        = nil
local lastStockAlert    = {}
local lastRestockCooldown = {}
local restockEndClock   = nil
local discountPercent   = 0
local assignedCooldowns = {}
local selectedStoreId   = "computer"
local storeOrderedUI    = {}
local activeSlotItems   = {}

-- ─── NOTIFY ───────────────────────────────────────────────────────
local function notify(title, content, duration)
    pcall(function()
        Fluent:Notify({ Title=title or "Hub", Content=content or "", Duration=duration or 3 })
    end)
end

-- ─── HELPERS DASAR ────────────────────────────────────────────────
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

local function safeTeleport(cf)
    local hrp = getHRP()
    local hum = getHumanoid()
    if not hrp or not cf then return end
    if hum and hum.Sit then hum.Sit = false task.wait(0.05) end
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.CFrame = cf
end

local function returnToOrigin(orig)
    if not orig then return end
    safeTeleport(orig)
    task.wait(0.12)
    safeTeleport(orig)
end

local function isGuiTrulyVisible(obj)
    if not obj or not obj:IsA("GuiObject") or not obj.Visible then return false end
    local curr = obj.Parent
    while curr and curr:IsA("GuiObject") do
        if not curr.Visible then return false end
        curr = curr.Parent
    end
    return true
end

local function getAllGuiRoots()
    local roots = {}
    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if pg then table.insert(roots, pg) end
    pcall(function()
        local cg = game:GetService("CoreGui")
        if cg then table.insert(roots, cg) end
    end)
    if gethui then
        pcall(function()
            local hui = gethui()
            if hui then table.insert(roots, hui) end
        end)
    end
    return roots
end

local function clickGuiButton(btn)
    if not btn then return end
    local targets = { btn }
    for _, d in ipairs(btn:GetDescendants()) do
        if d:IsA("GuiButton") then table.insert(targets, d) end
    end
    for _, t in ipairs(targets) do
        if firesignal then
            pcall(function() firesignal(t.MouseButton1Down) end)
            pcall(function() firesignal(t.MouseButton1Up) end)
            pcall(function() firesignal(t.MouseButton1Click) end)
            pcall(function() firesignal(t.Activated) end)
        end
    end
    pcall(function()
        local pos = btn.AbsolutePosition
        local sz  = btn.AbsoluteSize
        local cx  = pos.X + sz.X/2
        local cy  = pos.Y + sz.Y/2 + 36
        VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, true, game, 1)
        task.wait(0.05)
        VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, false, game, 1)
    end)
end

local function triggerPromptSafe(prompt)
    if not prompt or not prompt.Parent or not prompt.Enabled then return end
    if fireproximityprompt then
        pcall(function() fireproximityprompt(prompt) end)
    else
        pcall(function() prompt:InputHoldBegin() end)
        task.wait((prompt.HoldDuration or 0) + 0.15)
        pcall(function() prompt:InputHoldEnd() end)
    end
end

local function tpToPart(hrp, part, offset)
    if not hrp or not part then return end
    local pos = part:IsA("Model") and part:GetPivot().Position or part.Position
    safeTeleport(CFrame.new(pos + (offset or Vector3.new(0, 2, 2))))
    task.wait(0.3)
end

local function formatShortPrice(num)
    if not num or type(num) ~= "number" then return "" end
    if num >= 1000000 then
        local jt = num / 1000000
        return (jt % 1 == 0) and ("$"..jt.."Jt") or string.format("$%.2fJt", jt)
    elseif num >= 1000 then
        local k = num / 1000
        return (k % 1 == 0) and ("$"..k.."K") or string.format("$%.1fK", k)
    end
    return "$"..tostring(num)
end

local function parsePriceText(txt)
    if not txt then return nil end
    return tonumber(txt:gsub("[^%d]", ""))
end

local function formatTime(sec)
    sec = math.max(0, math.floor(sec))
    return string.format("%02d:%02d", math.floor(sec/60), sec%60)
end

-- ─── STATUS WARNET ────────────────────────────────────────────────
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

-- ─── DAY REPORT BUTTON (EN + ID) ─────────────────────────────────
local function getDayReportButton()
    for _, root in ipairs(getAllGuiRoots()) do
        for _, obj in ipairs(root:GetDescendants()) do
            if obj:IsA("TextButton") or obj:IsA("TextLabel") then
                local txt = tostring(obj.Text or "")
                if txt:find("Lanjut ke Hari", 1, true)
                or txt:find("Continue to Day", 1, true) then
                    local btn = obj:IsA("GuiButton") and obj or obj:FindFirstAncestorWhichIsA("GuiButton")
                    if btn and isGuiTrulyVisible(btn) then return btn end
                end
            end
        end
    end
    return nil
end

-- ─── ES TEH BUFF (EN + ID) ────────────────────────────────────────
local function getFreshBuffText()
    local gui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not gui then return nil end
    local ok, tl = pcall(function() return gui.WarnetopiaUI.Root.TL end)
    if not ok or not tl then return nil end
    for _, obj in ipairs(tl:GetDescendants()) do
        if obj:IsA("TextLabel") and obj.Visible then
            local raw = obj.Text or ""
            local txt = raw:gsub("<[^>]+>", " "):gsub("%s+", " "):gsub("^%s+",""):gsub("%s+$","")
            local low = txt:lower()
            -- ID: "Segar", EN: "Refreshed", "Fresh"
            if low:find("refreshed") or low:find("fresh for")
            or low:find("^fresh%s") or low:find("segar")
            or raw:find("⚡") then
                local clean = txt:gsub("^[^%w⚡]+", "")
                if clean ~= "" then return clean end
            end
        end
    end
    return nil
end

local function buyEsTeh(itemId, isAuto)
    if isBuying or isCleaning or isServing then return false end
    local hrp = getHRP()
    if not hrp then return false end
    isBuying = true
    local orig = hrp.CFrame
    safeTeleport(STORE_LOCATIONS.esteh)
    task.wait(0.45)
    fireAction("eat", { item = itemId, warung = "esteh" })
    notify(isAuto and "🥤 Auto Buff" or "✅ Es Teh Buff", ESTEH_ID_TO_LABEL[itemId] or itemId, 2.5)
    task.wait(0.3)
    returnToOrigin(orig)
    isBuying = false
    return true
end

-- ─── PROXIMITY PROMPTS ────────────────────────────────────────────
local function findCookPrompt(stationName, cookAction)
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.Enabled then
            if (obj.Parent and obj.Parent.Name) == stationName and obj.ActionText == cookAction then
                local p = obj.Parent
                if p and (p:IsA("BasePart") or p:IsA("Model")) then return obj, p end
            end
        end
    end
    return nil, nil
end

local function findSwitchPrompt(stationName)
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.Enabled then
            if (obj.Parent and obj.Parent.Name) == stationName and obj.ActionText == "Ganti" then
                local p = obj.Parent
                if p and (p:IsA("BasePart") or p:IsA("Model")) then return obj, p end
            end
        end
    end
    return nil, nil
end

local function findDeliverPrompt(foodKeyword)
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.Enabled then
            local actionTxt = obj.ActionText or ""
            local objectTxt = obj.ObjectText or ""
            local objectLow = objectTxt:lower()
            local isDeliver = false
            for _, da in ipairs(DELIVER_ACTIONS) do
                if actionTxt == da then isDeliver = true break end
            end
            if isDeliver then
                if not foodKeyword or objectLow:find(foodKeyword:lower(), 1, true) then
                    local p = obj.Parent
                    if p and p:IsA("Attachment") then p = p.Parent end
                    if p and (p:IsA("BasePart") or p:IsA("Model")) then
                        return obj, p, actionTxt, objectTxt
                    end
                end
            end
        end
    end
    return nil, nil, nil, nil
end

local function findTrashPrompts()
    local list = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.Enabled then
            local a = (obj.ActionText or ""):lower()
            local o = (obj.ObjectText or ""):lower()
            local n = (obj.Parent and obj.Parent.Name or ""):lower()
            if a:find("bersih") or a:find("sampah") or a:find("clean") or a:find("trash")
                or o:find("sampah") or n:find("trash") or n:find("sampah") then
                local p = obj.Parent
                if p and p:IsA("Attachment") then p = p.Parent end
                if p and (p:IsA("BasePart") or p:IsA("Model")) then
                    table.insert(list, { prompt = obj, part = p })
                end
            end
        end
    end
    return list
end

-- ─── AUTO SERVE SEMUA MENU ────────────────────────────────────────
local function processAutoServeAll()
    if isServing or isBuying or isCleaning then return end

    local deliverPrompt, deliverPart, deliverAction, _ = findDeliverPrompt(nil)
    if not deliverPrompt or not deliverPart then return end

    local foodKey  = (deliverAction:match("^Antar%s+(.+)$") or deliverAction:match("^Deliver%s+(.+)$") or ""):lower()
    local foodInfo = FOOD_MAP[foodKey]
    local hrp      = getHRP()
    if not hrp then return end

    isServing = true
    local originalCFrame = hrp.CFrame
    local needSwitchBack = false

    if foodInfo then
        if foodInfo.switchNeeded then
            local sw, swPart = findSwitchPrompt(foodInfo.station)
            if sw and swPart then
                tpToPart(hrp, swPart)
                triggerPromptSafe(sw)
                task.wait((sw.HoldDuration or 0) + 0.4)
                needSwitchBack = true
            end
        end

        local cp, cPart = findCookPrompt(foodInfo.station, foodInfo.cook)
        if cp and cPart then
            local curHrp = getHRP()
            if curHrp then
                tpToPart(curHrp, cPart)
                triggerPromptSafe(cp)
                local cookWait = COOK_DURATION[foodInfo.cook] or ((cp.HoldDuration or 0) + 0.5)
                task.wait(cookWait)
            end
        end
    end

    if cfg.autoServeEnabled and not isBuying then
        local promptStillValid = deliverPrompt and deliverPrompt.Parent and deliverPrompt.Enabled
        if promptStillValid then
            local curHrp = getHRP()
            if curHrp then
                tpToPart(curHrp, deliverPart)
                triggerPromptSafe(deliverPrompt)
                task.wait((deliverPrompt.HoldDuration or 0) + 0.4)
            end
        else
            local dp2, pp2, _, _ = findDeliverPrompt(foodKey ~= "" and foodKey or nil)
            if dp2 and pp2 then
                local curHrp = getHRP()
                if curHrp then
                    tpToPart(curHrp, pp2)
                    triggerPromptSafe(dp2)
                    task.wait((dp2.HoldDuration or 0) + 0.4)
                end
            end
        end
    end

    if not isBuying and not isCleaning then returnToOrigin(originalCFrame) end
    isServing = false

    if needSwitchBack and foodInfo then
        task.spawn(function()
            task.wait(0.3)
            local defaultCook = (foodInfo.station == "stove") and "Buat Mie Telur" or "Buat Es Teh"
            local defP, _ = findCookPrompt(foodInfo.station, defaultCook)
            if not defP then
                local sw2, sw2Part = findSwitchPrompt(foodInfo.station)
                if sw2 and sw2Part then
                    local curHrp = getHRP()
                    if curHrp then
                        tpToPart(curHrp, sw2Part)
                        triggerPromptSafe(sw2)
                    end
                end
            end
        end)
    end
end

-- ─── AUTO BERSIH SAMPAH ───────────────────────────────────────────
local function processAutoClean()
    if isCleaning or isBuying or isServing then return end
    local hrp = getHRP()
    if not hrp then return end
    local trashList = findTrashPrompts()
    if #trashList == 0 then return end
    isCleaning = true
    local orig = hrp.CFrame
    for _, item in ipairs(trashList) do
        if not cfg.autoCleanEnabled or isBuying or isServing then break end
        if item.prompt and item.prompt.Parent and item.prompt.Enabled and item.part and item.part.Parent then
            local curHrp = getHRP()
            if curHrp then
                tpToPart(curHrp, item.part)
                triggerPromptSafe(item.prompt)
                task.wait((item.prompt.HoldDuration or 0) + 0.35)
            end
        end
    end
    if not isBuying and not isServing then returnToOrigin(orig) end
    isCleaning = false
end

-- ─── AUTO TEMPATKAN PELANGGAN ─────────────────────────────────────
local function collectQueueIds(node, visited, results, depth)
    if type(node) ~= "table" or visited[node] or depth > 5 then return end
    visited[node] = true
    if type(node.id) == "string" and #node.id >= 8 and #node.id <= 24 then
        if node.hours or node.patience or node.name or node.want then
            results[node.id] = true
        end
    end
    for k, v in pairs(node) do
        if type(v) == "table" and k ~= "shops" and k ~= "inventory" and k ~= "desks" then
            collectQueueIds(v, visited, results, depth + 1)
        end
    end
end

local function processAutoPlace()
    local now = os.clock()
    local fired = false
    if latestSnap then
        local queueIds = {}
        collectQueueIds(latestSnap, {}, queueIds, 0)
        for custId in pairs(queueIds) do
            if now - (assignedCooldowns[custId] or 0) >= 2.5 then
                assignedCooldowns[custId] = now
                fireAction("assign", { id = custId, desk = "auto" })
                fired = true
                task.wait(0.15)
            end
        end
    end
    if fired then return end

    local gui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not gui then return end
    local ui = gui:FindFirstChild("WarnetopiaUI") or gui
    for _, obj in ipairs(ui:GetDescendants()) do
        if (obj:IsA("TextButton") or obj:IsA("TextLabel")) and (obj.Text == "Otomatis" or obj.Text == "Auto") then
            local btn = obj:IsA("GuiButton") and obj or obj:FindFirstAncestorWhichIsA("GuiButton")
            if btn and isGuiTrulyVisible(btn) then clickGuiButton(btn) return end
        end
    end
    local topBtn, topY = nil, math.huge
    for _, obj in ipairs(ui:GetDescendants()) do
        if (obj:IsA("TextButton") or obj:IsA("TextLabel")) and (obj.Text == "Tempatkan" or obj.Text == "Assign") then
            local btn = obj:IsA("GuiButton") and obj or obj:FindFirstAncestorWhichIsA("GuiButton")
            if btn and isGuiTrulyVisible(btn) and btn.AbsolutePosition.Y < topY then
                topY = btn.AbsolutePosition.Y
                topBtn = btn
            end
        end
    end
    if topBtn then clickGuiButton(topBtn) end
end

-- ─── WEBHOOK ──────────────────────────────────────────────────────
local function sendWebhook(title, description, colorHex)
    if not httpRequest then return false, "Executor tidak support HTTP" end
    local url = (cfg.webhookUrl or ""):gsub("^%s+",""):gsub("%s+$","")
    if url == "" or not url:find("^https://") then return false, "URL tidak valid" end
    local payload = {
        username = "Warnetopia Notifier",
        embeds = {{ title=title, description=description, color=colorHex or 3447003,
            footer = { text = "Player: "..LocalPlayer.Name.." • "..os.date("%H:%M:%S") }
        }}
    }
    local ok, res = pcall(function()
        return httpRequest({ Url=url, Method="POST",
            Headers={ ["Content-Type"]="application/json" },
            Body=HttpService:JSONEncode(payload) })
    end)
    if ok and res and (res.StatusCode==200 or res.StatusCode==204) then return true, "Terkirim!" end
    return false, "Gagal kirim"
end

-- ─── ANTI AFK ─────────────────────────────────────────────────────
LocalPlayer.Idled:Connect(function()
    if cfg.antiAfkEnabled then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end
end)

-- ─── MANUAL BUY HELPERS ───────────────────────────────────────────
local StoreSlotButtons = {}

local function setFluentButtonState(btnObj, newTitle, newDesc, isVisible)
    if not btnObj then return end
    pcall(function()
        if btnObj.SetTitle then btnObj:SetTitle(newTitle) end
        if btnObj.SetDesc then btnObj:SetDesc(newDesc) end
        local frame = btnObj.Frame or btnObj.Container or btnObj.Holder
        if frame and frame:IsA("GuiObject") then frame.Visible = isVisible end
    end)
end

local function refreshManualStoreSlots()
    table.clear(activeSlotItems)
    local orderedList = storeOrderedUI[selectedStoreId]
    local snapShelf   = latestSnap and latestSnap.shops and latestSnap.shops.shelves
                        and latestSnap.shops.shelves[selectedStoreId]
    local mult = (discountPercent > 0) and (1 - discountPercent/100) or 1

    local finalItems = {}
    local seenIds = {}

    if orderedList and #orderedList > 0 then
        for _, entry in ipairs(orderedList) do
            local liveQty = (entry.id and snapShelf and snapShelf[entry.id] ~= nil)
                and snapShelf[entry.id] or entry.qty
            entry.qty = liveQty
            local itemDisc = (discountPercent > 0) and discountPercent or (entry.discPct or 0)
            local finalPriceStr = entry.priceStr
            if entry.basePrice and itemDisc > 0 then
                finalPriceStr = formatShortPrice(math.floor(entry.basePrice * (1 - itemDisc/100) + 0.5))
            end
            table.insert(finalItems, {
                id=entry.id, name=entry.name, qty=liveQty,
                priceStr=finalPriceStr, discPct=itemDisc, basePrice=entry.basePrice,
            })
            if entry.id then seenIds[entry.id] = true end
        end
    end

    if snapShelf then
        local extraIds = {}
        for itemId in pairs(snapShelf) do
            if not seenIds[itemId] then table.insert(extraIds, itemId) end
        end
        table.sort(extraIds)
        for _, itemId in ipairs(extraIds) do
            local qty = snapShelf[itemId] or 0
            local itemInfo = BY_ID[itemId]
            local displayName = (itemInfo and itemInfo.name) or itemId
            local basePrice = itemInfo and itemInfo.price
            local discPrice = basePrice and mult < 1 and math.floor(basePrice * mult + 0.5) or basePrice
            local finalPriceStr = discPrice and formatShortPrice(discPrice) or ""
            table.insert(finalItems, {
                id=itemId, name=displayName, qty=qty,
                priceStr=finalPriceStr, discPct=discountPercent, basePrice=basePrice,
            })
        end
    end

    if #finalItems > 0 then
        for i = 1, MAX_SLOTS do
            local item = finalItems[i]
            if item then
                activeSlotItems[i] = item
                -- Rarity badge
                local itemInfo = item.id and BY_ID[item.id]
                local rarity   = itemInfo and itemInfo.rarity or "biasa"
                local badge    = rarity == "sangat_langka" and " ★★" or rarity == "langka" and " ★" or ""
                local titleText = item.name .. badge

                -- Desc: stok + harga diskon detail
                local statusStr = item.qty > 0 and ("Stok: "..item.qty) or "⛔ HABIS"
                local priceInfo = ""
                if item.priceStr and item.priceStr ~= "" then
                    if item.discPct and item.discPct > 0 and item.basePrice then
                        local origPrice = formatShortPrice(item.basePrice)
                        priceInfo = string.format(" │ 💰 %s (-%d%% dari %s)", item.priceStr, item.discPct, origPrice)
                    else
                        priceInfo = " │ 💰 " .. item.priceStr
                    end
                end
                setFluentButtonState(StoreSlotButtons[i], titleText, statusStr .. priceInfo, true)
            else
                setFluentButtonState(StoreSlotButtons[i], "", "", false)
            end
        end
    else
        for i = 1, MAX_SLOTS do
            if i <= 4 then
                setFluentButtonState(StoreSlotButtons[i], "Slot "..i, "Buka UI toko dulu / tunggu reset", true)
            else
                setFluentButtonState(StoreSlotButtons[i], "", "", false)
            end
        end
    end
end

local function buySingleItemManual(storeId, itemId, priceStr)
    if isBuying or isCleaning or isServing then
        notify("Tunggu Sebentar", "Sedang menjalankan aksi lain...", 2)
        return
    end
    local hrp = getHRP()
    local targetCFrame = STORE_LOCATIONS[storeId]
    if not hrp or not targetCFrame then return end
    isBuying = true
    local orig = hrp.CFrame
    local itemInfo = BY_ID[itemId]
    local itemName = (itemInfo and itemInfo.name) or itemId
    safeTeleport(targetCFrame)
    task.wait(0.4)
    fireAction("storeBuy", { store=storeId, item=itemId })
    notify("✅ Berhasil Beli", itemName..(priceStr ~= "" and " ("..priceStr..")" or ""), 2.5)
    task.wait(0.25)
    returnToOrigin(orig)
    isBuying = false
end

-- ─── STOCK ALERT + AUTO RESTOCK KAFE ─────────────────────────────
local function checkStockAlert(stock)
    if not stock then return end
    local alerts = {}

    for key, label in pairs(STOCK_LABELS) do
        local qty = stock[key] or 0
        local thr = cfg.stockThreshold

        -- Warning notif
        if cfg.stockAlertEnabled and qty < thr then
            if not lastStockAlert[key] or (os.clock() - lastStockAlert[key]) > 120 then
                lastStockAlert[key] = os.clock()
                table.insert(alerts, string.format("⚠️ %s tinggal %d", label, qty))
            end
        else
            lastStockAlert[key] = nil
        end

        -- Auto restock dari menu kafe (FireServer "buy")
        if cfg.autoRestockKafe and qty < thr then
            local cafeItemId = CAFE_STOCK_MAP[key]
            if cafeItemId then
                local now = os.clock()
                if now - (lastRestockCooldown[key] or 0) >= 30 then
                    lastRestockCooldown[key] = now
                    task.spawn(function()
                        -- Hitung berapa kali fire (+10 per fire)
                        local target = thr + 20
                        local needed = math.max(1, math.min(math.ceil((target - qty) / 10), 10))
                        for i = 1, needed do
                            fireAction("buy", { id = cafeItemId })
                            task.wait(0.3)
                        end
                        notify("🛒 Auto Restock Kafe",
                            string.format("%s +%d stok", label, needed * 10), 3)
                    end)
                end
            end
        end
    end

    if #alerts > 0 then
        local msg = table.concat(alerts, "\n")
        notify("⚠️ Stok Hampir Habis!", msg, 5)
        if cfg.webhookStockAlert then
            task.spawn(sendWebhook, "⚠️ Low Stock Alert — Warnetopia", msg, 16711680)
        end
    end
end

-- ─── ADDTOGGLE (normalized boolean) ──────────────────────────────
local function addToggle(section, id, title, desc, defaultVal, extraCallback)
    cfg[id] = defaultVal
    return section:AddToggle(id, {
        Title       = title,
        Description = desc,
        Default     = defaultVal,
        Callback    = function(val)
            local boolVal
            if type(val) == "boolean" then boolVal = val
            elseif type(val) == "number" then boolVal = val ~= 0
            elseif type(val) == "string" then boolVal = val == "true" or val == "1"
            elseif type(val) == "table" then
                boolVal = val.Value == true
            else boolVal = false end
            cfg[id] = boolVal
            if extraCallback then extraCallback(boolVal) end
        end
    })
end

-- ─── BERSIHKAN GUI LAMA ───────────────────────────────────────────
for _, root in ipairs(getAllGuiRoots()) do
    for _, child in ipairs(root:GetChildren()) do
        if child:IsA("ScreenGui") and child.Name == "ScreenGui" then
            if child:FindFirstChild("Notifications") then
                pcall(function() child:Destroy() end)
            end
        end
    end
end
local pg = LocalPlayer:WaitForChild("PlayerGui")
local oldMobile = pg:FindFirstChild("MobileToggle")
if oldMobile then oldMobile:Destroy() end

-- ─── BUILD FLUENT UI ──────────────────────────────────────────────
local isMobile = UserInputService.TouchEnabled
local Window = Fluent:CreateWindow({
    Title       = "Warnetopia Hub 🖤",
    SubTitle    = "by Realx13",
    TabWidth    = isMobile and 125 or 160,
    Size        = isMobile and UDim2.fromOffset(500, 320) or UDim2.fromOffset(620, 480),
    Acrylic     = false,
    Theme       = "Dark",
    MinimizeKey = Enum.KeyCode.RightShift
})

local Tabs = {
    AutoBuy   = Window:AddTab({ Title="Auto Buy",   Icon="shopping-cart" }),
    Dashboard = Window:AddTab({ Title="Dashboard",  Icon="bar-chart-2"   }),
    TokoKota  = Window:AddTab({ Title="Toko Kota",  Icon="store"         }),
    AutoFarm  = Window:AddTab({ Title="Auto Farm",  Icon="zap"           }),
    Settings  = Window:AddTab({ Title="Settings",   Icon="settings"      }),
}

-- ══ TAB 1: AUTO BUY ══════════════════════════════════════════════
local SecAutoBuy = Tabs.AutoBuy:AddSection("⚙️ Auto Buy Rare")
addToggle(SecAutoBuy, "autoBuyEnabled", "Auto Buy Rare ON/OFF", "Otomatis TP & beli item langka dari toko kota", false)
SecAutoBuy:AddSlider("minTier", {
    Title="Minimum Tier", Description="Hanya beli item tier >= ini",
    Default=3, Min=1, Max=4, Rounding=0,
    Callback=function(val) if type(val)=="number" then cfg.minTier = val end end
})

local SecRarity = Tabs.AutoBuy:AddSection("✨ Rarity Filter")
addToggle(SecRarity, "rarityLangka", "Langka (★)", nil, true)
addToggle(SecRarity, "raritySangat", "Sangat Langka (★★)", nil, true)

local SecToko = Tabs.AutoBuy:AddSection("🏪 Target Toko Rare")
addToggle(SecToko, "store_computer", "💻 Toko Komputer Jaya", nil, true)
addToggle(SecToko, "store_furniture", "🪑 Mebel Jati", nil, true)
addToggle(SecToko, "store_decor", "🌿 Galeri Dekorasi", nil, true)

local SecMinimart = Tabs.AutoBuy:AddSection("🛒 Minimart 24")
addToggle(SecMinimart, "autoMinimartEnabled", "Auto Restock Minimart", "Borong semua stok bahan di Minimart 24", false)

-- ══ TAB 2: DASHBOARD ═════════════════════════════════════════════
local ParaStats = Tabs.Dashboard:AddParagraph({
    Title   = "💰 Stats Warnet Hari Ini",
    Content = "📅 Hari: -  |  💵 Saldo: -  |  ⭐ Rating: -\n👥 Pelanggan: -  |  ✅ Served: -  |  😠 Kecewa: -\n📈 Income: - (Billing: - | Makanan: - | Tips: -)\n🖥️ Sesi Aktif: -  |  🕐 Antrean: -"
})

local ParaStock = Tabs.Dashboard:AddParagraph({
    Title   = "📦 Stok Kafe Saat Ini",
    Content = "🍟 Snack: -\n🧊 Es Teh: -\n🥤 Soda: -\n☕ Kopi: -\n🍜 Mie/Nasi: -"
})

local SecAlert = Tabs.Dashboard:AddSection("⚠️ Low Stock & Auto Restock")
addToggle(SecAlert, "stockAlertEnabled", "Aktifkan Stock Alert", "Notifikasi jika stok kafe di bawah batas", true)
SecAlert:AddSlider("stockThreshold", {
    Title="Batas Stok Minimum", Default=10, Min=5, Max=50, Rounding=0,
    Callback=function(val) if type(val)=="number" then cfg.stockThreshold = val end end
})
addToggle(SecAlert, "autoRestockKafe", "🛒 Auto Restock Kafe",
    "Otomatis beli stok kafe dari menu kafe jika < batas (tanpa TP ke mana-mana)", false)
addToggle(SecAlert, "webhookStockAlert", "Kirim Alert ke Discord", "Butuh Webhook URL di tab Settings", false)

local function stockLabel(qty, thr)
    if qty <= 0 then return " [⛔ HABIS]"
    elseif qty < thr then return string.format(" [⚠️ %d]", qty)
    else return string.format(" [%d]", qty) end
end

local function updateDashboard(snap)
    if not snap then return end
    local dayStr  = tostring(snap.day or "-")
    local m       = snap.money or 0
    local moneyStr = "$"..tostring(m):reverse():gsub("(%d%d%d)", "%1."):reverse():gsub("^%.","")
    local repStr  = string.format("%.2f", snap.rep or 0)
    local custStr, servStr, angryStr = "-", "-", "-"
    local incStr, billStr, foodStr, tipStr = "-", "-", "-", "-"

    if snap.today then
        local t = snap.today
        custStr  = tostring(t.customers or 0)
        servStr  = tostring(t.served or 0)
        angryStr = tostring(t.angry or 0)
        if t.income then
            local billing = t.income.billing or 0
            local food    = t.income.food or 0
            local tip     = t.income.tip or 0
            local other   = t.income.other or 0
            local total   = billing + food + tip + other
            local function fmt(n)
                if n >= 1000000 then return string.format("$%.1fJt", n/1000000)
                elseif n >= 1000 then return string.format("$%.0fK", n/1000)
                else return "$"..n end
            end
            incStr=fmt(total); billStr=fmt(billing); foodStr=fmt(food); tipStr=fmt(tip)
        end
    end

    local sesCount, qCount = 0, 0
    if snap.sessions then for _ in pairs(snap.sessions) do sesCount=sesCount+1 end end
    if snap.queue then for _ in pairs(snap.queue) do qCount=qCount+1 end end

    pcall(function()
        ParaStats:SetDesc(string.format(
            "📅 Hari: %s  |  💵 Saldo: %s  |  ⭐ Rating: %s\n👥 Pelanggan: %s  |  ✅ Served: %s  |  😠 Kecewa: %s\n📈 Income: %s (Billing: %s | Makanan: %s | Tips: %s)\n🖥️ Sesi Aktif: %d  |  🕐 Antrean: %d",
            dayStr, moneyStr, repStr, custStr, servStr, angryStr,
            incStr, billStr, foodStr, tipStr, sesCount, qCount
        ))
    end)

    if snap.stock then
        local s = snap.stock
        local thr = cfg.stockThreshold
        pcall(function()
            ParaStock:SetDesc(string.format(
                "🍟 Snack%s\n🧊 Es Teh%s\n🥤 Soda%s\n☕ Kopi%s\n🍜 Mie/Nasi%s",
                stockLabel(s.snack or 0, thr), stockLabel(s.tea or 0, thr),
                stockLabel(s.soda or 0, thr), stockLabel(s.coffee or 0, thr),
                stockLabel(s.noodle or 0, thr)
            ))
        end)
        checkStockAlert(s)
    end
end

-- ══ TAB 3: TOKO KOTA ═════════════════════════════════════════════
local ParaTimer = Tabs.TokoKota:AddParagraph({
    Title="⏰ Jadwal Restock Toko Kota",
    Content="Stok baru dalam: Buka 1x toko dulu"
})

Tabs.TokoKota:AddButton({
    Title="🚀 Teleport ke Toko Terpilih",
    Description="Langsung pindah ke toko yang dipilih di bawah",
    Callback=function()
        local target = STORE_LOCATIONS[selectedStoreId]
        if target then safeTeleport(target) end
    end
})

local SecEsTeh = Tabs.TokoKota:AddSection("🥤 Es Teh Segar (Buff +60%)")
local ParaEsTeh = SecEsTeh:AddParagraph({ Title="Status Buff", Content="Mengecek..." })
SecEsTeh:AddDropdown("esTehChoiceDropdown", {
    Title="Pilih Menu Minuman",
    Values={"🧊 Es Teh Manis ($5.000 • 4 Jam)", "🍊 Es Jeruk ($7.000 • 5.5 Jam)"},
    Multi=false, Default=2,
    Callback=function(val) cfg.esTehChoice = ESTEH_DISPLAY_TO_ID[val] or "es_jeruk" end
})
addToggle(SecEsTeh, "autoEsTehEnabled", "Auto Beli Saat Buff Habis", nil, false)
SecEsTeh:AddButton({
    Title="🥤 Beli Sekarang (1x)",
    Callback=function() task.spawn(buyEsTeh, cfg.esTehChoice, false) end
})

local SecManualShop = Tabs.TokoKota:AddSection("🛍️ Beli Manual (Semua Toko)")
SecManualShop:AddDropdown("selectedManualStore", {
    Title="Pilih Toko",
    Values={"💻 Toko Komputer Jaya","🪑 Mebel Jati","🌿 Galeri Dekorasi","☕ Toko Alat Kafe","🛒 Minimart 24"},
    Multi=false, Default=1,
    Callback=function(val)
        selectedStoreId = STORE_DISPLAY_TO_ID[val] or "computer"
        refreshManualStoreSlots()
    end
})

for i = 1, MAX_SLOTS do
    StoreSlotButtons[i] = SecManualShop:AddButton({
        Title="Slot "..i,
        Description="Menunggu data toko...",
        Callback=function()
            local slotData = activeSlotItems[i]
            if slotData and slotData.id then
                if slotData.qty and slotData.qty <= 0 then
                    notify("❌ Stok Habis", slotData.name.." sudah habis!", 2)
                else
                    task.spawn(buySingleItemManual, selectedStoreId, slotData.id, slotData.priceStr or "")
                end
            else
                notify("Info Toko", "Buka UI tokonya dulu / tunggu reset.", 2.5)
            end
        end
    })
    if i > 4 then setFluentButtonState(StoreSlotButtons[i], "", "", false) end
end

-- ══ TAB 4: AUTO FARM ═════════════════════════════════════════════
local SecWarnet = Tabs.AutoFarm:AddSection("🏪 Otomatisasi Warnet")
addToggle(SecWarnet, "autoOpenEnabled", "Auto Buka Warnet", "Otomatis buka warnet kembali jika TUTUP", false, function(val)
    lastStatus = nil
    if val and getStatus() == "TUTUP" then
        task.delay(1, function() fireAction("setOpen", {open=true}) end)
    end
end)
addToggle(SecWarnet, "autoDayEnabled", "Auto Lanjut Hari", "Otomatis klik tombol lanjut hari (EN & ID)", false)
addToggle(SecWarnet, "autoPlaceEnabled", "Auto Tempatkan Pelanggan", "Otomatis arahkan antrean ke PC kosong", false)
addToggle(SecWarnet, "autoCleanEnabled", "Auto Bersih Sampah", nil, false)
addToggle(SecWarnet, "autoServeEnabled", "Auto Layani Semua Menu",
    "Masak & antar Mie Telur, Nasi Goreng, Snack, Kopi, Es Teh, Soda", false)

local SecDelay = Tabs.AutoFarm:AddSection("⏱️ Pengaturan Delay")
SecDelay:AddSlider("reopenDelay", {
    Title="Reopen Delay (detik)", Default=6, Min=1, Max=15, Rounding=0,
    Callback=function(val) if type(val)=="number" then cfg.reopenDelay=val end end
})
SecDelay:AddSlider("continueDelay", {
    Title="Continue Day Delay (detik)", Default=2, Min=1, Max=10, Rounding=0,
    Callback=function(val) if type(val)=="number" then cfg.continueDelay=val end end
})

local SecPlayer = Tabs.AutoFarm:AddSection("🏃 Player & Anti AFK")
addToggle(SecPlayer, "antiAfkEnabled", "🛡️ Anti AFK", nil, true)
addToggle(SecPlayer, "walkSpeedEnabled", "Custom WalkSpeed", nil, false, function(val)
    local hum = getHumanoid()
    if hum then hum.WalkSpeed = val and cfg.walkSpeedValue or 16 end
end)
SecPlayer:AddSlider("walkSpeedValue", {
    Title="Kecepatan Lari (WalkSpeed)", Default=32, Min=16, Max=150, Rounding=0,
    Callback=function(val)
        if type(val)=="number" then
            cfg.walkSpeedValue = val
            if cfg.walkSpeedEnabled then
                local hum = getHumanoid()
                if hum then hum.WalkSpeed = val end
            end
        end
    end
})

-- ══ TAB 5: SETTINGS ══════════════════════════════════════════════
local SecWebhook = Tabs.Settings:AddSection("🔔 Discord Webhook")
addToggle(SecWebhook, "webhookEnabled", "Kirim Notif Auto Buy", nil, false)
SecWebhook:AddInput("webhookUrlInput", {
    Title="Webhook URL", Default="",
    Placeholder="https://discord.com/api/webhooks/...",
    Numeric=false, Finished=false,
    Callback=function(val) if type(val)=="string" then cfg.webhookUrl=val end end
})
SecWebhook:AddButton({
    Title="📨 Test Kirim Webhook",
    Callback=function()
        task.spawn(function()
            local ok, msg = sendWebhook("✅ Webhook Terhubung!", "Warnetopia Hub siap kirim notif.", 5763719)
            notify(ok and "✅ Berhasil" or "❌ Gagal", msg, 3)
        end)
    end
})

if InterfaceManager then
    pcall(function()
        InterfaceManager:SetLibrary(Fluent)
        InterfaceManager:SetFolder("WarnetopiaHub_Fluent")
        InterfaceManager:BuildInterfaceSection(Tabs.Settings)
    end)
end

if SaveManager then
    pcall(function()
        SaveManager:SetLibrary(Fluent)
        SaveManager:SetFolder("WarnetopiaHub_Fluent/configs")
        SaveManager:IgnoreThemeSettings()
        SaveManager:SetIgnoreIndexes({ "selectedManualStore" })
        SaveManager:BuildConfigSection(Tabs.Settings)
        SaveManager:LoadAutoloadConfig()
    end)
end

Window:SelectTab(1)

-- ─── SYNC DARI GAME UI ────────────────────────────────────────────
local function resolveItemByDisplayName(rawName)
    if not rawName then return nil end
    local clean = rawName:gsub("%.%.%.", ""):lower():gsub("^%s+",""):gsub("%s+$","")
    if clean == "" then return nil end
    if BY_NAME[clean] then return BY_NAME[clean] end
    for nameLower, item in pairs(BY_NAME) do
        if nameLower:sub(1, #clean) == clean then return item end
    end
    return nil
end

local function syncFromGameUI()
    local gui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not gui then return end
    local ui = gui:FindFirstChild("WarnetopiaUI")
    if not ui then return end

    local detectedStoreId = nil
    local foundDiscNum    = nil

    for _, obj in ipairs(ui:GetDescendants()) do
        if obj:IsA("TextLabel") and obj.Visible then
            local txt = obj.Text or ""
            local mStr, sStr = txt:match("Stok baru dalam%s*(%d+):(%d+)")
            if mStr and sStr then
                restockEndClock = os.clock() + (tonumber(mStr)*60) + tonumber(sStr)
            end
            if txt:find("Harga toko") or txt:find("Diskon") or txt:match("^%-%d+%%$") then
                local pct = tonumber(txt:match("(%d+)%%"))
                if pct and pct > 0 and pct < 100 then foundDiscNum = pct end
            end
            if UI_TITLE_TO_STORE_ID[txt] then detectedStoreId = UI_TITLE_TO_STORE_ID[txt] end
        end
    end

    if foundDiscNum then discountPercent = foundDiscNum
    elseif detectedStoreId then discountPercent = 0 end

    if detectedStoreId then
        local cards = {}
        local seenParents = {}
        for _, obj in ipairs(ui:GetDescendants()) do
            if (obj:IsA("TextButton") or obj:IsA("TextLabel")) and obj.Visible then
                local t = obj.Text or ""
                if t=="Beli" or t=="Habis" or t=="Buy" or t=="Sold Out" then
                    local cardFrame = obj.Parent
                    while cardFrame and cardFrame:IsA("GuiObject") do
                        if cardFrame.AbsoluteSize.X>=85 and cardFrame.AbsoluteSize.X<=260 and cardFrame.AbsoluteSize.Y>=115 then break end
                        cardFrame = cardFrame.Parent
                    end
                    if cardFrame and not seenParents[cardFrame] then
                        seenParents[cardFrame] = true
                        local qtyNum = (t=="Habis" or t=="Sold Out") and 0 or nil
                        local bestTitle, bestY = nil, math.huge
                        local lowestPrice, highestPrice = nil, nil
                        for _, child in ipairs(cardFrame:GetDescendants()) do
                            if child:IsA("TextLabel") and child.Visible then
                                local ct = child.Text or ""
                                if ct:match("^Sisa%s*(%d+)") then
                                    qtyNum = tonumber(ct:match("^Sisa%s*(%d+)"))
                                elseif ct:match("^(%d+)%s*left") then
                                    qtyNum = tonumber(ct:match("^(%d+)%s*left"))
                                elseif ct:match("^%$[%d%.%,]+") then
                                    local parsed = parsePriceText(ct)
                                    if parsed then
                                        if not lowestPrice or parsed < lowestPrice then lowestPrice = parsed end
                                        if not highestPrice or parsed > highestPrice then highestPrice = parsed end
                                    end
                                elseif ct ~= "" and ct ~= "Beli" and ct ~= "Habis" and ct ~= "Buy" and ct ~= "Sold Out"
                                    and not ct:match("^x%d+") and not ct:match("^T%d+$")
                                    and not ct:find("Rare") and not ct:find("Tip") then
                                    if child.AbsolutePosition.Y < bestY then
                                        bestY = child.AbsolutePosition.Y
                                        bestTitle = ct
                                    end
                                end
                            end
                        end

                        local cardDisc = discountPercent
                        if highestPrice and lowestPrice and highestPrice > lowestPrice then
                            cardDisc = math.floor(((highestPrice-lowestPrice)/highestPrice)*100+0.5)
                            if cardDisc > 0 and discountPercent == 0 then discountPercent = cardDisc end
                        end

                        if bestTitle then
                            table.insert(cards, {
                                x=cardFrame.AbsolutePosition.X, y=cardFrame.AbsolutePosition.Y,
                                title=bestTitle, qty=qtyNum or 0, price=lowestPrice, discPct=cardDisc
                            })
                        end
                    end
                end
            end
        end

        if #cards > 0 then
            table.sort(cards, function(a,b)
                if math.abs(a.y-b.y)>25 then return a.y<b.y end
                return a.x<b.x
            end)

            storeOrderedUI[detectedStoreId] = storeOrderedUI[detectedStoreId] or {}
            local existingMap = {}
            for idx, oldEntry in ipairs(storeOrderedUI[detectedStoreId]) do
                if oldEntry.id then existingMap[oldEntry.id] = idx end
            end

            for _, c in ipairs(cards) do
                local resolved = resolveItemByDisplayName(c.title)
                local itemId = resolved and resolved.id or nil
                local displayName = (resolved and resolved.name) or c.title
                local basePrice = resolved and resolved.price
                local finalPrice = c.price or basePrice
                local pStr = finalPrice and formatShortPrice(finalPrice) or ""
                local newEntry = { id=itemId, name=displayName, qty=c.qty, basePrice=basePrice, priceStr=pStr, discPct=c.discPct }
                if itemId and existingMap[itemId] then
                    storeOrderedUI[detectedStoreId][existingMap[itemId]] = newEntry
                else
                    table.insert(storeOrderedUI[detectedStoreId], newEntry)
                    if itemId then existingMap[itemId] = #storeOrderedUI[detectedStoreId] end
                end
            end

            if selectedStoreId == detectedStoreId then refreshManualStoreSlots() end
        end
    end
end

-- ─── AUTO BUY LOGIC ───────────────────────────────────────────────
local function rareItemMatches(item)
    if not item then return false end
    local r = item.rarity or "biasa"
    local wantLangka = cfg.rarityLangka and r == "langka"
    local wantSangat = cfg.raritySangat and r == "sangat_langka"
    if not wantLangka and not wantSangat then return false end
    if item.tier ~= nil and cfg.minTier and cfg.minTier > 0 then
        local tier = tonumber(item.tier)
        if tier and tier < cfg.minTier then return false end
    end
    return true
end

local function processSnap(snap)
    if not snap then return end
    latestSnap = snap
    task.spawn(function() pcall(updateDashboard, snap) end)

    if cfg.autoPlaceEnabled then
        task.spawn(function() pcall(processAutoPlace) end)
    end

    if not snap.shops then return end

    for k, v in pairs(snap.shops) do
        if type(v) == "number" and v > 0 then
            if v > 1000000 then
                local rem = v - workspace:GetServerTimeNow()
                if rem > 0 and rem < 3600 then restockEndClock = os.clock() + rem end
            elseif v <= 600 then
                restockEndClock = os.clock() + v
            end
        end
    end

    refreshManualStoreSlots()

    if (not cfg.autoBuyEnabled and not cfg.autoMinimartEnabled) or isBuying or isCleaning or isServing then return end
    if os.clock() - lastBuyCooldown < 4 then return end

    local purchaseQueue = {}

    for storeId, shelf in pairs(snap.shops.shelves or {}) do
        if storeId == "minimart" and cfg.autoMinimartEnabled then
            for itemId, qty in pairs(shelf) do
                if qty and qty > 0 then
                    purchaseQueue[storeId] = purchaseQueue[storeId] or {}
                    table.insert(purchaseQueue[storeId], { id=itemId, qty=qty })
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
                            table.insert(purchaseQueue[storeId], { id=itemId, qty=qty })
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
            safeTeleport(targetCFrame)
            task.wait(0.45)
            for _, itemData in ipairs(items) do
                local stillEnabled = (storeId=="minimart" and cfg.autoMinimartEnabled)
                                  or (storeId~="minimart" and cfg.autoBuyEnabled)
                if not stillEnabled then break end
                local boughtCount = 0
                for i = 1, itemData.qty do
                    fireAction("storeBuy", { store=storeId, item=itemData.id })
                    boughtCount = boughtCount + 1
                    task.wait(0.25)
                end
                if boughtCount > 0 then
                    local itemInfo = BY_ID[itemData.id]
                    local itemName = (itemInfo and itemInfo.name) or itemData.id
                    local rarityTag = (itemInfo and itemInfo.rarity=="sangat_langka" and " [★★]")
                                   or (itemInfo and itemInfo.rarity=="langka" and " [★]") or ""
                    table.insert(boughtLog, string.format("• **%s**%s (x%d) — *%s*",
                        itemName, rarityTag, boughtCount, STORE_ID_TO_NAME[storeId] or storeId))
                end
            end
        end
    end

    task.wait(0.2)
    returnToOrigin(originalCFrame)
    isBuying = false

    if cfg.webhookEnabled and #boughtLog > 0 then
        task.spawn(sendWebhook, "🛒 Laporan Auto Buy Warnetopia", table.concat(boughtLog, "\n"), 15844367)
    end
end

Snapshot.OnClientEvent:Connect(function(snap)
    task.spawn(processSnap, snap)
end)

-- ─── MAIN HEARTBEAT ───────────────────────────────────────────────
local uiTimer    = 0
local checkTimer = 0
local placeTimer = 0
local cleanTimer = 0
local serveTimer = 0
local esTehTimer = 0

RunService.Heartbeat:Connect(function(dt)
    if cfg.walkSpeedEnabled then
        local hum = getHumanoid()
        if hum and hum.WalkSpeed ~= cfg.walkSpeedValue then
            hum.WalkSpeed = cfg.walkSpeedValue
        end
    end

    if cfg.autoPlaceEnabled then
        placeTimer = placeTimer + dt
        if placeTimer >= 0.6 then
            placeTimer = 0
            task.spawn(function() pcall(processAutoPlace) end)
        end
    end

    if cfg.autoServeEnabled then
        serveTimer = serveTimer + dt
        if serveTimer >= 1.2 then
            serveTimer = 0
            task.spawn(function() pcall(processAutoServeAll) end)
        end
    end

    if cfg.autoCleanEnabled then
        cleanTimer = cleanTimer + dt
        if cleanTimer >= 1.5 then
            cleanTimer = 0
            task.spawn(function() pcall(processAutoClean) end)
        end
    end

    esTehTimer = esTehTimer + dt
    if esTehTimer >= 1.0 then
        esTehTimer = 0
        local ok, buffTxt = pcall(getFreshBuffText)
        if ok and buffTxt then
            pcall(function() ParaEsTeh:SetDesc("⚡ Aktif: "..buffTxt) end)
        else
            pcall(function() ParaEsTeh:SetDesc("💤 Status Buff: Tidak aktif / Habis") end)
            if cfg.autoEsTehEnabled and not isBuying and not isCleaning and not isServing
                and (os.clock() - lastEsTehCooldown >= 6) then
                lastEsTehCooldown = os.clock()
                task.spawn(buyEsTeh, cfg.esTehChoice, true)
            end
        end
    end

    uiTimer = uiTimer + dt
    if uiTimer >= 0.5 then
        uiTimer = 0
        pcall(syncFromGameUI)
        if restockEndClock then
            local rem = restockEndClock - os.clock()
            if rem > 0 then
                pcall(function() ParaTimer:SetDesc("Stok baru dalam: "..formatTime(rem)) end)
            else
                table.clear(storeOrderedUI)
                pcall(function() ParaTimer:SetDesc("Sedang Restock (00:00)...") end)
            end
        end
    end

    if not cfg.autoOpenEnabled and not cfg.autoDayEnabled then
        lastStatus = nil return
    end

    checkTimer = checkTimer + dt
    if checkTimer < 2 then return end
    checkTimer = 0

    local dayBtn = cfg.autoDayEnabled and getDayReportButton() or nil
    if dayBtn and not continuePending then
        continuePending = true
        task.spawn(function()
            task.wait(cfg.continueDelay)
            local btn = getDayReportButton()
            if cfg.autoDayEnabled and btn then
                clickGuiButton(btn)
                fireAction("dayContinue", {})
                task.wait(cfg.reopenDelay)
                if cfg.autoOpenEnabled and getStatus() == "TUTUP" then
                    fireAction("setOpen", {open=true})
                end
            end
            continuePending = false
        end)
        return
    end

    if not cfg.autoOpenEnabled then lastStatus = nil return end

    local status = getStatus()
    if not status then return end

    if lastStatus == "BUKA" and status == "TUTUP" and not reopenPending then
        reopenPending = true
        task.spawn(function()
            task.wait(cfg.reopenDelay)
            if cfg.autoOpenEnabled and getStatus() == "TUTUP" then
                fireAction("setOpen", {open=true})
            end
            reopenPending = false
        end)
    end

    if status == "TUTUP" and lastStatus == nil and not reopenPending then
        reopenPending = true
        task.spawn(function()
            task.wait(1)
            if cfg.autoOpenEnabled and getStatus() == "TUTUP" then
                fireAction("setOpen", {open=true})
            end
            reopenPending = false
        end)
    end

    lastStatus = status
end)

-- ─── MOBILE TOGGLE BUTTON ────────────────────────────────────────
if isMobile then
    local MobileGui = Instance.new("ScreenGui")
    MobileGui.Name           = "MobileToggle"
    MobileGui.ResetOnSpawn   = false
    MobileGui.DisplayOrder   = 99999
    MobileGui.IgnoreGuiInset = true
    MobileGui.Parent         = pg

    local Btn = Instance.new("TextButton")
    Btn.Name                   = "ToggleBtn"
    Btn.Size                   = UDim2.fromOffset(48, 48)
    Btn.Position               = UDim2.new(0, 8, 0.5, -24)
    Btn.BackgroundColor3       = Color3.fromRGB(20, 20, 30)
    Btn.BackgroundTransparency = 0.1
    Btn.BorderSizePixel        = 0
    Btn.Text                   = "🖤"
    Btn.TextSize               = 22
    Btn.Font                   = Enum.Font.GothamBold
    Btn.ZIndex                 = 99999
    Btn.AutoButtonColor        = false
    Btn.Parent                 = MobileGui

    Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 14)
    local stroke = Instance.new("UIStroke", Btn)
    stroke.Color = Color3.fromRGB(110, 90, 210)
    stroke.Thickness = 2

    local isDragging  = false
    local startTouch  = Vector2.zero
    local startBtnPos = UDim2.new()
    local touchActive = false

    Btn.InputBegan:Connect(function(inp)
        if inp.UserInputType ~= Enum.UserInputType.Touch then return end
        touchActive = true
        isDragging  = false
        startTouch  = Vector2.new(inp.Position.X, inp.Position.Y)
        startBtnPos = Btn.Position
        inp:GetPropertyChangedSignal("Delta"):Connect(function()
            if not touchActive then return end
            local cur = Vector2.new(inp.Position.X, inp.Position.Y)
            local delta = cur - startTouch
            if delta.Magnitude > 10 then
                isDragging = true
                Btn.Position = UDim2.new(
                    startBtnPos.X.Scale, startBtnPos.X.Offset + delta.X,
                    startBtnPos.Y.Scale, startBtnPos.Y.Offset + delta.Y
                )
            end
        end)
    end)

    Btn.InputEnded:Connect(function(inp)
        if inp.UserInputType ~= Enum.UserInputType.Touch then return end
        touchActive = false
        if not isDragging then
            pcall(function() Window:Minimize() end)
        end
        isDragging = false
    end)
end

notify("Warnetopia Hub 🖤", "Loaded! | by Realx13", 4)
print("[Hub] 🖤 Warnetopia Hub Fluent loaded!")
