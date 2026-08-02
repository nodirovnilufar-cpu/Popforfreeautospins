-- Optimized Auto-Obby Script for Delta (fixed target lookup and waypoint handling)

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local TARGET_NAME = "EXPERT"
print("Script started! Searching for target: " .. TARGET_NAME)

local function getTargetPart()
    -- Prefer player lookup (if TARGET_NAME is a player username)
    local targetPlayer = Players:FindFirstChild(TARGET_NAME)
    if targetPlayer and targetPlayer.Character then
        local char = targetPlayer.Character
        local hrp = char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
        if hrp and hrp:IsA("BasePart") then
            return hrp
        end
    end

    -- Fallback: search workspace for a BasePart or Model with HRP
    local found = workspace:FindFirstChild(TARGET_NAME, true)
    if not found then
        return nil
    end

    if found:IsA("BasePart") then
        return found
    elseif found:IsA("Model") then
        local hrp = found:FindFirstChild("HumanoidRootPart") or found.PrimaryPart
        if hrp and hrp:IsA("BasePart") then
            return hrp
        end
    end

    return nil
end

local function walkToTarget(targetPosition)
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local hrp = character:FindFirstChild("HumanoidRootPart")
    
    if not humanoid or not hrp or humanoid.Health <= 0 then 
        return 
    end

    local path = PathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = true,
        AgentJumpHeight = 10
    })

    local ok, err = pcall(function()
        path:ComputeAsync(hrp.Position, targetPosition)
    end)
    if not ok then
        warn("PATH COMPUTE ERROR: " .. tostring(err))
        return
    end

    if path.Status ~= Enum.PathStatus.Success then
        warn("PATH ERROR: Path status not success (" .. tostring(path.Status) .. ")")
        return
    end

    local waypoints = path:GetWaypoints()
    for _, waypoint in ipairs(waypoints) do
        if humanoid.Health <= 0 then break end

        if waypoint.Action == Enum.PathWaypointAction.Jump then
            humanoid.Jump = true
        end

        local reached = false
        local connection
        connection = humanoid.MoveToFinished:Connect(function(reachedArg)
            reached = reachedArg -- boolean provided by the event
            if connection then connection:Disconnect() end
        end)

        humanoid:MoveTo(waypoint.Position)

        -- Adaptive timeout: based on distance (0.6s per stud) with a min/max cap
        local dist = (hrp.Position - waypoint.Position).Magnitude
        local timeoutLimit = math.clamp(dist * 0.6, 1.5, 6) -- seconds
        local elapsed = 0
        while not reached and elapsed < timeoutLimit do
            task.wait(0.1)
            elapsed = elapsed + 0.1

            -- If player manually moves (input), break out of navigation loop but try to recompute later
            if humanoid.MoveDirection.Magnitude > 0 and elapsed > 0.3 then
                if connection then connection:Disconnect() end
                return -- stop current navigation; main loop will retry
            end
        end

        if connection then connection:Disconnect() end
    end
end

-- Main loop
task.spawn(function()
    while true do
        task.wait(1)
        local targetPart = getTargetPart()
        if targetPart then
            -- protect against target disappearing between lookup and move
            if targetPart.Parent then
                walkToTarget(targetPart.Position)
            end
        else
            print("Target '" .. TARGET_NAME .. "' not found, retrying...")
            task.wait(2)
        end
    end
end)
