--[[ BD Hub Part 1/2: Max Client Shield + TPS FOV + Bullet Tracking ]]
if getgenv().BDHub_Loaded then
    warn("BD Hub is already running!")
    return
end
getgenv().BDHub_Loaded = true

pcall(function()
    if hookmetamethod and getnamecallmethod and newcclosure then
        local mt = getrawmetatable(game)
        setreadonly(mt, false)
        local blockedWords = {
            "detector", "anticheat", "anti_cheat", "ac", "security",
            "protection", "scan", "check", "report", "flag", "kick", "ban"
        }
        local function isRisky(str)
            str = tostring(str):lower()
            for _, w in ipairs(blockedWords) do
                if str:find(w, 1, true) then return true end
            end
            return false
        end
        local oldNamecall = mt.__namecall
        mt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            local caller = checkcaller and checkcaller()
            if not caller and (isRisky(self) or isRisky(method)) then
                return nil
            end
            return oldNamecall(self, ...)
        end)
        setreadonly(mt, true)
    end
end)

local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

pcall(function()
    if setclipboard then
        setclipboard("bd-38263-0372-Hub")
        WindUI:Notify({ Title = "BD Hub Security", Content = "Key copied!", Duration = 3 })
    end
end)

local Window = WindUI:CreateWindow({
    Title = "BD Hub", Icon = "hammer", Author = "by BD Team", Folder = "BDHub",
    Size = UDim2.fromOffset(580, 460), MinSize = Vector2.new(560, 350), MaxSize = Vector2.new(850, 560),
    ToggleKey = Enum.KeyCode.LeftShift, Transparent = true, Theme = "Dark", Resizable = true, Draggable = true,
    SideBarWidth = 200, BackgroundImageTransparency = 0.42, HideSearchBar = true, ScrollBarEnabled = true,
    User = { Enabled = true, Anonymous = true, Callback = function() end },
    KeySystem = { Key = { "bd-38263-0372-Hub" }, Note = "Auto-copied!", Thumbnail = { Image = "hammer", Title = "BD Hub Security" }, URL = "", SaveKey = false }
})

local AimbotTab = Window:Tab({ Title = "Aimbot", Icon = "crosshair" })
local VisualsTab = Window:Tab({ Title = "Visuals", Icon = "eye" })

local CONFIG = {
    MASTER_COMBAT = false, TPS_CAM = true, FOV_RADIUS = 300, FOV_MODE = "Center",
    BULLET_TRACK = true, CHAR_LOOKAT = false, BIG_HITBOX = false,
    BOX_ESP = false, SNAPLINE_ESP = false, HEALTHBAR_ESP = false
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

local tpsActive = false
local savedWaistC1 = nil
local lockedTarget = nil
local activeBulletTargetHead = nil

local function resetTPSState()
    pcall(function()
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.CameraOffset = Vector3.zero; hum.AutoRotate = true end
        local waist = char and char:FindFirstChild("UpperTorso") and char.UpperTorso:FindFirstChild("Waist")
        if waist and savedWaistC1 then waist.C1 = savedWaistC1 end
        if tpsActive then UserInputService.MouseBehavior = Enum.MouseBehavior.Default end
        tpsActive = false; savedWaistC1 = nil
    end)
end

LocalPlayer.CharacterAdded:Connect(function()
    tpsActive = false; savedWaistC1 = nil; lockedTarget = nil; activeBulletTargetHead = nil
end)

local parentGui
if gethui then local ok, hui = pcall(gethui); if ok and hui then parentGui = hui end end
parentGui = parentGui or LocalPlayer:WaitForChild("PlayerGui")
if parentGui:FindFirstChild("BD_FOV_UI") then parentGui.BD_FOV_UI:Destroy() end

local fovGui = Instance.new("ScreenGui")
fovGui.Name = "BD_FOV_UI"; fovGui.IgnoreGuiInset = true; fovGui.ResetOnSpawn = false; fovGui.DisplayOrder = 999; fovGui.Parent = parentGui

local fovFrame = Instance.new("Frame")
fovFrame.Name = "FOVCircle"; fovFrame.AnchorPoint = Vector2.new(0.5, 0.5); fovFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
fovFrame.Size = UDim2.fromOffset(CONFIG.FOV_RADIUS * 2, CONFIG.FOV_RADIUS * 2); fovFrame.BackgroundTransparency = 1; fovFrame.Visible = false; fovFrame.Parent = fovGui
Instance.new("UICorner", fovFrame).CornerRadius = UDim.new(1, 0)

local fovStroke = Instance.new("UIStroke", fovFrame)
fovStroke.Thickness = 2.5; fovStroke.Transparency = 0.05

local fovGradient = Instance.new("UIGradient", fovStroke)
fovGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0, 0)), ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 165, 0)),
    ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 255, 0)), ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0, 255, 0)),
    ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)), ColorSequenceKeypoint.new(0.83, Color3.fromRGB(75, 0, 130)),
    ColorSequenceKeypoint.new(1.00, Color3.fromRGB(238, 130, 238))
})

AimbotTab:Section({ Title = "Combat & Targeting" })
AimbotTab:Toggle({ Title = "Combat Master Toggle (FOV + Active)", Default = false, Callback = function(v)
    CONFIG.MASTER_COMBAT = v
    if fovFrame then fovFrame.Visible = v end
    if not v then lockedTarget = nil; activeBulletTargetHead = nil; resetTPSState() end
end})
AimbotTab:Toggle({ Title = "Bullet Tracking (Lock Until Dead)", Default = true, Callback = function(v)
    CONFIG.BULLET_TRACK = v; if not v then activeBulletTargetHead = nil end
end})
AimbotTab:Toggle({ Title = "TPS Shoulder Camera (With FOV)", Default = true, Callback = function(v)
    CONFIG.TPS_CAM = v; if not v then resetTPSState() end
end})
AimbotTab:Dropdown({ Title = "FOV Position Mode", Values = { "Center", "Mouse" }, Default = "Center", Callback = function(v) CONFIG.FOV_MODE = v end })
AimbotTab:Dropdown({ Title = "FOV Radius Size", Values = { "150", "200", "250", "300", "400", "500" }, Default = "300", Callback = function(v)
    local num = tonumber(v)
    if num then CONFIG.FOV_RADIUS = num; if fovFrame then fovFrame.Size = UDim2.fromOffset(num * 2, num * 2) end end
end})
AimbotTab:Toggle({ Title = "Character LookAt Target (Body Auto-Face)", Default = false, Callback = function(v) CONFIG.CHAR_LOOKAT = v end })
AimbotTab:Toggle({ Title = "Big Hitbox (Expand Enemy Body)", Default = false, Callback = function(v) CONFIG.BIG_HITBOX = v end })

VisualsTab:Section({ Title = "ESP Settings" })
VisualsTab:Toggle({ Title = "Box ESP", Default = false, Callback = function(v) CONFIG.BOX_ESP = v end })
VisualsTab:Toggle({ Title = "Snaplines", Default = false, Callback = function(v) CONFIG.SNAPLINE_ESP = v end })
VisualsTab:Toggle({ Title = "Health Bar ESP", Default = false, Callback = function(v) CONFIG.HEALTHBAR_ESP = v end })
--[[ BD Hub Part 2/2: Engine, Target Lock, Bullet Track, TPS & ESP ]]
local ESPCache = {}

local function CleanupESP(p)
    pcall(function()
        if ESPCache[p] then
            for _, obj in pairs(ESPCache[p]) do if obj then obj:Remove() end end
            ESPCache[p] = nil
        end
        if lockedTarget == p then lockedTarget = nil; activeBulletTargetHead = nil end
    end)
end
Players.PlayerRemoving:Connect(CleanupESP)

local function getReferencePosition()
    if CONFIG.FOV_MODE == "Mouse" then return Vector2.new(Mouse.X, Mouse.Y + 36) end
    return Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
end

local function isPlayerAliveAndInFOV(plr, refPos, radius)
    if not plr or plr == LocalPlayer or not plr.Character then return false, nil end
    local hum = plr.Character:FindFirstChildOfClass("Humanoid")
    local head = plr.Character:FindFirstChild("Head")
    if not (hum and hum.Health > 0 and head) then return false, nil end
    local pos, onScreen = Camera:WorldToViewportPoint(head.Position)
    if not onScreen then return false, nil end
    local dist = (Vector2.new(pos.X, pos.Y) - refPos).Magnitude
    if dist <= radius then return true, head, dist end
    return false, nil
end

local function getTargetHead()
    if not Camera then return nil, nil end
    local refPos = getReferencePosition()
    local radius = CONFIG.FOV_RADIUS
    if lockedTarget then
        local valid, head = isPlayerAliveAndInFOV(lockedTarget, refPos, radius)
        if valid and head then return head, lockedTarget end
        lockedTarget = nil
    end
    local shortestDist = radius
    local bestHead, bestPlayer = nil, nil
    for _, plr in ipairs(Players:GetPlayers()) do
        local valid, head, dist = isPlayerAliveAndInFOV(plr, refPos, radius)
        if valid and head and dist < shortestDist then
            shortestDist = dist; bestHead = head; bestPlayer = plr
        end
    end
    lockedTarget = bestPlayer
    return bestHead, lockedTarget
end

local function aimArgAtTarget(arg, originPos, targetPos)
    if typeof(arg) == "Vector3" then
        if originPos and (arg - originPos).Magnitude <= 15 then return (targetPos - originPos).Unit end
        return targetPos
    elseif typeof(arg) == "Ray" then
        local dir = (targetPos - arg.Origin).Unit * (arg.Direction.Magnitude > 0 and arg.Direction.Magnitude or 500)
        return Ray.new(arg.Origin, dir)
    end
    return arg
end

pcall(function()
    if hookmetamethod and getnamecallmethod and newcclosure then
        local mt = getrawmetatable(game)
        setreadonly(mt, false)
        local oldIndex = mt.__index
        mt.__index = newcclosure(function(self, key)
            if not checkcaller() and CONFIG.MASTER_COMBAT and CONFIG.BULLET_TRACK and activeBulletTargetHead and activeBulletTargetHead.Parent then
                if self == Mouse then
                    if key == "Hit" then return activeBulletTargetHead.CFrame
                    elseif key == "Target" then return activeBulletTargetHead end
                end
            end
            return oldIndex(self, key)
        end)
        local prevNamecall = mt.__namecall
        mt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if not checkcaller() and CONFIG.MASTER_COMBAT and CONFIG.BULLET_TRACK and activeBulletTargetHead and activeBulletTargetHead.Parent then
                local targetPos = activeBulletTargetHead.Position
                local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                local originPos = hrp and hrp.Position or (Camera and Camera.CFrame.Position)
                if method == "Raycast" and self == workspace then
                    local args = { ... }
                    if typeof(args[1]) == "Vector3" and typeof(args[2]) == "Vector3" then
                        args[2] = (targetPos - args[1]).Unit * args[2].Magnitude
                        return prevNamecall(self, unpack(args))
                    end
                elseif method == "FindPartOnRay" or method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRayWithWhitelist" then
                    local args = { ... }
                    if typeof(args[1]) == "Ray" then
                        args[1] = aimArgAtTarget(args[1], originPos, targetPos)
                        return prevNamecall(self, unpack(args))
                    end
                elseif method == "FireServer" or method == "InvokeServer" then
                    local args = { ... }
                    for i = 1, #args do args[i] = aimArgAtTarget(args[i], originPos, targetPos) end
                    return prevNamecall(self, unpack(args))
                end
            end
            return prevNamecall(self, ...)
        end)
        setreadonly(mt, true)
    end
end)

local function runTPSCamera(char, targetHead)
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    local upperTorso = char:FindFirstChild("UpperTorso")
    local lowerTorso = char:FindFirstChild("LowerTorso")
    local waist = upperTorso and upperTorso:FindFirstChild("Waist")
    if not (hum and root and Camera) then return end
    if not tpsActive then
        tpsActive = true
        if waist and not savedWaistC1 then savedWaistC1 = waist.C1 end
        hum.CameraOffset = Vector3.new(3, 0, 0); hum.AutoRotate = false; Camera.CameraSubject = hum
    end
    UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
    local delta = UserInputService:GetMouseDelta()
    Camera.CFrame = CFrame.new(Camera.CFrame.p, Camera.CFrame * CFrame.new(delta.X, -delta.Y, -2000).p)
    if waist and upperTorso and lowerTorso and mouse and mouse.Hit and mouse.Origin then
        local dir = (mouse.Hit.p - mouse.Origin.p)
        if dir.Magnitude > 0 then
            local pitch = math.max(math.min(math.asin(math.clamp(dir.Unit.y, -1, 1)), 0.6), -0.75)
            local offset = lowerTorso.CFrame:ToWorldSpace(CFrame.new(0, upperTorso.Size.Y / 2, 0)) * CFrame.fromEulerAnglesXYZ(pitch, 0, 0) * CFrame.new(0, upperTorso.Size.Y / 2, 0)
            waist.C1 = offset:inverse() * lowerTorso.CFrame * CFrame.new(0, 0.8, 0)
        end
    end
    local aimDir = (CONFIG.CHAR_LOOKAT and targetHead) and Vector3.new(targetHead.Position.X - root.Position.X, 0, targetHead.Position.Z - root.Position.Z) or Vector3.new(Camera.CFrame.LookVector.X, 0, Camera.CFrame.LookVector.Z)
    if aimDir.Magnitude > 0.001 then
        TweenService:Create(root, TweenInfo.new(0.15, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { CFrame = CFrame.new(root.Position, root.Position + aimDir.Unit) }):Play()
    end
end

RunService.RenderStepped:Connect(function()
    pcall(function()
        if not Camera then return end
        local refPos = getReferencePosition()
        if fovFrame then
            fovFrame.Visible = CONFIG.MASTER_COMBAT
            fovFrame.Position = (CONFIG.FOV_MODE == "Mouse") and UDim2.fromOffset(Mouse.X, Mouse.Y + 36) or UDim2.new(0.5, 0, 0.5, 0)
            if fovGradient then fovGradient.Rotation = (tick() * 60) % 360 end
        end
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
                local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
                if rootPart and humanoid and humanoid.Health > 0 then
                    if CONFIG.BIG_HITBOX then
                        rootPart.Size = Vector3.new(4, 7, 4); rootPart.Transparency = 0.8; rootPart.CanCollide = false
                    else
                        rootPart.Size = Vector3.new(2, 2, 1); rootPart.Transparency = 1
                    end
                end
            end
        end
        local targetHead, currentTargetPlr = getTargetHead()
        activeBulletTargetHead = CONFIG.MASTER_COMBAT and targetHead or nil
        local myChar = LocalPlayer.Character
        if CONFIG.MASTER_COMBAT and CONFIG.TPS_CAM and myChar and myChar.Parent == workspace then
            runTPSCamera(myChar, targetHead)
        else
            if tpsActive then resetTPSState() end
            if CONFIG.MASTER_COMBAT and CONFIG.CHAR_LOOKAT and targetHead and myChar then
                local hrp = myChar:FindFirstChild("HumanoidRootPart")
                if hrp then hrp.CFrame = CFrame.new(hrp.Position, Vector3.new(targetHead.Position.X, hrp.Position.Y, targetHead.Position.Z)) end
            end
        end
        if CONFIG.BOX_ESP or CONFIG.SNAPLINE_ESP or CONFIG.HEALTHBAR_ESP then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character then
                    local char = player.Character
                    local rootPart = char:FindFirstChild("HumanoidRootPart")
                    local head = char:FindFirstChild("Head")
                    local humanoid = char:FindFirstChildOfClass("Humanoid")
                    if rootPart and head and humanoid and humanoid.Health > 0 then
                        if not ESPCache[player] then
                            local box = Drawing.new("Square"); box.Thickness = 1.5; box.Filled = false
                            local tracer = Drawing.new("Line"); tracer.Thickness = 1; tracer.Transparency = 0.8
                            local hb_bg = Drawing.new("Line"); hb_bg.Thickness = 3; hb_bg.Color = Color3.new(0, 0, 0)
                            local hb_fill = Drawing.new("Line"); hb_fill.Thickness = 1.5
                            ESPCache[player] = { Box = box, Tracer = tracer, HB_Bg = hb_bg, HB_Fill = hb_fill }
                        end
                        local pos, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
                        local headPos, headOnScreen = Camera:WorldToViewportPoint(head.Position)
                        if onScreen then
                            local scaleFactor = 1 / (pos.Z * math.tan(math.rad(Camera.FieldOfView * 0.5)) * 2) * 1000
                            local w, h = math.floor(4 * scaleFactor), math.floor(5.5 * scaleFactor)
                            local boxPos = Vector2.new(pos.X - w / 2, pos.Y - h / 2)
                            local targetColor = (player == currentTargetPlr) and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(0, 255, 128)
                            local c = ESPCache[player]
                            c.Box.Visible = CONFIG.BOX_ESP
                            if CONFIG.BOX_ESP then c.Box.Color = targetColor; c.Box.Size = Vector2.new(w, h); c.Box.Position = boxPos end
                            c.Tracer.Visible = CONFIG.SNAPLINE_ESP and player == currentTargetPlr and headOnScreen
                            if c.Tracer.Visible then c.Tracer.Color = Color3.fromRGB(255, 50, 50); c.Tracer.From = refPos; c.Tracer.To = Vector2.new(headPos.X, headPos.Y) end
                            c.HB_Bg.Visible = CONFIG.HEALTHBAR_ESP; c.HB_Fill.Visible = CONFIG.HEALTHBAR_ESP
                            if CONFIG.HEALTHBAR_ESP then
                                local hp = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
                                c.HB_Bg.From = Vector2.new(boxPos.X - 6, boxPos.Y + h); c.HB_Bg.To = Vector2.new(boxPos.X - 6, boxPos.Y)
                                c.HB_Fill.From = Vector2.new(boxPos.X - 6, boxPos.Y + h); c.HB_Fill.To = Vector2.new(boxPos.X - 6, boxPos.Y + (h - (h * hp))); c.HB_Fill.Color = Color3.fromRGB(0, 255, 0)
                            end
                        else
                            for _, obj in pairs(ESPCache[player]) do obj.Visible = false end
                        end
                    else CleanupESP(player) end
                end
            end
        else
            for p in pairs(ESPCache) do CleanupESP(p) end
        end
    end)
end)

print("BD Hub (2-Part Max-Shield) Loaded!")
