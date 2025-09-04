-- Stop previous instances
if getgenv().RochasChangerRunning then
    getgenv().RochasChangerRunning = false
    task.wait(0.3)
end
getgenv().RochasChangerRunning = true

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local localCharacter = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()

-- Update on respawn
LocalPlayer.CharacterAdded:Connect(function(char)
    localCharacter = char
end)

local onlychangelocalplayerskin = false
local characterName = {
    "Jason",
    "JohnDoe",
    "c00lkidd",
    "1x1x1x1",
    "Noli",
    "TwoTime",
    "Noob",
    "Guest1337",
    "Elliot",
    "Chance",
    "Builderman",
    "Dusekkar",
    "007n7",
    "Shedletsky",
    "Taph"
}
local skinName = {
    "GeometryJohnDoe",
    "Milestone75Jason",
    "MafiosoC00l",
    "FriendElliot",
    "YAAINoli",
    "Diva1x1x1x1"
    -- add more here
} -- SkinName then  Killer name like Vanity Jason is VanityJason and geometry john doe will become GeometryJohnDoe and same for 1x1x1x1 like Diva1x1x1x1. for coolkidd its like MafiosoC00l
local rigAssetId = "rbxassetid://74773737275811"
local spikeAssetId = "rbxassetid://80855887476594"

-- Remove all old GUIs named "RochasChangerGUI"
for _, gui in pairs(game.CoreGui:GetChildren()) do
    if gui.Name == "RochasChangerGUI" then
        gui:Destroy()
    end
end

local function makeRigNonCollidable(rig)
    if not rig then return end
    for _, part in ipairs(rig:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
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

local function contains(tbl, value)
    for _, v in ipairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

local function getTargetRig()
    -- First: ActorRig in workspace.Misc
    local miscFolder = workspace:FindFirstChild("Misc")
    if miscFolder then
        for _, model in pairs(miscFolder:GetChildren()) do
            if model:IsA("Model") and model.Name:find("ActorRig") then
                return model, "ActorRig"
            end
        end
    end
    
    -- Second: JohnDoe in Killers folder
    local characterPlayerModel = workspace:FindFirstChild("Players")
        and workspace.Players:FindFirstChild("Killers")
        and workspace.Players.Killers:FindFirstChild(characterName)

    if characterPlayerModel and contains(characterName, characterPlayerModel.Name) then
        if contains(skinName, characterPlayerModel:GetAttribute("SkinName")) then
            -- Check if only changing local player's skin
            if onlychangelocalplayerskin then
                if characterPlayerModel ~= localCharacter then
                    -- Not the local player, skip
                    return nil
                end
            end
            return characterPlayerModel, characterName
        end
    else
        characterPlayerModel = workspace:FindFirstChild("Players")
            and workspace.Players:FindFirstChild("Survivors")
            and workspace.Players.Survivors:FindFirstChild(characterName)

        if characterPlayerModel and contains(characterName, characterPlayerModel.Name) and contains(skinName, characterPlayerModel:GetAttribute("SkinName")) then
            -- Check if only changing local player's skin
            if onlychangelocalplayerskin then
                if characterPlayerModel ~= localCharacter then
                    -- Not the local player, skip
                    return nil
                end
            end
            return characterPlayerModel, characterName
        end
    end
    
    return nil, nil
end

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

        -- Position newSpike at original Spike's PrimaryPart CFrame
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

local function updateJohnDoeTrails()
    local characterPlayerModel = workspace:FindFirstChild("Players")
        and workspace.Players:FindFirstChild("Killers")
        and workspace.Players.Killers:FindFirstChild(characterName)
    if not characterPlayerModel then return end

    local johnDoeTrailFolder = characterPlayerModel:FindFirstChild("JohnDoeTrail")
    if not johnDoeTrailFolder then return end

    local loadedTrail = nil
    local trailStorageFolder = workspace:FindFirstChild("CustomTrails")
    if not trailStorageFolder then
        trailStorageFolder = Instance.new("Folder")
        trailStorageFolder.Name = "CustomTrails"
        trailStorageFolder.Parent = workspace
    end

    if loadedTrail and loadedTrail.Parent then
        -- already loaded
    else
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
        else
            warn("Failed to load new trail model")
            return
        end
    end

    for _, trailObj in pairs(johnDoeTrailFolder:GetChildren()) do
        if trailObj.Name == "Trail" and (trailObj:IsA("Folder") or trailObj:IsA("Instance")) then
            -- Skip if already has 3 children (means it's the new trail)
            if #trailObj:GetChildren() == 3 then
                continue
            end

            for _, child in pairs(trailObj:GetChildren()) do
                child:Destroy()
            end

            for _, child in pairs(loadedTrail:GetChildren()) do
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
local proxyRunning = false

local function stopRochasProxy()
    proxyRunning = false
    getgenv().RochasChangerRunning = false
    if heartbeatConnection then
        heartbeatConnection:Disconnect()
        heartbeatConnection = nil
    end

    if rigInstance then
        rigInstance:Destroy()
        rigInstance = nil
    end

    -- Destroy all Models named "Rig" in workspace
    for _, model in pairs(workspace:GetChildren()) do
        if model:IsA("Model") and model.Name == "Rig" then
            model:Destroy()
        end
    end

    -- Reset JohnDoe visibility
    local characterPlayerModel = workspace:FindFirstChild("Players")
        and workspace.Players:FindFirstChild("Killers")
        and workspace.Players.Killers:FindFirstChild(characterName)
    if characterPlayerModel then
        for _, part in pairs(characterPlayerModel:GetDescendants()) do
            if part:IsA("BasePart") then
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
    proxyRunning = true
    StatusLabel.Text = "Status: Searching for rig..."

    local currentTargetType = nil

    while proxyRunning do
        local targetModel, targetType = getTargetRig()
        if not targetModel then
            StatusLabel.Text = "Status: No target found"
            for _, model in pairs(workspace:GetChildren()) do
                if model:IsA("Model") and model.Name == "Rig" then
                    model:Destroy()
                end
            end
            wait(1)
            continue
        end

        -- Auto-switch priority if needed
        if currentTargetType ~= targetType then
            -- If currently proxying JohnDoe but ActorRig shows up, restart
            if currentTargetType == "JohnDoe" and targetType == "ActorRig" then
                StatusLabel.Text = "Status: ActorRig detected, restarting proxy..."
                break -- break to restart proxy loop and prioritize ActorRig
            end
            -- If currently proxying ActorRig but no longer exists, restart to fallback
            if currentTargetType == "ActorRig" and targetType ~= "ActorRig" then
                StatusLabel.Text = "Status: ActorRig lost, restarting proxy..."
                break
            end

            currentTargetType = targetType
        end

        local killerHumanoid = targetModel:FindFirstChildOfClass("Humanoid")
        if not killerHumanoid then
            StatusLabel.Text = "Status: Target has no Humanoid"
            wait(1)
            continue
        end

        if rigInstance then
            rigInstance:Destroy()
            rigInstance = nil
        end
        rigAnimTracks = {}
        killerAnimIds = {}

        local rig = loadRig()
        if not rig then
            StatusLabel.Text = "Status: Failed to load rig"
            wait(1)
            continue
        end
        local rigHumanoid = rig:FindFirstChildOfClass("Humanoid")
        if not rigHumanoid then
            rig:Destroy()
            StatusLabel.Text = "Status: Rig has no Humanoid"
            wait(1)
            continue
        end

        setRigNonCollidable(rig)
        makeRigNonCollidable(rig)
        makePartsInvisible(rig)

        local rochasRig = rig
        game.Workspace.Rig.Torso.CanCollide = false

        if rochasRig then
            local head = rochasRig:FindFirstChild("Head")
            if head and head:IsA("BasePart") then
                head.Transparency = 1
                local headz = head:FindFirstChild("Headz")
                if headz and headz:IsA("BasePart") then
                    headz.Transparency = 1
                end
            end

            local leftArm = rochasRig:FindFirstChild("Left Arm")
            if leftArm then
                local cube001 = leftArm:FindFirstChild("Cube.001")
                if cube001 and cube001:IsA("BasePart") then
                    cube001.Transparency = 1
                end
                for _, part in ipairs(leftArm:GetDescendants()) do
                    if part:IsA("BasePart") and part.Name == "Cube.001" then
                        part.Transparency = 1
                    end
                end
            end
        end

        setModelInvisible(targetModel)

        rigInstance = rig
        StatusLabel.Text = "Status: Running (" .. targetType .. ")"
        Button.Text = "Stop Rochas Rig Proxy"

        -- Proxy loop for current target
        while proxyRunning and targetModel and targetModel.Parent do
            -- Detect if ActorRig priority changed mid-proxy
            local newTargetModel, newTargetType = getTargetRig()
            if newTargetType ~= targetType then
                -- If ActorRig appears and current proxy is JohnDoe, break to restart proxy with ActorRig
                if targetType == "JohnDoe" and newTargetType == "ActorRig" then
                    StatusLabel.Text = "Status: ActorRig appeared, restarting proxy..."
                    break
                end
                -- If ActorRig disappears and fallback needed, break to restart
                if targetType == "ActorRig" and newTargetType ~= "ActorRig" then
                    StatusLabel.Text = "Status: ActorRig lost, restarting proxy..."
                    break
                end
            end

            local targetHRP = targetModel:FindFirstChild("HumanoidRootPart")
            local rigHRP = rig:FindFirstChild("HumanoidRootPart")
            if targetHRP and rigHRP then
                local pos = targetHRP.Position
                local _, y, _ = targetHRP.CFrame:ToEulerAnglesYXZ()
                rigHRP.CFrame = CFrame.new(pos) * CFrame.Angles(0, y, 0)
            end

            updateRigAnimations(killerHumanoid, rigHumanoid)
            game.workspace.Players.Killers.JohnDoe.QueryHitbox.Transparency = 0.6
            game.workspace.Players.Killers.JohnDoe.CollisionHitbox.Transparency = 0.6
            game.workspace.Players.Killers.JohnDoe.CollisionHitbox.CanCollide = true
            game.workspace.Players.Killers.JohnDoe.QueryHitbox.CanCollide = true
            game.Workspace.Rig.Hat.CanCollide = false
            game.Workspace.Rig.Head.CanCollide = false
            game.Workspace.Rig.HumanoidRootPart.CanCollide = false
            game.Workspace.Rig["Left Arm"].CanCollide = false
            game.Workspace.Rig["Left Leg"].CanCollide = false
            game.Workspace.Rig["Right Arm"].CanCollide = false
            game.Workspace.Rig["Right Leg"].CanCollide = false
            local rochasrigrn = game.Workspace:FindFirstChild("Rig")
            rochasrigrn.Torso.CanCollide = false

            if targetType == "JohnDoe" then
                updateJohnDoeTrails()
                local ingameMap = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Ingame")
                if ingameMap then
                    local spikeCount = 0
                    for _, spike in pairs(ingameMap:GetChildren()) do
                        if spike:IsA("Model") and spike.Name == "Spike" then
                            if spikeCount >= MAX_SPIKES then break end
                            setModelInvisible(spike)
                            local replacementSpike = loadSpikeReplacement(spike)
                            if replacementSpike and spike.PrimaryPart and replacementSpike.PrimaryPart then
                                replacementSpike:SetPrimaryPartCFrame(spike.PrimaryPart.CFrame)
                            end
                            spikeCount += 1
                        end
                    end
                end
            end

            wait()
        end
    end
end

Button.MouseButton1Click:Connect(function()
    if proxyRunning then
        stopRochasProxy()
    else
        getgenv().RochasChangerRunning = true
        spawn(startRochasProxy)
    end
end)

-- Intro text replacement loop (runs in parallel)
spawn(function()
    while true do
        if getgenv().RochasChangerRunning then
            -- Replace intro text if needed
            local gui = LocalPlayer:FindFirstChild("PlayerGui")
            if gui then
                local intro = gui:FindFirstChild("IntroScreen")
                if intro and intro:FindFirstChild("Main") and intro.Main:FindFirstChild("Title") then
                    local title = intro.Main.Title
                    if typeof(title.Text) == "string" and title.Text == "I've always been here." then
                        title.Text = "SPREAD."
                    end
                end
            end
        end

        local hasActorRig = workspace:FindFirstChild("Misc") and (function()
            for _, m in pairs(workspace.Misc:GetChildren()) do
                if m.Name:find("ActorRig") then
                    return true
                end
            end
            return false
        end)() or false

        local johnDoeExists = workspace:FindFirstChild("Players") 
            and workspace.Players:FindFirstChild("Killers") 
            and workspace.Players.Killers:FindFirstChild(characterName)

        if hasActorRig then
            if game:GetService("Players").LocalPlayer.PlayerGui.IntroScreen.Main.Title.Text == "I've always been here." then
                game:GetService("Players").LocalPlayer.PlayerGui.IntroScreen.Main.Title.Text = "SPREAD."
            end
            stopRochasProxy()
            
            -- Destroy all Models named "Rig" in workspace
            for _, model in pairs(workspace:GetChildren()) do
                if model:IsA("Model") and model.Name == "Rig" then
                    model:Destroy()
                end
            end

            wait(0.1) -- small delay before restarting
            spawn(startRochasProxy)
            
            -- Wait until actor rig disappears
            repeat
                wait(0.1)
                hasActorRig = workspace:FindFirstChild("Misc") and (function()
                    for _, m in pairs(workspace.Misc:GetChildren()) do
                        if m.Name:find("ActorRig") then
                            return true
                        end
                    end
                    return false
                end)() or false
            until not hasActorRig

            stopRochasProxy()
            
            -- Destroy all Models named "Rig" in workspace again after stopping
            for _, model in pairs(workspace:GetChildren()) do
                if model:IsA("Model") and model.Name == "Rig" then
                    model:Destroy()
                end
            end

            wait(0.1)
            spawn(startRochasProxy)
        end

        local killersFolder = workspace:FindFirstChild("Players") 
            and workspace.Players:FindFirstChild("Killers")

        if getgenv().RochasChangerRunning and killersFolder and #killersFolder:GetChildren() == 0 then
            stopRochasProxy()
            for _, model in pairs(workspace:GetChildren()) do
                if model:IsA("Model") and model.Name == "Rig" then
                    model:Destroy()
                end
            end
            wait(0.1)
            spawn(startRochasProxy)
        end

        wait(0) -- small delay before next check
    end
end)
