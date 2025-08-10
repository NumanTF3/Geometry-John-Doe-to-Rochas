-- Stop previous instances
if getgenv().RochasChangerRunning then
    getgenv().RochasChangerRunning = false
    task.wait(0.3)
end
getgenv().RochasChangerRunning = true

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local killerName = "JohnDoe"
local torsoColor = Color3.fromRGB(255, 174, 182)
local rigAssetId = "rbxassetid://74773737275811"
local spikeAssetId = "rbxassetid://80855887476594"

-- Remove all old GUIs named "RochasChangerGUI"
for _, gui in pairs(game.CoreGui:GetChildren()) do
    if gui.Name == "RochasChangerGUI" then
        gui:Destroy()
    end
end

-- Load rig from asset and parent to workspace
local function loadRig()
    local success, models = pcall(function()
        return game:GetObjects(rigAssetId)
    end)
    if success and models and #models > 0 then
        local rig = models[1]
        if rig:IsA("Folder") and #rig:GetChildren() > 0 then
            rig = rig:GetChildren()[1]
        end
        rig.Parent = workspace
        rig:PivotTo(CFrame.new(0, 10, 0)) -- Spawn above ground to be visible
        for _, part in pairs(rig:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Transparency = 0
                part.CanCollide = false
            end
        end
        return rig
    end
    warn("Failed to load rig model")
    return nil
end

-- Make model invisible & non-collidable
local function setModelInvisible(model)
    for _, part in pairs(model:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Transparency = 1
            part.CanCollide = false
        elseif part:IsA("Decal") or part:IsA("Texture") then
            part.Transparency = 1
        end
    end
end

-- Make rig visible & non-collidable
local function setRigNonCollidable(model)
    for _, part in pairs(model:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
            part.Transparency = 0
        end
    end
end

-- Dynamic animation syncing helpers
local rigAnimTracks = {}
local killerAnimIds = {}

local function clearRigAnimations(rigHumanoid)
    for _, track in ipairs(rigAnimTracks) do
        track:Stop()
        track:Destroy()
    end
    rigAnimTracks = {}
    killerAnimIds = {}
end

local function updateRigAnimations(killerHumanoid, rigHumanoid)
    local currentIds = {}
    local playingTracks = killerHumanoid:GetPlayingAnimationTracks()

    for _, track in ipairs(playingTracks) do
        if track.Animation then
            currentIds[track.Animation.AnimationId] = track
        end
    end

    -- Check if animations changed
    local changed = false
    if #playingTracks ~= #rigAnimTracks then
        changed = true
    else
        for animId in pairs(currentIds) do
            if not killerAnimIds[animId] then
                changed = true
                break
            end
        end
    end

    if changed then
        clearRigAnimations(rigHumanoid)
        for animId, track in pairs(currentIds) do
            local anim = track.Animation
            local newTrack = rigHumanoid:LoadAnimation(anim)
            newTrack:Play()
            newTrack.TimePosition = track.TimePosition
            table.insert(rigAnimTracks, newTrack)
        end
        killerAnimIds = currentIds
    end
end

-- Make HumanoidRootPart and Right Arm invisible
local function makePartsInvisible(rig)
    local hrp = rig:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.Transparency = 1
        hrp.CanCollide = false
    end
    local rightArm = rig:FindFirstChild("Right Arm") or rig:FindFirstChild("RightUpperArm")
    if rightArm then
        rightArm.Transparency = 1
        rightArm.CanCollide = false
    end
end

-- Spike replacement tracking
local loadedSpikes = {}

local MAX_SPIKES = 24 -- max spikes to load at once

local customSpikeFolder = workspace:FindFirstChild("RochasCustomSpikes")
if not customSpikeFolder then
    customSpikeFolder = Instance.new("Folder")
    customSpikeFolder.Name = "RochasCustomSpikes"
    customSpikeFolder.Parent = workspace
end

local function loadSpikeReplacement(originalSpike)
    if loadedSpikes[originalSpike] then
        return loadedSpikes[originalSpike]
    end

    if #loadedSpikes >= MAX_SPIKES then
        -- Limit reached, don't load new spikes
        return nil
    end

    local success, models = pcall(function()
        return game:GetObjects(spikeAssetId)
    end)
    if success and models and #models > 0 then
        local newSpike = models[1]
        if newSpike:IsA("Folder") and #newSpike:GetChildren() > 0 then
            newSpike = newSpike:GetChildren()[1]
        end
        newSpike.Name = "Spike"
        newSpike.Parent = customSpikeFolder

        -- Initially position newSpike at original Spike's PrimaryPart CFrame
        if originalSpike.PrimaryPart and newSpike.PrimaryPart then
            newSpike:SetPrimaryPartCFrame(originalSpike.PrimaryPart.CFrame)
        else
            newSpike:PivotTo(originalSpike:GetPivot())
        end

        -- Make new spike parts visible and collidable, except Root part invisible
        for _, part in pairs(newSpike:GetDescendants()) do
            if part:IsA("BasePart") then
                if part.Name == "Root" then
                    part.Transparency = 1
                    part.CanCollide = false
                else
                    part.Transparency = 0
                    part.CanCollide = true
                end
            end
        end

        loadedSpikes[originalSpike] = newSpike
        return newSpike
    else
        warn("Failed to load spike replacement model")
        return nil
    end
end

local function getAllParticleEmitters(parent)
    local emitters = {}
    for _, child in pairs(parent:GetDescendants()) do
        if child:IsA("ParticleEmitter") then
            table.insert(emitters, child)
        end
    end
    return emitters
end

local maxTrails = 12
local currentTrailCount = 0
local trailInstance = nil

local loadedTrail = nil

local trailStorageFolder = workspace:FindFirstChild("CustomTrails")
if not trailStorageFolder then
    trailStorageFolder = Instance.new("Folder")
    trailStorageFolder.Name = "CustomTrails"
    trailStorageFolder.Parent = workspace
end

local function loadNewTrailOnce()
    if loadedTrail and loadedTrail.Parent then
        return loadedTrail
    end

    local success, models = pcall(function()
        return game:GetObjects("rbxassetid://72925629825816")
    end)
    if success and models and #models > 0 then
        local trailModel = models[1]
        if trailModel:IsA("Folder") and #trailModel:GetChildren() > 0 then
            trailModel = trailModel:GetChildren()[1]
        end
        trailModel.Name = "RochasTrail"
        trailModel.Parent = trailStorageFolder
        loadedTrail = trailModel
        return loadedTrail
    else
        warn("Failed to load new trail model")
        return nil
    end
end

local function updateJohnDoeTrails()
    local killerModel = workspace:FindFirstChild("Players")
        and workspace.Players:FindFirstChild("Killers")
        and workspace.Players.Killers:FindFirstChild(killerName)
    if not killerModel then return end

    local johnDoeTrailFolder = killerModel:FindFirstChild("JohnDoeTrail")
    if not johnDoeTrailFolder then return end

    local newTrail = loadNewTrailOnce()
    if not newTrail then return end

    for _, trailObj in pairs(johnDoeTrailFolder:GetChildren()) do
        if trailObj.Name == "Trail" and (trailObj:IsA("Folder") or trailObj:IsA("Instance")) then
            -- Skip if already has 3 children (means it's the new trail)
            if #trailObj:GetChildren() == 3 then
                continue
            end

            for _, child in pairs(trailObj:GetChildren()) do
                child:Destroy()
            end

            for _, child in pairs(newTrail:GetChildren()) do
                child:Clone().Parent = trailObj
            end
        end
    end
end

-- GUI creation
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "RochasChangerGUI"
ScreenGui.Parent = game.CoreGui

local Frame = Instance.new("Frame")
Frame.Size = UDim2.new(0, 260, 0, 120)
Frame.Position = UDim2.new(0.5, -130, 0.5, -60)
Frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
Frame.BorderSizePixel = 0
Frame.Active = true
Frame.Draggable = true
Frame.Parent = ScreenGui

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -20, 0, 25)
StatusLabel.Position = UDim2.new(0, 10, 0, 10)
StatusLabel.BackgroundTransparency = 1
StatusLabel.TextColor3 = Color3.new(1, 1, 1)
StatusLabel.Font = Enum.Font.SourceSans
StatusLabel.TextSize = 18
StatusLabel.Text = "Status: Idle"
StatusLabel.Parent = Frame

local Button = Instance.new("TextButton")
Button.Size = UDim2.new(1, -20, 0, 50)
Button.Position = UDim2.new(0, 10, 0, 45)
Button.Text = "Start Rochas Rig Proxy"
Button.Font = Enum.Font.SourceSansBold
Button.TextSize = 20
Button.TextColor3 = Color3.new(1,1,1)
Button.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
Button.BorderSizePixel = 0
Button.Parent = Frame

local rigInstance = nil
local heartbeatConnection = nil

local function stopRochasProxy()
    getgenv().RochasChangerRunning = false
    if heartbeatConnection then
        heartbeatConnection:Disconnect()
        heartbeatConnection = nil
    end
    if rigInstance then
        rigInstance:Destroy()
        rigInstance = nil
    end

    -- Reset JohnDoe visibility
    local killerModel = workspace:FindFirstChild("Players")
        and workspace.Players:FindFirstChild("Killers")
        and workspace.Players.Killers:FindFirstChild(killerName)
    if killerModel then
        for _, part in pairs(killerModel:GetDescendants()) do
            if part:IsA("BasePart") then
                if part.Name == Trail then
                    return
                end
                part.Transparency = 0
                part.CanCollide = true
            elseif part:IsA("Decal") or part:IsA("Texture") then
                part.Transparency = 0
            end
        end
    end

    -- Remove all loaded spike replacements
    for original, replacement in pairs(loadedSpikes) do
        if replacement and replacement.Parent then
            replacement:Destroy()
        end
    end
    loadedSpikes = {}

    StatusLabel.Text = "Status: Stopped"
    Button.Text = "Start Rochas Rig Proxy"
end

local function startRochasProxy()
    local killerModel = workspace:FindFirstChild("Players")
        and workspace.Players:FindFirstChild("Killers")
        and workspace.Players.Killers:FindFirstChild(killerName)
    repeat
        task.wait(0)
    until workspace:FindFirstChild("Players")
        and workspace.Players:FindFirstChild("Killers")
        and workspace.Players.Killers:FindFirstChild(killerName)
    if not killerModel then
        warn("Killer model not found")
        StatusLabel.Text = "Status: Killer not found"
        return
    end

    local torso = killerModel:FindFirstChild("Torso")
    if not torso then
        warn("Killer torso not found")
        StatusLabel.Text = "Status: Torso missing"
        return
    end

    if torso.Color ~= torsoColor then
        warn("Torso color mismatch")
        StatusLabel.Text = "Status: Torso color mismatch"
        return
    end

    local killerHumanoid = killerModel:FindFirstChildOfClass("Humanoid")
    if not killerHumanoid then
        warn("Killer humanoid missing")
        StatusLabel.Text = "Status: No Humanoid"
        return
    end

    -- Load rig and prep
    local rig = loadRig()
    if not rig then
        StatusLabel.Text = "Status: Failed to load rig"
        return
    end

    local rigHumanoid = rig:FindFirstChildOfClass("Humanoid")
    if not rigHumanoid then
        rig:Destroy()
        StatusLabel.Text = "Status: Rig has no Humanoid"
        return
    end

    setModelInvisible(killerModel)
    setRigNonCollidable(rig)
    makePartsInvisible(rig)

    rigInstance = rig

    StatusLabel.Text = "Status: Running"
    Button.Text = "Stop Rochas Rig Proxy"

    heartbeatConnection = RunService.Heartbeat:Connect(function()
        if not getgenv().RochasChangerRunning then
            stopRochasProxy()
            return
        end

        rig:FindFirstChild("Humanoid").DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

        -- Sync rig position & yaw rotation to killer HRP
        local killerHRP = killerModel:FindFirstChild("HumanoidRootPart")
        local rigHRP = rig:FindFirstChild("HumanoidRootPart")
        if killerHRP and rigHRP then
            local pos = killerHRP.Position
            local _, y, _ = killerHRP.CFrame:ToEulerAnglesYXZ() -- yaw only
            rigHRP.CFrame = CFrame.new(pos) * CFrame.Angles(0, y, 0)
        end

        -- Dynamic animation syncing
        updateRigAnimations(killerHumanoid, rigHumanoid)
        updateJohnDoeTrails()

        -- Spike replacement logic
        local ingameMap = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Ingame")
        if ingameMap then
            local spikeCount = 0
            for _, spike in pairs(ingameMap:GetChildren()) do
                if spike:IsA("Model") and spike.Name == "Spike" then
                    if spikeCount >= MAX_SPIKES then
                        break
                    end

                    -- Make original spike invisible
                    setModelInvisible(spike)

                    -- Load or get replacement spike
                    local replacementSpike = loadSpikeReplacement(spike)
                    if replacementSpike and spike.PrimaryPart and replacementSpike.PrimaryPart then
                        -- Continuously sync replacement spike position to original spike position
                        replacementSpike:SetPrimaryPartCFrame(spike.PrimaryPart.CFrame)
                    end
                    spikeCount = spikeCount + 1
                end
            end
        end
    end)
end

Button.MouseButton1Click:Connect(function()
    if getgenv().RochasChangerRunning then
        stopRochasProxy()
    else
        getgenv().RochasChangerRunning = true
        startRochasProxy()
    end
end)

-- Intro text replacement loop (every frame) with GUI refresh
task.spawn(function()
    while getgenv().RochasChangerRunning do
        task.wait(0) -- every frame

        local gui = LocalPlayer:FindFirstChild("PlayerGui")
        if gui then
            local intro = gui:FindFirstChild("IntroScreen")
            if intro and intro:FindFirstChild("Main") and intro.Main:FindFirstChild("Title") then
                local textLabel = intro.Main.Title
                if typeof(textLabel.Text) == "string" and textLabel.Text:find("I've always been here.") then
                    -- Destroy and recreate the killer's GUI to refresh text
                    intro.Main.Title:Destroy()

                    -- Wait a tiny bit before recreating (to avoid race conditions)
                    task.wait(0.05)

                    local newTitle = Instance.new("TextLabel")
                    newTitle.Name = "Title"
                    newTitle.Size = UDim2.new(1, 0, 1, 0)
                    newTitle.BackgroundTransparency = 1
                    newTitle.TextColor3 = Color3.new(1, 1, 1)
                    newTitle.Font = Enum.Font.SourceSansBold
                    newTitle.TextSize = 24
                    newTitle.Text = "SPREAD."
                    newTitle.Parent = intro.Main
                end
            end
        end
    end
end)
