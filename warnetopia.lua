--[[
    Warnetopia Hub — Full Script
    UI: LinoriaLib
    Features:
    ✅ Auto Buy Rare Items (Komputer, Mebel, Dekorasi) + Safe Teleport Return
    ✅ Auto Restock Minimart
    ✅ Manual Buy Semua Toko
    ✅ Auto Buka Warnet
    ✅ Auto Lanjut Hari (Multi-root UI + VirtualInputManager Click)
    ✅ Auto Tempatkan Pelanggan
    ✅ Auto Bersih Sampah
    ✅ Auto Layani Semua Menu (Mie Telur, Nasi Goreng, Snack, Kopi, Es Teh, Soda)
    ✅ Auto Buff Es Teh Segar
    ✅ Stats Dashboard Real-Time (snap.today.income, snap.today.served, snap.rep)
    ✅ Low Stock Alert (< 10) + Auto Restock Stok Kafe (+10 via snap.stock)
    ✅ WalkSpeed Custom & Anti AFK
    ✅ Save/Load Config (Autoload)
    Credit: Realx13
--]]

-- ─── LOAD LINORIA ─────────────────────────────────────────────────
local repo         = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'
local Library      = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager  = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()

-- ─── SERVICES ─────────────────────────────────────────────────────
local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local RunService          = game:GetService("RunService")
local VirtualUser         = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")
local HttpService         = game:GetService("HttpService")
local LocalPlayer         = Players.LocalPlayer

local httpRequest = (syn and syn.request) or (http and http.request) or http_request or request

-- ─── REMOTES ──────────────────────────────────────────────────────
local Remotes  = ReplicatedStorage:WaitForChild("Remotes", 10)
local Action   = Remotes:WaitForChild("Action", 10)
local Snapshot = Remotes:WaitForChild("Snapshot", 10)

-- ─── CATALOG ──────────────────────────────────────────────────────
local Catalog = require(ReplicatedStorage.Shared.Data.Catalog)
local BY_ID   = {}
local BY_NAME = {}
for _, item in ipairs(Catalog.ITEMS) do
    BY_ID[item.id] = item
    if item.name then BY_NAME[item.name:lower()] = item end
end

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

local CAFE_ITEM_LABELS = {
    noodle       = "Mie Telur",
    stock_noodle = "Mie Telur",
    rice         = "Nasi Goreng",
    stock_rice   = "Nasi Goreng",
    snack        = "Snack",
    stock_snack  = "Snack",
    coffee       = "Kopi Hitam",
    stock_coffee = "Kopi Hitam",
    tea          = "Es Teh",
    stock_tea    = "Es Teh",
    soda         = "Soda",
    stock_soda   = "Soda",
}

local CAFE_KEY_TO_STOCK_ID = {
    soda   = "stock_soda",
    noodle = "stock_noodle",
    coffee = "stock_coffee",
    rice   = "stock_rice",
    tea    = "stock_tea",
    snack  = "stock_snack",
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
    ["mie telur"]   = { cook = "Buat Mie Telur",  station = "stove",          switchNeeded = false },
    ["nasi goreng"] = { cook = "Buat Nasi Goreng", station = "stove",          switchNeeded = true  },
    ["snack"]       = { cook = "Buat Snack",       station = "snack_rack",     switchNeeded = false },
    ["kopi hitam"]  = { cook = "Buat Kopi Hitam",  station = "coffee_machine", switchNeeded = false },
    ["es teh"]      = { cook = "Buat Es Teh",      station = "fridge",         switchNeeded = false },
    ["soda"]        = { cook = "Buat Soda",        station = "fridge",         switchNeeded = true  },
}

local DELIVER_ACTIONS = {
    "Antar Mie Telur", "Antar Nasi Goreng", "Antar Snack",
    "Antar Kopi Hitam", "Antar Es Teh", "Antar Soda",
}

local RARE_STORE_MAP = {
    computer  = "store_computer",
    furniture = "store_furniture",
    decor     = "store_decor",
}

local MAX_SLOTS = 15

-- ─── CONFIG ───────────────────────────────────────────────────────
local cfg = {
    autoBuyEnabled         = false,
    autoMinimartEnabled    = false,
    autoOpenEnabled        = false,
    autoDayEnabled         = false,
    autoPlaceEnabled       = false,
    autoCleanEnabled       = false,
    autoServeEnabled       = false,
    autoEsTehEnabled       = false,
    esTehChoice            = "es_jeruk",
    lowStockAlertGui       = true,
    lowStockWebhook        = true,
    autoRestockCafeEnabled = false,
    lowStockThreshold      = 10,
    walkSpeedEnabled       = false,
    walkSpeedValue         = 32,
    antiAfkEnabled         = true,
    webhookUrl             = "",
    webhookEnabled         = false,
    store_computer         = true,
    store_furniture        = true,
    store_decor            = true,
    minTier                = 3,
    rarityLangka           = true,
    raritySangat           = true,
    reopenDelay            = 6,
    continueDelay          = 1.5,
}

-- ─── STATE ────────────────────────────────────────────────────────
local lastStatus            = nil
local reopenPending         = false
local continuePending       = false
local isBuying              = false
local isCleaning            = false
local isServing             = false
local lastBuyCooldown       = 0
local lastEsTehCooldown     = 0
local lastCafeRestockClock  = 0
local latestSnap            = nil
local restockEndClock       = nil
local discountPercent       = 0
local assignedCooldowns     = {}
local selectedStoreId       = "computer"
local storeOrderedUI        = {}
local activeSlotItems       = {}
local lowStockNotified      = {}
local lastLowStockGuiMsg    = ""

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

local function safeTeleport(targetCFrame)
    local hrp = getHRP()
    local hum = getHumanoid()
    if not hrp or not targetCFrame then return end
    if hum and hum.Sit then
        hum.Sit = false
        task.wait(0.05)
    end
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.CFrame = targetCFrame
end

local function returnToOrigin(origCFrame)
    if not origCFrame then return end
    safeTeleport(origCFrame)
    task.wait(0.12)
    safeTeleport(origCFrame)
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
    if firesignal then
        pcall(function() firesignal(btn.MouseButton1Down) end)
        pcall(function() firesignal(btn.MouseButton1Click) end)
        pcall(function() firesignal(btn.Activated) end)
    end
    if btn:IsA("GuiObject") and btn.Visible then
        local pos = btn.AbsolutePosition
        local sz  = btn.AbsoluteSize
        local cx  = pos.X + (sz.X * 0.5)
        local cy  = pos.Y + (sz.Y * 0.5)
        pcall(function()
            VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, true, game, 1)
            task.wait(0.05)
            VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, false, game, 1)
        end)
    end
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

local function formatMoneyFull(num)
    if type(num) ~= "number" then return "$0" end
    local formatted = tostring(math.floor(num + 0.5))
    while true do
        local k
        formatted, k = formatted:gsub("^(-?%d+)(%d%d%d)", "%1.%2")
        if k == 0 then break end
    end
    return "$" .. formatted
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

-- ─── HELPER: Status warnet ────────────────────────────────────────
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
            if t == "BUKA" or t == "OPEN"  then return "BUKA"
            elseif t == "TUTUP" or t == "CLOSED" then return "TUTUP" end
        end
    end
    return nil
end

-- ─── HELPER: DayReport button ─────────────────────────────────────
local function getDayReportButton()
    for _, root in ipairs(getAllGuiRoots()) do
        for _, obj in ipairs(root:GetDescendants()) do
            if (obj:IsA("TextButton") or obj:IsA("TextLabel")) then
                local txt = tostring(obj.Text or "")
                if txt:find("Lanjut ke Hari", 1, true) or txt:match("^Lanjut%s+ke%s+Hari") then
                    local btn = obj:IsA("GuiButton") and obj or obj:FindFirstAncestorWhichIsA("GuiButton")
                    if btn and isGuiTrulyVisible(btn) then
                        return btn
                    end
                end
            end
        end
    end
    return nil
end

-- ─── HELPER: Es Teh Buff ──────────────────────────────────────────
local function getFreshBuffText()
    local gui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not gui then return nil end
    local ok, tl = pcall(function() return gui.WarnetopiaUI.Root.TL end)
    if not ok or not tl then return nil end
    for _, obj in ipairs(tl:GetDescendants()) do
        if obj:IsA("TextLabel") and obj.Visible then
            local txt = (obj.Text or ""):gsub("<[^>]+>", " "):gsub("%s+", " "):gsub("^%s+",""):gsub("%s+$","")
            if txt:lower():find("segar") or txt:lower():find("fresh for") then
                return txt:gsub("^[^%w]+", "")
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

    pcall(function()
        safeTeleport(STORE_LOCATIONS.esteh)
        task.wait(0.45)
        fireAction("eat", { item = itemId, warung = "esteh" })
        Library:Notify((isAuto and "🥤 Auto Buff: " or "✅ ") .. (ESTEH_ID_TO_LABEL[itemId] or itemId), 2.5)
        task.wait(0.3)
    end)

    returnToOrigin(orig)
    isBuying = false
    return true
end

-- ─── HELPER: Proximity Prompts ────────────────────────────────────
local function findCookPrompt(stationName, cookAction)
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.Enabled then
            if (obj.Parent and obj.Parent.Name) == stationName and obj.ActionText == cookAction then
                local p = obj.Parent
                if p and (p:IsA("BasePart") or p:IsA("Model")) then
                    return obj, p
                end
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
                if p and (p:IsA("BasePart") or p:IsA("Model")) then
                    return obj, p
                end
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

    local foodKey  = (deliverAction:match("^Antar%s+(.+)$") or ""):lower()
    local foodInfo = FOOD_MAP[foodKey]
    local hrp      = getHRP()
    if not hrp then return end

    isServing = true
    local originalCFrame = hrp.CFrame
    local needSwitchBack = false

    pcall(function()
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
    end)

    if not isBuying and not isCleaning then
        returnToOrigin(originalCFrame)
    end

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

    pcall(function()
        for _, item in ipairs(trashList) do
            if not cfg.autoCleanEnabled or isBuying or isServing then break end
            local prompt, part = item.prompt, item.part
            if prompt and prompt.Parent and prompt.Enabled and part and part.Parent then
                local curHrp = getHRP()
                if curHrp then
                    tpToPart(curHrp, part)
                    triggerPromptSafe(prompt)
                    task.wait((prompt.HoldDuration or 0) + 0.35)
                end
            end
        end
    end)

    if not isBuying and not isServing then
        returnToOrigin(orig)
    end
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
        if (obj:IsA("TextButton") or obj:IsA("TextLabel")) and obj.Text == "Otomatis" then
            local btn = obj:IsA("GuiButton") and obj or obj:FindFirstAncestorWhichIsA("GuiButton")
            if btn and isGuiTrulyVisible(btn) then clickGuiButton(btn) return end
        end
    end

    local topBtn, topY = nil, math.huge
    for _, obj in ipairs(ui:GetDescendants()) do
        if (obj:IsA("TextButton") or obj:IsA("TextLabel")) and obj.Text == "Tempatkan" then
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
local function setButtonState(btnObj, newText, isVisible)
    if not btnObj then return end
    pcall(function()
        local container = btnObj.Container
        if container and container:IsA("GuiObject") then
            container.Visible = isVisible
        end
        local lbl = btnObj.Label
        if not lbl and container then
            for _, d in ipairs(container:GetDescendants()) do
                if d:IsA("TextLabel") then lbl = d break end
            end
        end
        if lbl and lbl:IsA("TextLabel") then
            lbl.Text = newText
            lbl.TextScaled = true
            local c = lbl:FindFirstChildOfClass("UITextSizeConstraint")
            if not c then c = Instance.new("UITextSizeConstraint") c.Parent = lbl end
            c.MaxTextSize = 15
            c.MinTextSize = 12
        end
    end)
end

local function buildButtonLabel(name, qty, priceStr, discPct)
    local statusStr = qty > 0 and ("x"..qty) or "HABIS"
    local discTag   = (discPct and discPct > 0) and string.format(" (-%d%%)", discPct) or ""
    local pricePart = (priceStr and priceStr ~= "") and (" • "..priceStr..discTag) or discTag
    return string.format("%s (%s)%s", name, statusStr, pricePart)
end

local StoreSlotButtons = {}

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
            local liveQty = (entry.id and snapShelf and snapShelf[entry.id] ~= nil) and snapShelf[entry.id] or entry.qty
            entry.qty = liveQty
            local itemDisc = (discountPercent > 0) and discountPercent or (entry.discPct or 0)
            local finalPriceStr = entry.priceStr
            if entry.basePrice and itemDisc > 0 then
                finalPriceStr = formatShortPrice(math.floor(entry.basePrice * (1 - itemDisc/100) + 0.5))
            end
            table.insert(finalItems, { id=entry.id, name=entry.name, qty=liveQty, priceStr=finalPriceStr, discPct=itemDisc })
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
            local finalPriceStr = basePrice and formatShortPrice(math.floor(basePrice * mult + 0.5)) or ""
            table.insert(finalItems, { id=itemId, name=displayName, qty=qty, priceStr=finalPriceStr, discPct=discountPercent })
        end
    end

    if #finalItems > 0 then
        for i = 1, MAX_SLOTS do
            local item = finalItems[i]
            if item then
                activeSlotItems[i] = item
                setButtonState(StoreSlotButtons[i], buildButtonLabel(item.name, item.qty, item.priceStr, item.discPct), true)
            else
                setButtonState(StoreSlotButtons[i], "", false)
            end
        end
    else
        for i = 1, MAX_SLOTS do
            if i <= 4 then
                setButtonState(StoreSlotButtons[i], string.format("Slot %d: Buka toko dulu / tunggu reset", i), true)
            else
                setButtonState(StoreSlotButtons[i], "", false)
            end
        end
    end
end

local function buySingleItemManual(storeId, itemId, priceStr)
    if isBuying or isCleaning or isServing then
        Library:Notify("Sedang proses aksi lain, tunggu sebentar...", 2)
        return
    end
    local hrp = getHRP()
    local targetCFrame = STORE_LOCATIONS[storeId]
    if not hrp or not targetCFrame then return end

    isBuying = true
    local orig = hrp.CFrame
    local itemInfo = BY_ID[itemId]
    local itemName = (itemInfo and itemInfo.name) or itemId

    pcall(function()
        safeTeleport(targetCFrame)
        task.wait(0.45)
        fireAction("storeBuy", { store=storeId, item=itemId })
        Library:Notify("✅ Membeli: "..itemName..(priceStr~="" and " ("..priceStr..")" or ""), 2.5)
        task.wait(0.35)
    end)

    returnToOrigin(orig)
    isBuying = false
end

-- ─── BUILD LINORIA UI ─────────────────────────────────────────────
local Window = Library:CreateWindow({
    Title    = 'Warnetopia Hub 🖤',
    Center   = true,
    AutoShow = true,
    Size     = UDim2.fromOffset(780, 710),
})

-- ══ TAB 1: AUTO BUY ══════════════════════════════════════════════
local BuyTab  = Window:AddTab('Auto Buy')
local BuyBox  = BuyTab:AddLeftGroupbox('⚙️ Auto Buy Rare')

BuyBox:AddToggle('autoBuyEnabled', {
    Text='Auto Buy Rare ON/OFF', Default=false,
    Tooltip='Aktifkan auto beli item langka dari toko kota',
    Callback=function(val) cfg.autoBuyEnabled = val end,
})
BuyBox:AddSlider('minTier', {
    Text='Minimum Tier', Min=1, Max=4, Default=3, Rounding=0,
    Tooltip='Hanya beli item dengan tier >= ini',
    Callback=function(val) cfg.minTier = val end,
})

local RarityBox = BuyTab:AddLeftGroupbox('✨ Rarity Filter')
RarityBox:AddToggle('rarityLangka', {
    Text='Langka (★)', Default=true,
    Callback=function(val) cfg.rarityLangka = val end,
})
RarityBox:AddToggle('raritySangat', {
    Text='Sangat Langka (★★)', Default=true,
    Callback=function(val) cfg.raritySangat = val end,
})

local TokoBox = BuyTab:AddRightGroupbox('🏪 Toko Rare Items')
TokoBox:AddToggle('store_computer', {
    Text='💻 Toko Komputer Jaya', Default=true,
    Callback=function(val) cfg.store_computer = val end,
})
TokoBox:AddToggle('store_furniture', {
    Text='🪑 Mebel Jati', Default=true,
    Callback=function(val) cfg.store_furniture = val end,
})
TokoBox:AddToggle('store_decor', {
    Text='🌿 Galeri Dekorasi', Default=true,
    Callback=function(val) cfg.store_decor = val end,
})

local MinimartBox = BuyTab:AddRightGroupbox('🛒 Minimart 24')
MinimartBox:AddToggle('autoMinimartEnabled', {
    Text='Auto Restock Minimart', Default=false,
    Tooltip='Borong semua stok di Minimart 24',
    Callback=function(val) cfg.autoMinimartEnabled = val end,
})

-- ══ TAB 2: TOKO KOTA ═════════════════════════════════════════════
local CafeTab  = Window:AddTab('Toko Kota')
local TimerBox = CafeTab:AddLeftGroupbox('⏰ Jadwal Restock')
local RestockTimerLabel = TimerBox:AddLabel('Stok baru dalam: Buka 1x toko dulu')
TimerBox:AddDivider()
TimerBox:AddLabel('Semua toko kota reset bersamaan saat timer 00:00', true)
TimerBox:AddDivider()
TimerBox:AddButton({
    Text='🚀 TP ke Toko Terpilih',
    Func=function()
        local target = STORE_LOCATIONS[selectedStoreId]
        if target then safeTeleport(target) end
    end,
    Tooltip='Teleport ke toko yang dipilih di kanan',
})

local EsTehBox = CafeTab:AddLeftGroupbox('🥤 Es Teh Segar (Buff +60%)')
local EsTehStatusLabel = EsTehBox:AddLabel('Status Buff: Mengecek...')
EsTehBox:AddDropdown('esTehChoiceDropdown', {
    Values={'🧊 Es Teh Manis ($5.000 • 4 Jam)','🍊 Es Jeruk ($7.000 • 5.5 Jam)'},
    Default=2, Multi=false, Text='Pilih Menu:',
    Callback=function(val) cfg.esTehChoice = ESTEH_DISPLAY_TO_ID[val] or "es_jeruk" end,
})
EsTehBox:AddToggle('autoEsTehEnabled', {
    Text='Auto Beli Saat Buff Habis', Default=false,
    Callback=function(val) cfg.autoEsTehEnabled = val end,
})
EsTehBox:AddButton({
    Text='🥤 Beli Sekarang (1x)',
    Func=function() task.spawn(buyEsTeh, cfg.esTehChoice, false) end,
})

local LowStockBox = CafeTab:AddLeftGroupbox('⚠️ Low Stock Alert (Menu Kafe)')
local LowStockStatusLabel = LowStockBox:AddLabel('✅ Semua stok menu kafe aman')
LowStockBox:AddSlider('lowStockThreshold', {
    Text='Batas Minimum Stok', Min=1, Max=50, Default=10, Rounding=0,
    Tooltip='Kirim peringatan & beli +10 di WarnetOS jika stok menu kafe di bawah angka ini',
    Callback=function(val)
        cfg.lowStockThreshold = val
        table.clear(lowStockNotified)
    end,
})
LowStockBox:AddToggle('lowStockAlertGui', {
    Text='Warning di GUI & Notif', Default=true,
    Callback=function(val) cfg.lowStockAlertGui = val end,
})
LowStockBox:AddToggle('lowStockWebhook', {
    Text='Kirim Alert ke Discord', Default=true,
    Callback=function(val) cfg.lowStockWebhook = val end,
})
LowStockBox:AddToggle('autoRestockCafeEnabled', {
    Text='Auto Beli Stok Kafe (+10)', Default=false,
    Tooltip='Otomatis beli +10 stok via WarnetOS di background tanpa TP jika stok di bawah batas minimum',
    Callback=function(val)
        cfg.autoRestockCafeEnabled = val
        lastCafeRestockClock = 0
    end,
})

local ManualShopBox = CafeTab:AddRightGroupbox('🛍️ Beli Manual (Semua Toko)')
ManualShopBox:AddDropdown('selectedManualStore', {
    Values={'💻 Toko Komputer Jaya','🪑 Mebel Jati','🌿 Galeri Dekorasi','☕ Toko Alat Kafe','🛒 Minimart 24'},
    Default=1, Multi=false, Text='Pilih Toko:',
    Callback=function(val)
        selectedStoreId = STORE_DISPLAY_TO_ID[val] or "computer"
        refreshManualStoreSlots()
    end,
})
ManualShopBox:AddDivider()

for i = 1, MAX_SLOTS do
    StoreSlotButtons[i] = ManualShopBox:AddButton({
        Text=('Slot %d: Menunggu data...'):format(i),
        Func=function()
            local slotData = activeSlotItems[i]
            if slotData and slotData.id then
                if slotData.qty and slotData.qty <= 0 then
                    Library:Notify("❌ Stok "..slotData.name.." sudah HABIS!", 2)
                else
                    task.spawn(buySingleItemManual, selectedStoreId, slotData.id, slotData.priceStr or "")
                end
            else
                Library:Notify("Buka UI tokonya dulu / tunggu reset.", 2.5)
            end
        end,
        Tooltip='Klik untuk TP & beli item ini 1x',
    })
    if i > 4 then setButtonState(StoreSlotButtons[i], "", false)
    else setButtonState(StoreSlotButtons[i], ('Slot %d: Menunggu data...'):format(i), true) end
end

-- ══ TAB 3: AUTO OPEN & WARNET ════════════════════════════════════
local OpenTab = Window:AddTab('Auto Farm')
local OpenBox = OpenTab:AddLeftGroupbox('🏪 Warnet')

OpenBox:AddToggle('autoOpenEnabled', {
    Text='Auto Buka Warnet', Default=false,
    Tooltip='Otomatis buka warnet kalau tiba-tiba TUTUP',
    Callback=function(val)
        cfg.autoOpenEnabled = val
        lastStatus = nil
        if val and getStatus() == "TUTUP" then
            task.delay(1, function() fireAction("setOpen", {open=true}) end)
        end
    end,
})
OpenBox:AddToggle('autoDayEnabled', {
    Text='Auto Lanjut Hari', Default=false,
    Tooltip='Otomatis pencet "Lanjut ke Hari X" saat popup muncul',
    Callback=function(val) cfg.autoDayEnabled = val end,
})
OpenBox:AddToggle('autoPlaceEnabled', {
    Text='Auto Tempatkan Pelanggan', Default=false,
    Callback=function(val) cfg.autoPlaceEnabled = val end,
})
OpenBox:AddToggle('autoCleanEnabled', {
    Text='Auto Bersih Sampah', Default=false,
    Callback=function(val) cfg.autoCleanEnabled = val end,
})
OpenBox:AddToggle('autoServeEnabled', {
    Text='Auto Layani Semua Menu', Default=false,
    Tooltip='Otomatis masak & antar: Mie Telur, Nasi Goreng, Snack, Kopi, Es Teh, Soda',
    Callback=function(val) cfg.autoServeEnabled = val end,
})

local DelayBox = OpenTab:AddLeftGroupbox('⏱️ Delay')
DelayBox:AddSlider('reopenDelay', {
    Text='Reopen Delay (detik)', Min=1, Max=15, Default=6, Rounding=0,
    Callback=function(val) cfg.reopenDelay = val end,
})
DelayBox:AddSlider('continueDelay', {
    Text='Continue Delay (detik)', Min=1, Max=10, Default=2, Rounding=0,
    Callback=function(val) cfg.continueDelay = val end,
})

local PlayerBox = OpenTab:AddRightGroupbox('🏃 Player & AFK')
PlayerBox:AddToggle('antiAfkEnabled', {
    Text='🛡️ Anti AFK', Default=true,
    Callback=function(val) cfg.antiAfkEnabled = val end,
})
PlayerBox:AddDivider()
PlayerBox:AddToggle('walkSpeedEnabled', {
    Text='Custom WalkSpeed', Default=false,
    Callback=function(val)
        cfg.walkSpeedEnabled = val
        local hum = getHumanoid()
        if hum then hum.WalkSpeed = val and cfg.walkSpeedValue or 16 end
    end,
})
PlayerBox:AddSlider('walkSpeedValue', {
    Text='WalkSpeed', Min=16, Max=150, Default=32, Rounding=0,
    Callback=function(val)
        cfg.walkSpeedValue = val
        if cfg.walkSpeedEnabled then
            local hum = getHumanoid()
            if hum then hum.WalkSpeed = val end
        end
    end,
})

-- Stats Dashboard Box (Real-Time dari snap.today & snap.rep)
local StatsBox = OpenTab:AddRightGroupbox('📊 Stats Dashboard (Real-Time)')
local StatDayLabel      = StatsBox:AddLabel('📅 Hari: -')
local StatIncomeLabel   = StatsBox:AddLabel('💰 Income Hari Ini: $0')
local StatServedLabel   = StatsBox:AddLabel('👥 Pelanggan Served: 0')
local StatRatingLabel   = StatsBox:AddLabel('⭐ Rating Warnet: -')

-- ══ TAB 4: SETTINGS ══════════════════════════════════════════════
local SettingsTab = Window:AddTab('Settings')
local SettingsBox = SettingsTab:AddLeftGroupbox('🎨 Theme')
ThemeManager:SetLibrary(Library)
ThemeManager:SetFolder('WarnetopiaHub')
ThemeManager:ApplyToGroupbox(SettingsBox)

SaveManager:SetLibrary(Library)
SaveManager:SetFolder('WarnetopiaHub/configs')
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({'MenuKeybind','selectedManualStore'})
SaveManager:BuildConfigSection(SettingsTab)

local WebhookBox = SettingsTab:AddRightGroupbox('🔔 Discord Webhook')
WebhookBox:AddToggle('webhookEnabled', {
    Text='Kirim Notif Auto Buy', Default=false,
    Callback=function(val) cfg.webhookEnabled = val end,
})
WebhookBox:AddInput('webhookUrlInput', {
    Default='', Numeric=false, Finished=false,
    Text='Webhook URL', Placeholder='https://discord.com/api/webhooks/...',
    Callback=function(val) cfg.webhookUrl = val end,
})
WebhookBox:AddButton({
    Text='📨 Test Kirim Webhook',
    Func=function()
        task.spawn(function()
            local ok, msg = sendWebhook("✅ Webhook Terhubung!", "Warnetopia Hub siap kirim notif.", 5763719)
            Library:Notify((ok and "✅ " or "❌ ")..msg, 3)
        end)
    end,
})

-- ─── STATS DASHBOARD, LOW STOCK & AUTO RESTOCK STOK KAFE ──────────
local function getCafeItemDisplayName(key)
    local kl = tostring(key):lower()
    if CAFE_ITEM_LABELS[kl] then return CAFE_ITEM_LABELS[kl] end
    local byId = BY_ID[key] or BY_ID[kl]
    if byId and byId.name then return byId.name end
    return tostring(key):gsub("_", " "):gsub("^%l", string.upper)
end

local function autoRestockCafeMenuBackground(lowKeyMap)
    if not cfg.autoRestockCafeEnabled then return end
    if os.clock() - lastCafeRestockClock < 4 then return end

    local buyIds = {}
    local seenStockIds = {}

    for cafeKey, _ in pairs(lowKeyMap) do
        local kl = tostring(cafeKey):lower()
        local stockId = CAFE_KEY_TO_STOCK_ID[kl]
        if stockId and not seenStockIds[stockId] then
            seenStockIds[stockId] = true
            table.insert(buyIds, { stockId = stockId, label = getCafeItemDisplayName(stockId) })
        end
    end

    if #buyIds == 0 then return end
    lastCafeRestockClock = os.clock()

    local boughtLog = {}
    for _, entry in ipairs(buyIds) do
        if not cfg.autoRestockCafeEnabled then break end
        fireAction("buy", { id = entry.stockId })
        table.insert(boughtLog, string.format("• **%s** (+10 stok)", entry.label))
        task.wait(0.25)
    end

    if #boughtLog > 0 then
        Library:Notify("☕ Auto Restock Kafe (+10): " .. #boughtLog .. " menu dibeli!", 3)
        if cfg.lowStockWebhook then
            task.spawn(sendWebhook(
                "☕ Auto Restock Stok Kafe (+10)",
                "Berhasil mengisi ulang stok menu kafe via **WarnetOS**:\n" .. table.concat(boughtLog, "\n"),
                3066993
            ))
        end
    end
end

local function evaluateCafeLowStock(snap)
    if not snap or type(snap.stock) ~= "table" then return end

    local lowItems = {}
    local lowKeyMap = {}
    local discordLines = {}
    local threshold = cfg.lowStockThreshold or 10

    for itemKey, qty in pairs(snap.stock) do
        if type(qty) == "number" then
            local label = getCafeItemDisplayName(itemKey)
            if qty < threshold then
                lowKeyMap[itemKey] = qty
                table.insert(lowItems, string.format("%s (%d)", label, qty))
                if not lowStockNotified[itemKey] then
                    lowStockNotified[itemKey] = true
                    table.insert(discordLines, string.format("• **%s** — Sisa **%d** stok!", label, qty))
                end
            else
                lowStockNotified[itemKey] = nil
            end
        end
    end

    if #lowItems > 0 then
        local summary = "⚠️ Stok Tipis: " .. table.concat(lowItems, ", ")
        LowStockStatusLabel:SetText(summary)
        if cfg.lowStockAlertGui and lastLowStockGuiMsg ~= summary then
            lastLowStockGuiMsg = summary
            Library:Notify(summary, 4)
        end
        if cfg.lowStockWebhook and #discordLines > 0 then
            task.spawn(sendWebhook(
                "⚠️ Low Stock Alert — Menu Kafe!",
                "Stok menu kafe berikut sudah di bawah **" .. threshold .. "**:\n" .. table.concat(discordLines, "\n"),
                15158332
            ))
        end
        if cfg.autoRestockCafeEnabled then
            task.spawn(autoRestockCafeMenuBackground, lowKeyMap)
        end
    else
        lastLowStockGuiMsg = ""
        LowStockStatusLabel:SetText("✅ Semua stok menu kafe aman (>= " .. threshold .. ")")
    end
end

local function updateStatsDashboard(snap)
    if type(snap) ~= "table" then return end

    if snap.day then
        StatDayLabel:SetText("📅 Hari: Hari " .. tostring(snap.day))
    end

    if type(snap.today) == "table" then
        if type(snap.today.income) == "table" then
            local totalIncome = 0
            for _, amount in pairs(snap.today.income) do
                if type(amount) == "number" then
                    totalIncome = totalIncome + amount
                end
            end
            StatIncomeLabel:SetText("💰 Income Hari Ini: " .. formatMoneyFull(totalIncome))
        elseif type(snap.today.income) == "number" then
            StatIncomeLabel:SetText("💰 Income Hari Ini: " .. formatMoneyFull(snap.today.income))
        end

        if snap.today.served ~= nil then
            local custStr = snap.today.customers and (" / " .. tostring(snap.today.customers) .. " datang") or " orang"
            StatServedLabel:SetText("👥 Pelanggan Served: " .. tostring(snap.today.served) .. custStr)
        end
    end

    if type(snap.rep) == "number" then
        StatRatingLabel:SetText(string.format("⭐ Rating Warnet: %.2f / 5.0", snap.rep))
    end
end

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
                if t == "Beli" or t == "Habis" then
                    local cardFrame = obj.Parent
                    while cardFrame and cardFrame:IsA("GuiObject") do
                        if cardFrame.AbsoluteSize.X >= 85 and cardFrame.AbsoluteSize.X <= 260 and cardFrame.AbsoluteSize.Y >= 115 then break end
                        cardFrame = cardFrame.Parent
                    end
                    if cardFrame and not seenParents[cardFrame] then
                        seenParents[cardFrame] = true
                        local qtyNum = (t == "Habis") and 0 or nil
                        local bestTitle, bestY = nil, math.huge
                        local lowestPrice, highestPrice = nil, nil
                        for _, child in ipairs(cardFrame:GetDescendants()) do
                            if child:IsA("TextLabel") and child.Visible then
                                local ct = child.Text or ""
                                if ct:match("^Sisa%s*(%d+)") then
                                    qtyNum = tonumber(ct:match("^Sisa%s*(%d+)"))
                                elseif ct:match("^%$[%d%.%,]+") then
                                    local parsed = parsePriceText(ct)
                                    if parsed then
                                        if not lowestPrice or parsed < lowestPrice then lowestPrice = parsed end
                                        if not highestPrice or parsed > highestPrice then highestPrice = parsed end
                                    end
                                elseif ct ~= "" and ct ~= "Beli" and ct ~= "Habis"
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
                            cardDisc = math.floor(((highestPrice - lowestPrice) / highestPrice) * 100 + 0.5)
                            if cardDisc > 0 and discountPercent == 0 then discountPercent = cardDisc end
                        end

                        if bestTitle then
                            table.insert(cards, { x=cardFrame.AbsolutePosition.X, y=cardFrame.AbsolutePosition.Y,
                                title=bestTitle, qty=qtyNum or 0, price=lowestPrice, discPct=cardDisc })
                        end
                    end
                end
            end
        end

        if #cards > 0 then
            table.sort(cards, function(a, b)
                if math.abs(a.y - b.y) > 25 then return a.y < b.y end
                return a.x < b.x
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

    pcall(updateStatsDashboard, snap)
    pcall(evaluateCafeLowStock, snap)

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

    pcall(function()
        for storeId, items in pairs(purchaseQueue) do
            local targetCFrame = STORE_LOCATIONS[storeId]
            if targetCFrame then
                safeTeleport(targetCFrame)
                task.wait(0.5)
                for _, itemData in ipairs(items) do
                    local stillEnabled = (storeId == "minimart" and cfg.autoMinimartEnabled)
                                      or (storeId ~= "minimart" and cfg.autoBuyEnabled)
                    if not stillEnabled then break end
                    local boughtCount = 0
                    for _ = 1, itemData.qty do
                        fireAction("storeBuy", { store=storeId, item=itemData.id })
                        boughtCount = boughtCount + 1
                        task.wait(0.25)
                    end
                    if boughtCount > 0 then
                        local itemInfo = BY_ID[itemData.id]
                        local itemName = (itemInfo and itemInfo.name) or itemData.id
                        local rarityTag = (itemInfo and itemInfo.rarity == "sangat_langka" and " [★★]")
                                       or (itemInfo and itemInfo.rarity == "langka" and " [★]") or ""
                        table.insert(boughtLog, string.format("• **%s**%s (x%d) — *%s*",
                            itemName, rarityTag, boughtCount, STORE_ID_TO_NAME[storeId] or storeId))
                    end
                end
            end
        end
    end)

    task.wait(0.3)
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
            EsTehStatusLabel:SetText("⚡ Aktif: " .. buffTxt)
        else
            EsTehStatusLabel:SetText("💤 Status Buff: Tidak aktif / Habis")
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
                clickGuiButton(btn)
                fireAction("dayContinue", {})
                task.delay(cfg.reopenDelay, function()
                    if cfg.autoOpenEnabled and getStatus() == "TUTUP" then
                        fireAction("setOpen", { open=true })
                    end
                end)
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
        task.delay(cfg.reopenDelay, function()
            if cfg.autoOpenEnabled and getStatus() == "TUTUP" then
                fireAction("setOpen", { open=true })
            end
            reopenPending = false
        end)
    end

    if status == "TUTUP" and lastStatus == nil and not reopenPending then
        reopenPending = true
        task.delay(1, function()
            if cfg.autoOpenEnabled and getStatus() == "TUTUP" then
                fireAction("setOpen", { open=true })
            end
            reopenPending = false
        end)
    end

    lastStatus = status
end)

SaveManager:LoadAutoloadConfig()
Library:SetWatermark('Warnetopia Hub 🖤')
Library.Toggled = true

print('[Hub] 🖤 Warnetopia Hub loaded! RightShift = hide/show')
