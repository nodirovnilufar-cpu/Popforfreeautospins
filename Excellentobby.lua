-- Optimized Auto-Obby Script for Delta
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local TARGET_NAME = "Excellent"
print("Script started! Searching for: " .. TARGET_NAME)

local function getTargetPart()
    local target = workspace:FindFirstChild(TARGET_NAME, true)
    if not target then
        return nil
    end
    return target
end

local function walkToTarget(targetPosition)
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local hrp = character:FindFirstChild("HumanoidRootPart")
    
    if not humanoid or not hrp or humanoid.Health <= 0 then 
        return 
    end

    -- Pathfinding agent sozlamalari
    local path = PathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = true,
        AgentJumpHeight = 10
    })

    local success, errorMessage = pcall(function()
        path:ComputeAsync(hrp.Position, targetPosition)
    end)

    if not success then
        warn("PATH ERROR: " .. tostring(errorMessage))
        return
    end

    if path.Status == Enum.PathStatus.Success then
        local waypoints = path:GetWaypoints()
        
        for _, waypoint in ipairs(waypoints) do
            -- Player o'zi boshqarsa yoki o'lib qolsa harakatni to'xtatish
            if humanoid.Health <= 0 then break end
            
            -- Agar nuqta sakrashni talab qilsa:
            if waypoint.Action == Enum.PathWaypointAction.Jump then
                humanoid.Jump = true
            end

            humanoid:MoveTo(waypoint.Position)

            -- Qotib qolmaslik uchun Timeout (ko'pida 2 soniya kutadi)
            local reached = false
            local connection
            
            connection = humanoid.MoveToFinished:Connect(function()
                reached = true
                if connection then connection:Disconnect() end
            end)

            local timeout = 0
            while not reached and timeout < 2 do
                task.wait(0.1)
                timeout = timeout + 0.1
                
                -- O'yinchi tugmalarni bossa script to'xtaydi
                if humanoid.MoveDirection.Magnitude > 0 and timeout > 0.3 then
                    if connection then connection:Disconnect() end
                    return
                end
            end
            
            if connection then connection:Disconnect() end
        end
    else
        warn("PATH ERROR: Path status not success (Path blocked or too far).")
    end
end

-- Asosiy sikl
task.spawn(function()
    while task.wait(1) do
        local targetPart = getTargetPart()
        if targetPart then
            walkToTarget(targetPart.Position)
        else
            print("Target '" .. TARGET_NAME .. "' not found, retrying...")
            task.wait(2)
        end
    end
end)
