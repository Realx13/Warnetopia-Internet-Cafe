--[[
    Warnetopia: Warnet Simulator — Auto-Open v2
    - Toggle GUI button (ON/OFF)
    - Auto buka warnet kalau tiba-tiba TUTUP
    - Fix path CafeCard yang bener

    🖤 untuk Temu
--]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

-- ─── REMOTE ──────────────────────────────────────────────────────────────────
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
local Action  = Remotes and Remotes:WaitForChild("Action", 10)
assert(Action, "[AutoOpen] Remote Action ga ketemu!")

-- ─── CONFIG ──────────────────────────────────────────────────────────────────
local CHECK_INTERVAL   = 3     -- detik antar cek
local REOPEN_DELAY     = 6     -- detik tunggu sebelum buka ulang setelah TUTUP

-- ─── STATE ───────────────────────────────────────────────────────────────────
local autoOpenEnabled  = false
local lastStatus       = nil
local checkTimer       = 0
local reopenPending    = false

-- ─── HELPER: Ambil status BUKA/TUTUP dari UI ─────────────────────────────────
local function getStatus(): string?
    local gui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not gui then return nil end
    local ok, card = pcall(function()
        return gui.WarnetopiaUI.Root.TL.TopRow.CafeCard
    end)
    if not ok or not card then return nil end
    for _, d in ipairs(card:GetDescendants()) do
        if d:IsA("TextLabel") then
            local t = d.Text:upper()
            if t == "BUKA" or t == "TUTUP" then return t end
        end
    end
    return nil
end

-- ─── HELPER: Fire buka warnet ────────────────────────────────────────────────
local function sendOpen()
    local ok, err = pcall(function()
        Action:FireServer("setOpen", { open = true })
    end)
    if ok then
        print("[AutoOpen] ✅ Warnet dibuka!")
    else
        warn("[AutoOpen] ❌ Gagal:", err)
    end
end

-- ─── BUAT GUI ────────────────────────────────────────────────────────────────
local function buildGui()
    -- Hapus kalau udah ada (re-execute safe)
    local existing = LocalPlayer.PlayerGui:FindFirstChild("AutoOpenGui")
    if existing then existing:Destroy() end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name            = "AutoOpenGui"
    ScreenGui.ResetOnSpawn    = false
    ScreenGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
    ScreenGui.Parent          = LocalPlayer.PlayerGui

    -- Container frame
    local Frame = Instance.new("Frame")
    Frame.Name              = "Container"
    Frame.Size              = UDim2.fromOffset(180, 56)
    Frame.Position          = UDim2.new(0.5, -90, 1, -80)
    Frame.BackgroundColor3  = Color3.fromRGB(18, 18, 22)
    Frame.BorderSizePixel   = 0
    Frame.AnchorPoint       = Vector2.new(0, 0)
    Frame.Parent            = ScreenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = Frame

    local stroke = Instance.new("UIStroke")
    stroke.Color     = Color3.fromRGB(80, 80, 110)
    stroke.Thickness = 1.5
    stroke.Parent    = Frame

    -- Label kiri
    local Label = Instance.new("TextLabel")
    Label.Size              = UDim2.new(0, 110, 1, 0)
    Label.Position          = UDim2.fromOffset(10, 0)
    Label.BackgroundTransparency = 1
    Label.TextColor3        = Color3.fromRGB(220, 220, 240)
    Label.Font              = Enum.Font.GothamBold
    Label.TextSize          = 13
    Label.TextXAlignment    = Enum.TextXAlignment.Left
    Label.Text              = "🏪 Auto-Open"
    Label.Parent            = Frame

    -- Toggle button
    local Btn = Instance.new("TextButton")
    Btn.Name              = "Toggle"
    Btn.Size              = UDim2.fromOffset(54, 28)
    Btn.Position          = UDim2.new(1, -62, 0.5, -14)
    Btn.BackgroundColor3  = Color3.fromRGB(60, 60, 75)
    Btn.BorderSizePixel   = 0
    Btn.TextColor3        = Color3.fromRGB(180, 180, 200)
    Btn.Font              = Enum.Font.GothamBold
    Btn.TextSize          = 12
    Btn.Text              = "OFF"
    Btn.Parent            = Frame

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 8)
    btnCorner.Parent = Btn

    -- Update visual state tombol
    local function refreshBtn()
        local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad)
        if autoOpenEnabled then
            TweenService:Create(Btn, tweenInfo, {
                BackgroundColor3 = Color3.fromRGB(60, 200, 100)
            }):Play()
            Btn.TextColor3 = Color3.fromRGB(10, 30, 10)
            Btn.Text = "ON"
        else
            TweenService:Create(Btn, tweenInfo, {
                BackgroundColor3 = Color3.fromRGB(60, 60, 75)
            }):Play()
            Btn.TextColor3 = Color3.fromRGB(180, 180, 200)
            Btn.Text = "OFF"
        end
    end

    -- Click handler
    Btn.MouseButton1Click:Connect(function()
        autoOpenEnabled = not autoOpenEnabled
        refreshBtn()

        if autoOpenEnabled then
            print("[AutoOpen] 🟢 Aktif — monitoring warnet...")
            -- Langsung buka kalau sekarang TUTUP
            local s = getStatus()
            if s == "TUTUP" then
                task.delay(1, sendOpen)
            end
        else
            print("[AutoOpen] 🔴 Nonaktif.")
            reopenPending = false
        end
    end)

    -- Drag support (biar bisa dipindahin)
    local dragging, dragStart, startPos
    Frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging  = true
            dragStart = input.Position
            startPos  = Frame.Position
        end
    end)
    Frame.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            Frame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
    Frame.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    refreshBtn()
    return ScreenGui
end

buildGui()
print("[AutoOpen] 🖤 GUI muncul! Tekan tombol OFF buat aktifin.")

-- ─── MAIN LOOP ────────────────────────────────────────────────────────────────
RunService.Heartbeat:Connect(function(dt)
    if not autoOpenEnabled then
        lastStatus = nil
        return
    end

    checkTimer = checkTimer + dt
    if checkTimer < CHECK_INTERVAL then return end
    checkTimer = 0

    local status = getStatus()
    if not status then return end

    -- Kalau baru berubah dari BUKA → TUTUP
    if lastStatus == "BUKA" and status == "TUTUP" and not reopenPending then
        reopenPending = true
        print(("[AutoOpen] ⚠️ Warnet TUTUP terdeteksi! Buka ulang dalam %ds..."):format(REOPEN_DELAY))

        task.delay(REOPEN_DELAY, function()
            if not autoOpenEnabled then
                reopenPending = false
                return
            end
            local cur = getStatus()
            if cur == "TUTUP" then
                print("[AutoOpen] 🔁 Membuka warnet otomatis...")
                sendOpen()
            end
            reopenPending = false
        end)
    end

    -- Kalau masih TUTUP tapi fitur baru dinyalain (edge case)
    if status == "TUTUP" and lastStatus == nil and not reopenPending then
        reopenPending = true
        task.delay(1, function()
            if autoOpenEnabled and getStatus() == "TUTUP" then
                sendOpen()
            end
            reopenPending = false
        end)
    end

    lastStatus = status
end)
