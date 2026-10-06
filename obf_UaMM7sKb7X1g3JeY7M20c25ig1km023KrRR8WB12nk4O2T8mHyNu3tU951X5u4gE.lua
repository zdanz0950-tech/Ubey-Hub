-- ==========================================
-- UBEY HUB - Kebun Hangout & HWID Auth
-- ==========================================

local SUPABASE_URL = "https://ndmomqdxmfecbjtjmzge.supabase.co"
local SUPABASE_KEY = "sb_publishable_g-sgyG652KcpFv5O..." -- Masukkan Publishable Key kamu di sini

local HttpService = game:GetService("HttpService")
local cloneref = cloneref or function(o) return o end
local Players = cloneref(game:GetService("Players"))
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local Workspace = cloneref(game:GetService("Workspace"))
local SoundService = cloneref(game:GetService("SoundService"))
local VirtualUser = cloneref(game:GetService("VirtualUser"))
local LocalPlayer = Players.LocalPlayer

-- Fungsi untuk mengambil HWID unik perangkat HP
local function getHWID()
    if gethwid then
        return gethwid()
    elseif syn and syn.get_hwid then
        return syn.get_hwid()
    else
        return tostring(LocalPlayer.UserId)
    end
end

local playerHWID = getHWID()

-- Fungsi verifikasi Key ke Supabase (Bebas Pindah Game / Auto Update HWID di 1 Perangkat)
local function verifyKey(inputKey)
    local url = SUPABASE_URL .. "/rest/v1/keys?key_value=eq." .. HttpService:UrlEncode(inputKey)
    
    local headers = {
        ["apikey"] = SUPABASE_KEY,
        ["Authorization"] = "Bearer " .. SUPABASE_KEY,
        ["Content-Type"] = "application/json"
    }

    local success, response = pcall(function()
        return syn.request({
            Url = url,
            Method = "GET",
            Headers = headers
        })
    end)

    if not success then
        return false, "Gagal terhubung ke server database!"
    end

    local data = HttpService:JSONDecode(response.Body)

    if #data == 0 then
        return false, "Key tidak valid atau salah!"
    end

    local keyData = data[1]

    -- Cek status aktif key
    if keyData.status and keyData.status == "Expired" then
        return false, "Key ini sudah kedaluwarsa!"
    end

    -- Update atau sinkronkan HWID otomatis ke perangkat saat ini tanpa memblokir game lain
    local updateUrl = SUPABASE_URL .. "/rest/v1/keys?key_value=eq." .. HttpService:UrlEncode(inputKey)
    local updateBody = HttpService:JSONEncode({ hwid = playerHWID, status = "Active" })
    
    local updateHeaders = {
        ["apikey"] = SUPABASE_KEY,
        ["Authorization"] = "Bearer " .. SUPABASE_KEY,
        ["Content-Type"] = "application/json",
        ["Prefer"] = "return=minimal"
    }

    pcall(function()
        syn.request({
            Url = updateUrl,
            Method = "PATCH",
            Headers = updateHeaders,
            Body = updateBody
        })
    end)

    return true, "Login Berhasil! Key aktif di perangkat ini."
end

-- Remote Events (Sawah)
local SeedShopRemotes = ReplicatedStorage:WaitForChild("SeedShopRemotes", 5)
local BuySeedEvent = SeedShopRemotes and SeedShopRemotes:WaitForChild("BuySeed", 5)
local PlantEvent = ReplicatedStorage:WaitForChild("PlantEvent", 5)
local PlantActionEvent = ReplicatedStorage:WaitForChild("PlantActionEvent", 5)
local SellEvent = ReplicatedStorage:WaitForChild("SellEvent", 5)

-- Remote Events (Mining System)
local MiningRemotes = ReplicatedStorage:WaitForChild("MiningSystemRemotes", 5)
local MiningStartRequest = MiningRemotes and MiningRemotes:WaitForChild("MiningStartRequest", 5)
local MiningActionEvent = MiningRemotes and MiningRemotes:WaitForChild("MiningActionEvent", 5)

-- Remote Event (Chicken Catch)
local ChickenRemotes = ReplicatedStorage:WaitForChild("ChickenCatchRemotes", 5)
local SwingNetEvent = ChickenRemotes and ChickenRemotes:WaitForChild("SwingNet", 5)

-- Remote Events & Folders (Butterfly / Kupu-Kupu)
local ButterflyRemotes = ReplicatedStorage:WaitForChild("VillageButterflies", 5)
local CatchButterflyEvent = ButterflyRemotes and ButterflyRemotes:WaitForChild("Catch", 5)

-- Remote Events (Fishing System)
local FishingRemotes = ReplicatedStorage:WaitForChild("FishingSystemRemotes", 5)
local FishingActionEvent = FishingRemotes and FishingRemotes:WaitForChild("Action", 5)
local FishingPhaseEvent = FishingRemotes and FishingRemotes:WaitForChild("Phase", 5)

-- Konfigurasi Default & Pilihan Bibit
getgenv().SelectedSeed = "Matahari"
getgenv().AutoSellInterval = 5
local SawahModel = Workspace:WaitForChild("Sawah", 5)
local MAX_PLANTS = 30

-- Koordinat Sawah, Water & Sumur
local PlantPosition = Vector3.new(-15.134395599365234, 10.973939895629883, -473.38986206054688)
local WaterPosition = Vector3.new(-15.134395599365234, 13.673937797546387, -473.38986206054688)
local FishingCastTarget = Vector3.new(-92.823776245117188, 8, -305.47808837890625)

local SellCFrame = CFrame.new(
    -6.58236408, 12.9271421, -407.487854, 
    0.0403795838, 3.357815e-08, 0.99918443, 
    2.3621336e-08, 1, -3.45601556e-08, 
    -0.99918443, 2.49975951e-08, 0.0403795838
)

-- CFrame Penjual Tambang, Ayam, Kupu-kupu & Susu
local MiningSellCFrame = CFrame.new(-206.505844, 12.6999979, -433.204315, 0.969809055, 1.57811968e-08, 0.24386552, -2.09505693e-08, 1, 1.8603922e-08, -0.24386552, -2.31513742e-08, 0.969809055)
local ChickenSellCFrame = CFrame.new(-72.7465286, 12.499999, -152.334641, 0.115703702, 3.83616126e-08, 0.993283749, -6.97474123e-09, 1, -3.78085403e-08, -0.993283749, -2.55330934e-09, 0.115703702)
local ButterflySellCFrame = CFrame.new(-71.4649429, 12.499999, -173.004608, -0.0785275698, -1.82409876e-09, 0.996911943, 6.02684747e-09, 1, 2.30448882e-09, -0.996911943, 6.18920204e-09, -0.0785275698)
local MilkSellCFrame = CFrame.new(82.8893051, 23.2939873, -676.127625, 0.999944627, -1.16198784e-07, 0.0105238697, 1.15764458e-07, 1, 4.18796802e-08, -0.0105238697, -4.06590708e-08, 0.999944627)

-- Daftar CFrame 4 Lokasi Tambang
local MiningLocations = {
    ["Batu Bara 1"] = CFrame.new(-395.596588, 33.9701958, -535.331848, -0.234104395, 0.819247544, 0.523477435, 0.961516201, 0.274748325, 1.58250332e-05, -0.143811569, 0.503335714, -0.852039576),
    ["Diamond"] = CFrame.new(-378.382233, 29.6900635, -551.896606, -0.816186666, 0.518062115, 0.255834013, 0.577788353, 0.731835961, 0.361354053, -2.46763229e-05, 0.442750275, -0.89664495),
    ["Gold"] = CFrame.new(-340.845306, 34.2572861, -635.2724, 0.235785246, 0.66882515, 0.705037773, 0.23444663, 0.6649158, -0.709169805, -0.943101346, 0.332505524, -2.64644623e-05),
    ["Batubara 2"] = CFrame.new(-304.255035, 26.3019257, -662.946533, -0.821258426, -0.0497378074, 0.568384886, -0.0604742579, 0.99816978, -3.20263207e-05, -0.567342997, -0.0343989469, -0.822763205)
}

local MiningOrderList = {"Batu Bara 1", "Diamond", "Gold", "Batubara 2"}
getgenv().SelectedMiningZone = "Batu Bara 1"
getgenv().AutoLoopMining = false
getgenv().MiningTimerDuration = 3 
getgenv().AntiSitEnabled = false
getgenv().AntiAfkEnabled = false

-- Status Toggle & Config
getgenv().AutoBuyRunning = false
getgenv().AutoFarmRunning = false
getgenv().AutoSellRunning = false
getgenv().AutoSellMiningRunning = false
getgenv().AutoSellMiningInterval = 5
getgenv().AutoSellChickenRunning = false
getgenv().AutoSellChickenInterval = 5
getgenv().AutoSellButterflyRunning = false
getgenv().AutoSellButterflyInterval = 5
getgenv().AutoSellMilkRunning = false
getgenv().AutoSellMilkInterval = 5

getgenv().AutoCatchChickenRunning = false
getgenv().AutoCatchButterflyRunning = false
getgenv().AutoMineRunning = false
getgenv().AutoFeedAnimalRunning = false
getgenv().AutoCollectMilkRunning = false
getgenv().AutoFishingRunning = false

local IsFarmBusy = false
local IsMiningBusy = false
local IsCatchBusy = false
getgenv().IsKandangBusy = false

-- Variable Auto Fishing State Management
local CurrentFishingSession = nil
local CurrentFishingPhase = "Idle"

-- Fungsi Aman Anti Pental saat Teleport
local function SafeTeleport(targetCFrame)
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        local hrp = char.HumanoidRootPart
        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        hrp.CFrame = targetCFrame
        task.wait(0.05)
        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
    end
end

local function TeleportToSawah()
    SafeTeleport(CFrame.new(PlantPosition + Vector3.new(0, 3, 0)))
end

local function ExecuteSell()
    if not SellEvent then return end
    pcall(function()
        SafeTeleport(SellCFrame)
        task.wait(0.3)
        SellEvent:FireServer("ALL")
        task.wait(0.2)
        SellEvent:FireServer("SellAll")
        task.wait(0.2)
        SellEvent:FireServer()
    end)
end

-- Fungsi Jual Hasil Tambang
local function ExecuteMiningSell()
    pcall(function()
        SafeTeleport(MiningSellCFrame)
        task.wait(0.5)
        
        local tokoModel = Workspace:FindFirstChild("Toko Jual Hasil Tambang")
        if tokoModel then
            local prompt = tokoModel:FindFirstChild("MiningSellPrompt", true)
            if prompt and prompt:IsA("ProximityPrompt") then
                fireproximityprompt(prompt)
                task.wait(0.5)
                fireproximityprompt(prompt)
            end
        else
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj.Name == "MiningSellPrompt" and obj:IsA("ProximityPrompt") then
                    fireproximityprompt(obj)
                    task.wait(0.5)
                    fireproximityprompt(obj)
                    break
                end
            end
        end
    end)
end

-- Fungsi Jual Hasil Tangkap Ayam
local function ExecuteChickenSell()
    pcall(function()
        SafeTeleport(ChickenSellCFrame)
        task.wait(0.5)
        for _, prompt in ipairs(Workspace:GetDescendants()) do
            if prompt:IsA("ProximityPrompt") and (prompt.Name:lower():find("chicken") or prompt.Name:lower():find("ayam") or prompt.Name:lower():find("sell")) then
                local dist = (prompt.Parent:GetPivot().Position - ChickenSellCFrame.Position).Magnitude
                if dist < 15 then
                    fireproximityprompt(prompt)
                    task.wait(0.5)
                    fireproximityprompt(prompt)
                    break
                end
            end
        end
    end)
end

-- Fungsi Jual Hasil Tangkap Kupu-Kupu
local function ExecuteButterflySell()
    pcall(function()
        SafeTeleport(ButterflySellCFrame)
        task.wait(0.5)
        for _, prompt in ipairs(Workspace:GetDescendants()) do
            if prompt:IsA("ProximityPrompt") and (prompt.Name:lower():find("butterfly") or prompt.Name:lower():find("kupu") or prompt.Name:lower():find("sell")) then
                local dist = (prompt.Parent:GetPivot().Position - ButterflySellCFrame.Position).Magnitude
                if dist < 15 then
                    fireproximityprompt(prompt)
                    task.wait(0.5)
                    fireproximityprompt(prompt)
                    break
                end
            end
        end
    end)
end

-- Fungsi Jual Susu (Menggunakan Deteksi Distance Prompt Milk Stand)
local function ExecuteMilkSell()
    pcall(function()
        SafeTeleport(MilkSellCFrame)
        task.wait(0.8)

        local char = LocalPlayer.Character
        local rootPart = char and char:FindFirstChild("HumanoidRootPart")
        if not rootPart then return end

        local targetPrompt = nil
        local shortestDist = 20

        for _, prompt in ipairs(Workspace:GetDescendants()) do
            if prompt:IsA("ProximityPrompt") then
                local parentPart = prompt.Parent
                if parentPart then
                    local parentPos = parentPart:IsA("BasePart") and parentPart.Position or (parentPart:IsA("Model") and parentPart:GetPivot().Position)
                    if parentPos then
                        local dist = (rootPart.Position - parentPos).Magnitude
                        if dist < shortestDist then
                            shortestDist = dist
                            targetPrompt = prompt
                        end
                    end
                end
            end
        end

        if targetPrompt then
            fireproximityprompt(targetPrompt)
            task.wait(0.4)
            fireproximityprompt(targetPrompt)
        end
    end)
end

local function CountSeedInInventory()
    local count = 0
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local character = LocalPlayer.Character
    
    local function checkContainer(container)
        if not container then return end
        for _, item in ipairs(container:GetChildren()) do
            if item:IsA("Tool") then
                local itemName = item.Name:lower()
                local selectedLower = getgenv().SelectedSeed:lower()
                
                if itemName:find(selectedLower) or itemName:find("bibit") then
                    local stack = item:GetAttribute("JumlahBibit") or item:GetAttribute("Amount") or item:GetAttribute("Count") or item:GetAttribute("Stok")
                    if not stack then
                        local numFromBracket = item.Name:match("%((%d+)%)")
                        if numFromBracket then stack = tonumber(numFromBracket) end
                    end
                    if not stack then
                        local numFromName = tonumber(item.Name:match("%d+"))
                        if numFromName then stack = numFromName end
                    end
                    count = count + (stack or 0)
                end
            end
        end
    end
    
    checkContainer(backpack)
    checkContainer(character)
    return count
end

local function CountActivePlants()
    local count = 0
    local targetReadyName = getgenv().SelectedSeed .. "_Ready"
    local targetNormalName = getgenv().SelectedSeed
    
    for _, Object in ipairs(Workspace:GetDescendants()) do
        if Object and Object.Parent and (Object.Name == targetReadyName or Object.Name == targetNormalName or Object.Name:match(getgenv().SelectedSeed)) then
            count = count + 1
        end
    end
    return count
end

local function CountReadyPlants()
    local count = 0
    local targetReadyName = getgenv().SelectedSeed .. "_Ready"
    
    for _, Object in ipairs(Workspace:GetDescendants()) do
        if Object and Object.Parent and Object.Name == targetReadyName then
            if Object:IsA("BasePart") or (Object:IsA("Model") and Object.PrimaryPart) then
                count = count + 1
            end
        end
    end
    return count
end

local function FindReadyPlant()
    local targetReadyName = getgenv().SelectedSeed .. "_Ready"
    for _, Object in ipairs(Workspace:GetDescendants()) do
        if Object and Object.Parent and Object.Name == targetReadyName then
            if Object:IsA("BasePart") or (Object:IsA("Model") and Object.PrimaryPart) then
                return Object
            end
        end
    end
    return nil
end

local function FindNearestChicken()
    local chickenFolder = Workspace:FindFirstChild("ChickenCatchSystem") and Workspace.ChickenCatchSystem:FindFirstChild("AyamBerkeliaran")
    if not chickenFolder then return nil end
    
    local closestChicken = nil
    local shortestDistance = math.huge
    local char = LocalPlayer.Character
    local rootPart = char and char:FindFirstChild("HumanoidRootPart")
    
    if not rootPart then return nil end
    
    for _, chicken in ipairs(chickenFolder:GetChildren()) do
        local targetPart = chicken:IsA("Model") and (chicken.PrimaryPart or chicken:FindFirstChildWhichIsA("BasePart"))
        if targetPart then
            local distance = (rootPart.Position - targetPart.Position).Magnitude
            if distance < shortestDistance then
                shortestDistance = distance
                closestChicken = chicken
            end
        end
    end
    return closestChicken
end

local function FindNearestButterfly()
    local visualsFolder = Workspace:FindFirstChild("ButterflyVisuals")
    if not visualsFolder then return nil end
    
    local closestButterfly = nil
    local shortestDistance = math.huge
    local char = LocalPlayer.Character
    local rootPart = char and char:FindFirstChild("HumanoidRootPart")
    
    if not rootPart then return nil end
    
    for _, bfly in ipairs(visualsFolder:GetChildren()) do
        local targetPart = bfly:IsA("Model") and (bfly.PrimaryPart or bfly:FindFirstChildWhichIsA("BasePart")) or (bfly:IsA("BasePart") and bfly)
        if targetPart then
            local distance = (rootPart.Position - targetPart.Position).Magnitude
            if distance < shortestDistance then
                shortestDistance = distance
                closestButterfly = bfly
            end
        end
    end
    return closestButterfly
end

local function FindOreNearCFrame(targetPos)
    local miningSystem = Workspace:FindFirstChild("MiningSystem")
    if not miningSystem then return nil, math.huge end
    
    local closestOre = nil
    local shortestDistance = math.huge
    
    for _, child in ipairs(miningSystem:GetChildren()) do
        if child:IsA("Folder") or child:IsA("Model") then
            for _, ore in ipairs(child:GetChildren()) do
                local targetPart = ore:IsA("Model") and (ore.PrimaryPart or ore:FindFirstChildWhichIsA("BasePart")) or (ore:IsA("BasePart") and ore)
                
                if targetPart then
                    local distance = (targetPos - targetPart.Position).Magnitude
                    if distance < shortestDistance then
                        shortestDistance = distance
                        closestOre = ore
                    end
                end
            end
        end
    end
    
    return closestOre, shortestDistance
end

local function AutoEquipNet()
    pcall(function()
        local char = LocalPlayer.Character
        local backpack = LocalPlayer:FindFirstChild("Backpack")
        if not char or not backpack then return end
        
        local currentTool = char:FindFirstChildOfClass("Tool")
        if currentTool and (currentTool.Name:match("Jaring") or currentTool.Name:match("Net")) then return end
        
        for _, item in ipairs(backpack:GetChildren()) do
            if item:IsA("Tool") and (item.Name:match("Jaring") or item.Name:match("Net")) then
                local humanoid = char:FindFirstChildOfClass("Humanoid")
                if humanoid then humanoid:EquipTool(item) end
                break
            end
        end
    end)
end

local function TouchTargetWithTool(targetPart)
    pcall(function()
        local char = LocalPlayer.Character
        if not char then return end
        
        local currentTool = nil
        for _, child in ipairs(char:GetChildren()) do
            if child:IsA("Tool") and (child.Name:match("Jaring") or child.Name:match("Net")) then
                currentTool = child
                break
            end
        end
        
        local toolPart = currentTool and (currentTool:FindFirstChild("Handle") or currentTool:FindFirstChildWhichIsA("BasePart"))
        
        if toolPart and targetPart and targetPart:IsA("BasePart") then
            toolPart.CFrame = targetPart.CFrame
            firetouchinterest(toolPart, targetPart, 0)
            firetouchinterest(toolPart, targetPart, 1)
        end
    end)
end

local function AutoEquipPickaxe()
    pcall(function()
        local char = LocalPlayer.Character
        local backpack = LocalPlayer:FindFirstChild("Backpack")
        if not char or not backpack then return end
        
        local currentTool = char:FindFirstChildOfClass("Tool")
        if currentTool and (currentTool.Name:lower():find("alat") or currentTool.Name:lower():find("pickaxe") or currentTool.Name:lower():find("diamond")) then return end
        
        for _, item in ipairs(backpack:GetChildren()) do
            if item:IsA("Tool") then
                local nameLower = item.Name:lower()
                if nameLower:find("alat") or nameLower:find("pickaxe") or nameLower:find("diamond") or nameLower:find("batu") then
                    local humanoid = char:FindFirstChildOfClass("Humanoid")
                    if humanoid then humanoid:EquipTool(item) end
                    return
                end
            end
        end
    end)
end

local function AutoEquipFishingRod()
    pcall(function()
        local char = LocalPlayer.Character
        local backpack = LocalPlayer:FindFirstChild("Backpack")
        if not char or not backpack then return end
        
        local currentTool = char:FindFirstChildOfClass("Tool")
        if currentTool and (currentTool.Name:lower():find("pancing") or currentTool.Name:lower():find("rod") or currentTool.Name:lower():find("fiber") or currentTool.Name:lower():find("bambu")) then return end
        
        for _, item in ipairs(backpack:GetChildren()) do
            if item:IsA("Tool") then
                local nameLower = item.Name:lower()
                if nameLower:find("pancing") or nameLower:find("rod") or nameLower:find("fiber") or nameLower:find("bambu") or nameLower:find("carbon") then
                    local humanoid = char:FindFirstChildOfClass("Humanoid")
                    if humanoid then humanoid:EquipTool(item) end
                    return
                end
            end
        end
    end)
end

local function AutoEquipEmber()
    pcall(function()
        local char = LocalPlayer.Character
        local backpack = LocalPlayer:FindFirstChild("Backpack")
        if not char or not backpack then return end
        
        local currentTool = char:FindFirstChildOfClass("Tool")
        if currentTool and currentTool.Name:lower():find("prem") then return end
        
        for _, item in ipairs(backpack:GetChildren()) do
            if item:IsA("Tool") then
                local nameLower = item.Name:lower()
                if nameLower:find("ember") and (nameLower:find("prem") or nameLower:find("premium")) then
                    local humanoid = char:FindFirstChildOfClass("Humanoid")
                    if humanoid then humanoid:EquipTool(item) end
                    return
                end
            end
        end
    end)
end

local function AutoRefillWater()
    pcall(function()
        local sumurModel = Workspace:FindFirstChild("SUMUR")
        if not sumurModel then return end

        local targetPrompt = sumurModel:FindFirstChildWhichIsA("ProximityPrompt", true)
        if targetPrompt and targetPrompt.Parent then
            local promptPart = targetPrompt.Parent
            local targetPos = promptPart:IsA("BasePart") and promptPart.Position or (promptPart:IsA("Model") and promptPart.PrimaryPart.Position)

            if targetPos then
                SafeTeleport(CFrame.new(targetPos + Vector3.new(2, 2, 0)))
                task.wait(0.4)
                AutoEquipEmber()
                task.wait(0.3)
                fireproximityprompt(targetPrompt)
                task.wait(0.8)
            end
        end
    end)
end

-- Deteksi Kandang Pemilik
local function TriggerCowBarnPrompt(promptName)
    pcall(function()
        local cowBarns = Workspace:FindFirstChild("CowBarns")
        if not cowBarns then return end

        local myBarn = nil
        local myName = LocalPlayer.Name:lower()
        local myDisplayName = LocalPlayer.DisplayName:lower()

        for _, barn in ipairs(cowBarns:GetChildren()) do
            for _, descendant in ipairs(barn:GetDescendants()) do
                if descendant:IsA("TextLabel") or descendant:IsA("StringValue") or descendant:IsA("TextButton") then
                    local textVal = tostring(descendant.Text or descendant.Value):lower()
                    if textVal:find(myName) or textVal:find(myDisplayName) then
                        myBarn = barn
                        break
                    end
                end
            end
            if myBarn then break end
        end

        if not myBarn then
            for _, barn in ipairs(cowBarns:GetChildren()) do
                for _, descendant in ipairs(barn:GetDescendants()) do
                    if descendant.Name:lower():find("sapi") or descendant.Name:lower():find("hewan") or descendant.Name:lower():find("cow") then
                        myBarn = barn
                        break
                    end
                end
                if myBarn then break end
            end
        end

        if myBarn then
            local targetPrompt = myBarn:FindFirstChild(promptName, true)
            if targetPrompt and targetPrompt:IsA("ProximityPrompt") then
                local parentPart = targetPrompt.Parent
                if parentPart then
                    local targetPos = parentPart:IsA("BasePart") and parentPart.Position or (parentPart:IsA("Model") and parentPart:GetPivot().Position)
                    if targetPos then
                        SafeTeleport(CFrame.new(targetPos + Vector3.new(0, 3, 0)))
                        task.wait(0.4)
                        fireproximityprompt(targetPrompt)
                        task.wait(0.3)
                        fireproximityprompt(targetPrompt)
                    end
                end
            end
        end
    end)
end

-- Listener Event Phase Mancing
if FishingPhaseEvent then
    FishingPhaseEvent.OnClientEvent:Connect(function(data)
        if typeof(data) == "table" and data.Phase then
            CurrentFishingPhase = data.Phase
            if data.SessionId then
                CurrentFishingSession = data.SessionId
            end

            if data.Phase == "Caught" or data.Phase == "Success" or data.Phase == "Failed" then
                task.delay(1.5, function()
                    if getgenv().AutoFishingRunning then
                        CurrentFishingPhase = "Idle"
                        CurrentFishingSession = nil
                    end
                end)
            end
        end
    end)
end

-- Load Rayfield UI dengan KeySystem Aktif
local successRayfield, Rayfield = pcall(function()
    return loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
end)

if not successRayfield or not Rayfield then return end

local Window = Rayfield:CreateWindow({
   Name = "🌾 Ubey Hub | Kebun Hangout🌱",
   LoadingTitle = "Ubey Hub",
   LoadingSubtitle = "by D4NZ",
   ConfigurationSaving = { Enabled = true, FolderName = "UbeyHubConfig", FileName = "UbeyKebunKeyStore" },
   Discord = { Enabled = false, Invite = "noinvitelink", RememberJoins = true },
   KeySystem = true, -- Mengaktifkan Key System
   KeySettings = { 
       Title = "UBEY HUB - Authentication", 
       Subtitle = "Verifikasi Key & HWID", 
       Note = "Dapatkan key resmi dari Discord UBEY HUB.", 
       FileName = "UbeyKebunKeyStore", 
       SaveKey = true, 
       GrabKeyFromSite = false, 
       Key = {
           "UBEY-TEST-KEY",
           "UBEY-VIP-2026"
       } 
   }
})

-- Validasi Key Rayfield ke Database Supabase
Window.VerifyKey = function(enteredKey)
    local isValid, message = verifyKey(enteredKey)
    Rayfield:Notify({
        Title = "Status Verifikasi Key",
        Content = message,
        Duration = 6.5
    })
    return isValid
end

-- Tab 1: Home & Farm
local MainTab = Window:CreateTab("Farm Sawah🌾", nil)
MainTab:CreateSection("Farming Sawah")

MainTab:CreateDropdown({
   Name = "Pilih Jenis Bibit",
   Options = {"Matahari", "Padi", "Tomat", "Jagung", "Wortel", "Pisang"},
   CurrentOption = {"Matahari"},
   Callback = function(Option) getgenv().SelectedSeed = Option[1] end,
})

MainTab:CreateToggle({
   Name = "Auto Buy Seed",
   CurrentValue = false,
   Callback = function(Value) getgenv().AutoBuyRunning = Value end,
})

MainTab:CreateToggle({
   Name = "🚀 Auto Farm",
   CurrentValue = false,
   Callback = function(Value)
        getgenv().AutoFarmRunning = Value
        if not Value then IsFarmBusy = false end
        if Value then TeleportToSawah() end
   end,
})

MainTab:CreateSection("Auto Sell Sawah")
MainTab:CreateToggle({
   Name = "💰 Aktifkan Auto Sell Dengan waktu",
   CurrentValue = false,
   Callback = function(Value) getgenv().AutoSellRunning = Value end,
})

MainTab:CreateSlider({
   Name = "⏱️Waktu (Menit)",
   Range = {1, 30},
   Increment = 1,
   CurrentValue = 5,
   Callback = function(Value) getgenv().AutoSellInterval = Value end,
})

-- Tab 2: Mining
local MiningTab = Window:CreateTab("⛏ Auto Mining", nil)
MiningTab:CreateSection("Pengaturan Lokasi Tambang")

MiningTab:CreateDropdown({
   Name = "Pilih Lokasi Tambang ",
   Options = {"Batu Bara 1", "Diamond", "Gold", "Batubara 2"},
   CurrentOption = {"Batu Bara 1"},
   Callback = function(Option)
        getgenv().SelectedMiningZone = Option[1]
   end,
})

MiningTab:CreateToggle({
   Name = "🔄 Auto Berpindah Lokasi",
   CurrentValue = false,
   Callback = function(Value)
        getgenv().AutoLoopMining = Value
   end,
})

MiningTab:CreateSlider({
   Name = "Durasi Waktu Per Lokasi (Detik)",
   Range = {0, 10},
   Increment = 0.5,
   CurrentValue = 3,
   Callback = function(Value)
        getgenv().MiningTimerDuration = Value
   end,
})

MiningTab:CreateButton({
   Name = "📍 Teleport Instan ke Lokasi Tambang Terpilih",
   Callback = function()
        pcall(function()
            local targetCF = MiningLocations[getgenv().SelectedMiningZone]
            if targetCF then
                SafeTeleport(targetCF)
            end
        end)
   end,
})

MiningTab:CreateSection("Sistem Auto Mining")
MiningTab:CreateToggle({
   Name = "Auto Mining",
   CurrentValue = false,
   Callback = function(Value) getgenv().AutoMineRunning = Value end,
})

MiningTab:CreateSection("💎 Auto Sell Hasil Tambang")
MiningTab:CreateToggle({
   Name = "💰 Auto Sell Hasil Tambang",
   CurrentValue = false,
   Callback = function(Value) getgenv().AutoSellMiningRunning = Value end,
})

MiningTab:CreateSlider({
   Name = "Delay Auto Sell Tambang (Menit)",
   Range = {1, 10},
   Increment = 1,
   CurrentValue = 5,
   Callback = function(Value) getgenv().AutoSellMiningInterval = Value end,
})

MiningTab:CreateButton({
   Name = "🏪 Teleport Instan ke Penjual",
   Callback = function()
        SafeTeleport(MiningSellCFrame)
   end,
})

-- Tab 3: Fishing
local FishingTab = Window:CreateTab("🎣 Auto Fishing", nil)
FishingTab:CreateSection("Auto Mancing")

FishingTab:CreateToggle({
   Name = "🎣 Auto Fishing",
   CurrentValue = false,
   Callback = function(Value)
        getgenv().AutoFishingRunning = Value
        if not Value then
            CurrentFishingPhase = "Idle"
            CurrentFishingSession = nil
        end
   end,
})

-- Tab 4: Catching
local CatchTab = Window:CreateTab("🐔Auto Catch🦋", nil)
CatchTab:CreateSection("Chicken & Butterfly")

CatchTab:CreateToggle({
   Name = "Auto Catch Chicken (Ayam)",
   CurrentValue = false,
   Callback = function(Value) getgenv().AutoCatchChickenRunning = Value end,
})

CatchTab:CreateToggle({
   Name = "Auto Catch Butterfly (Kupu-Kupu)",
   CurrentValue = false,
   Callback = function(Value) getgenv().AutoCatchButterflyRunning = Value end,
})

CatchTab:CreateSection("🐔 Auto Sell Chicken(Ayam)")
CatchTab:CreateToggle({
   Name = "💰 Auto Sell Chicken(Ayam)",
   CurrentValue = false,
   Callback = function(Value) getgenv().AutoSellChickenRunning = Value end,
})

CatchTab:CreateSlider({
   Name = "Delay Auto Sell Chicken(Ayam) (Menit)",
   Range = {1, 10},
   Increment = 1,
   CurrentValue = 5,
   Callback = function(Value) getgenv().AutoSellChickenInterval = Value end,
})

CatchTab:CreateButton({
   Name = "🏪 Teleport Instan ke Penjual Ayam",
   Callback = function()
        SafeTeleport(ChickenSellCFrame)
   end,
})

CatchTab:CreateSection("🦋 Auto Sell Kupu-Kupu")
CatchTab:CreateToggle({
   Name = "💰 Auto Sell Kupu-Kupu",
   CurrentValue = false,
   Callback = function(Value) getgenv().AutoSellButterflyRunning = Value end,
})

CatchTab:CreateSlider({
   Name = "Delay Auto Sell Kupu-Kupu (Menit)",
   Range = {1, 10},
   Increment = 1,
   CurrentValue = 5,
   Callback = function(Value) getgenv().AutoSellButterflyInterval = Value end,
})

CatchTab:CreateButton({
   Name = "🏪 Teleport Instan ke Penjual Kupu-Kupu",
   Callback = function()
        SafeTeleport(ButterflySellCFrame)
   end,
})

-- Tab 5: Kandang
local KandangTab = Window:CreateTab("🐄 Peternakan", nil)
KandangTab:CreateSection("Auto Farm Peternakan")

KandangTab:CreateToggle({
   Name = "Auto Kasih Makan Hewan (Tiap 2 Menit)",
   CurrentValue = false,
   Callback = function(Value) getgenv().AutoFeedAnimalRunning = Value end,
})

KandangTab:CreateToggle({
   Name = "Auto Ambil Susu (Tiap 2 Menit)",
   CurrentValue = false,
   Callback = function(Value) getgenv().AutoCollectMilkRunning = Value end,
})

KandangTab:CreateSection("🥛 Auto Sell Susu")

KandangTab:CreateToggle({
   Name = "💰 Auto Sell Susu",
   CurrentValue = false,
   Callback = function(Value) getgenv().AutoSellMilkRunning = Value end,
})

KandangTab:CreateSlider({
   Name = "Delay Auto Sell Susu (Menit)",
   Range = {1, 10},
   Increment = 1,
   CurrentValue = 5,
   Callback = function(Value) getgenv().AutoSellMilkInterval = Value end,
})

KandangTab:CreateButton({
   Name = "🏪 Teleport Instan ke Penjual Susu",
   Callback = function()
        SafeTeleport(MilkSellCFrame)
   end,
})

-- Tab 6: Player
local PlayerTab = Window:CreateTab("⚡ Player", nil)

PlayerTab:CreateSection("Pengaturan Karakter & Keamanan")
PlayerTab:CreateToggle({
   Name = "🛡 Anti Sit (Cegah Karakter Duduk)",
   CurrentValue = false,
   Callback = function(Value)
        getgenv().AntiSitEnabled = Value
   end,
})

PlayerTab:CreateToggle({
   Name = "⏳ Anti AFK (Cegah Kena Kick Idle)",
   CurrentValue = false,
   Callback = function(Value)
        getgenv().AntiAfkEnabled = Value
   end,
})

PlayerTab:CreateSlider({
   Name = "WalkSpeed Slider",
   Range = {1, 350},
   Increment = 1,
   CurrentValue = 16,
   Callback = function(Value)
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            LocalPlayer.Character.Humanoid.WalkSpeed = Value
        end
   end,
})

--- LOOPS ---
local oldIdledConnection
oldIdledConnection = LocalPlayer.Idled:Connect(function()
    if getgenv().AntiAfkEnabled then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new(0, 0))
        end)
    end
end)

task.spawn(function()
    while true do
        if getgenv().AntiAfkEnabled then
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new(0, 0))
            end)
        end
        task.wait(60)
    end
end)

task.spawn(function()
    while true do
        if getgenv().AntiSitEnabled then
            pcall(function()
                local char = LocalPlayer.Character
                if char then
                    local humanoid = char:FindFirstChildOfClass("Humanoid")
                    if humanoid and humanoid.Sit then
                        humanoid.Sit = false
                    end
                    for _, obj in ipairs(Workspace:GetDescendants()) do
                        if (obj:IsA("Seat") or obj:IsA("VehicleSeat")) and not obj.Disabled then
                            obj.Disabled = true
                        end
                    end
                end
            end)
        end
        task.wait(0.2)
    end
end)

-- Loop Auto Fishing
task.spawn(function()
    local lastActionTime = tick()

    while true do
        if getgenv().AutoFishingRunning and not IsFarmBusy and not IsMiningBusy and not IsCatchBusy and not getgenv().IsKandangBusy then
            pcall(function()
                AutoEquipFishingRod()
                
                if FishingActionEvent then
                    if CurrentFishingPhase ~= "Idle" and (tick() - lastActionTime > 8) then
                        CurrentFishingPhase = "Idle"
                        CurrentFishingSession = nil
                    end

                    if CurrentFishingPhase == "Idle" then
                        lastActionTime = tick()
                        FishingActionEvent:FireServer({
                            Action = "Cast",
                            Target = FishingCastTarget
                        })
                        CurrentFishingPhase = "Waiting"
                        task.wait(1.2)

                    elseif CurrentFishingPhase == "Bite" or CurrentFishingPhase == "Reeling" or CurrentFishingPhase == "ReelProgress" then
                        lastActionTime = tick()
                        if CurrentFishingSession then
                            for i = 1, 3 do
                                FishingActionEvent:FireServer({
                                    Action = "ReelTap",
                                    SessionId = CurrentFishingSession
                                })
                            end
                        end
                        task.wait(0.01)

                    elseif CurrentFishingPhase == "Caught" or CurrentFishingPhase == "Success" then
                        task.wait(1.0)
                        CurrentFishingPhase = "Idle"
                        CurrentFishingSession = nil
                    end
                end
            end)
        else
            task.wait(0.5)
        end
        task.wait(0.01)
    end
end)

task.spawn(function()
    while true do
        if getgenv().AutoBuyRunning then
            pcall(function()
                local currentSeeds = CountSeedInInventory()
                if BuySeedEvent and currentSeeds <= 20 then
                    for i = 1, 7 do
                        if not getgenv().AutoBuyRunning then break end
                        BuySeedEvent:FireServer(getgenv().SelectedSeed)
                        task.wait(0.3)
                    end
                    task.wait(5)
                end
            end)
        end
        task.wait(2)
    end
end)

task.spawn(function()
    while true do
        if getgenv().AutoFarmRunning then
            pcall(function()
                while getgenv().IsKandangBusy or getgenv().AutoMineRunning or IsMiningBusy or IsCatchBusy do task.wait(0.5) end
                TeleportToSawah()
                IsFarmBusy = true
                
                while getgenv().AutoFarmRunning and not getgenv().IsKandangBusy and not getgenv().AutoMineRunning and not IsMiningBusy and not IsCatchBusy and CountActivePlants() < MAX_PLANTS do
                    if PlantEvent then
                        PlantEvent:FireServer(PlantPosition, SawahModel, getgenv().SelectedSeed)
                        task.wait(0.25)
                    else
                        task.wait(0.5)
                    end
                end
                
                if getgenv().AutoFarmRunning and PlantActionEvent then
                    task.wait(0.3)
                    AutoRefillWater()
                    task.wait(0.5)
                    TeleportToSawah()
                    task.wait(0.3)
                    AutoEquipEmber()
                    task.wait(0.3)
                    PlantActionEvent:FireServer("WaterNearby", WaterPosition)
                    task.wait(0.5)
                end
                
                IsFarmBusy = false 
                while getgenv().AutoFarmRunning and not getgenv().IsKandangBusy and not getgenv().AutoMineRunning and not IsMiningBusy and not IsCatchBusy and CountReadyPlants() < 1 do
                    task.wait(1)
                end
                IsFarmBusy = true
                
                local emptyAttempts = 0
                while getgenv().AutoFarmRunning and not getgenv().IsKandangBusy and not getgenv().AutoMineRunning and not IsMiningBusy and not IsCatchBusy and emptyAttempts < 6 do
                    local targetInstance = FindReadyPlant()
                    if targetInstance and targetInstance.Parent and PlantActionEvent then
                        emptyAttempts = 0 
                        local targetPos = PlantPosition
                        if targetInstance:IsA("BasePart") then targetPos = targetInstance.Position end
                        SafeTeleport(CFrame.new(targetPos + Vector3.new(0, 3, 0)))
                        PlantActionEvent:FireServer("HarvestOne", { target = targetInstance, position = targetPos })
                        task.wait(0.35)
                    else
                        emptyAttempts = emptyAttempts + 1
                        task.wait(0.5)
                    end
                end
            end)
        else
            IsFarmBusy = false
            task.wait(1)
        end
        task.wait(0.05)
    end
end)

task.spawn(function()
    while true do
        if getgenv().AutoSellRunning then
            local waitTime = (getgenv().AutoSellInterval or 5) * 60
            task.wait(waitTime)
            pcall(function()
                if getgenv().AutoSellRunning then
                    IsFarmBusy = true
                    task.wait(0.5)
                    ExecuteSell()
                    task.wait(1.0)
                    if getgenv().AutoSellRunning then TeleportToSawah() end
                    IsFarmBusy = false
                end
            end)
        else
            task.wait(2)
        end
    end
end)

-- Loop Auto Sell Hasil Tambang
task.spawn(function()
    while true do
        if getgenv().AutoSellMiningRunning then
            local waitTime = (getgenv().AutoSellMiningInterval or 5) * 60
            task.wait(waitTime)
            pcall(function()
                if getgenv().AutoSellMiningRunning then
                    IsMiningBusy = true
                    task.wait(0.5)
                    ExecuteMiningSell()
                    task.wait(1.5)
                    
                    if getgenv().AutoMineRunning then
                        local currentZone = getgenv().SelectedMiningZone or "Batu Bara 1"
                        local miningCF = MiningLocations[currentZone]
                        if miningCF then SafeTeleport(miningCF) end
                    end
                    IsMiningBusy = false
                end
            end)
        else
            task.wait(2)
        end
    end
end)

-- Loop Auto Sell Ayam
task.spawn(function()
    while true do
        if getgenv().AutoSellChickenRunning then
            local waitTime = (getgenv().AutoSellChickenInterval or 5) * 60
            task.wait(waitTime)
            pcall(function()
                if getgenv().AutoSellChickenRunning then
                    IsCatchBusy = true
                    task.wait(0.5)
                    ExecuteChickenSell()
                    task.wait(1.5)
                    IsCatchBusy = false
                end
            end)
        else
            task.wait(2)
        end
    end
end)

-- Loop Auto Sell Kupu-Kupu
task.spawn(function()
    while true do
        if getgenv().AutoSellButterflyRunning then
            local waitTime = (getgenv().AutoSellButterflyInterval or 5) * 60
            task.wait(waitTime)
            pcall(function()
                if getgenv().AutoSellButterflyRunning then
                    IsCatchBusy = true
                    task.wait(0.5)
                    ExecuteButterflySell()
                    task.wait(1.5)
                    IsCatchBusy = false
                end
            end)
        else
            task.wait(2)
        end
    end
end)

-- Loop Auto Sell Susu
task.spawn(function()
    while true do
        if getgenv().AutoSellMilkRunning then
            local waitTime = (getgenv().AutoSellMilkInterval or 5) * 60
            task.wait(waitTime)
            pcall(function()
                if getgenv().AutoSellMilkRunning then
                    getgenv().IsKandangBusy = true
                    task.wait(0.5)
                    ExecuteMilkSell()
                    task.wait(1.5)
                    if getgenv().AutoFarmRunning then TeleportToSawah() end
                    getgenv().IsKandangBusy = false
                end
            end)
        else
            task.wait(2)
        end
    end
end)

local currentActiveSessionId = nil
pcall(function()
    if MiningActionEvent then
        MiningActionEvent.OnClientEvent:Connect(function(actionType, data)
            if actionType == "start" and data and data.sessionId then
                currentActiveSessionId = data.sessionId
            end
        end)
    end
end)

task.spawn(function()
    local currentZoneIndex = 1
    
    while true do
        if getgenv().AutoMineRunning and not getgenv().IsKandangBusy and not IsMiningBusy and not IsCatchBusy then
            pcall(function()
                local zoneName = getgenv().SelectedMiningZone
                if getgenv().AutoLoopMining then
                    zoneName = MiningOrderList[currentZoneIndex]
                end
                
                local exactCField = MiningLocations[zoneName]
                if exactCField then
                    SafeTeleport(exactCField)
                    task.wait(0.2)
                    
                    AutoEquipPickaxe()
                    task.wait(0.15)
                    
                    local targetOre, _ = FindOreNearCFrame(exactCField.Position)
                    if targetOre and MiningStartRequest and MiningActionEvent then
                        currentActiveSessionId = nil
                        MiningStartRequest:FireServer(targetOre)
                        task.wait(0.2)
                        
                        local targetSessionId = currentActiveSessionId or HttpService:GenerateGUID(false)
                        local startTime = tick()
                        local zoneDuration = getgenv().AutoLoopMining and (getgenv().MiningTimerDuration or 3) or 999999
                        
                        while getgenv().AutoMineRunning and not IsMiningBusy and (tick() - startTime < zoneDuration) do
                            MiningActionEvent:FireServer("tap", { sessionId = targetSessionId })
                            task.wait(0.05)
                            
                            if not targetOre or not targetOre.Parent then
                                targetOre, _ = FindOreNearCFrame(exactCField.Position)
                                if targetOre then
                                    MiningStartRequest:FireServer(targetOre)
                                    task.wait(0.2)
                                end
                            end
                        end
                        
                        currentActiveSessionId = nil
                    else
                        task.wait(0.5)
                    end
                    
                    if getgenv().AutoLoopMining then
                        currentZoneIndex = currentZoneIndex + 1
                        if currentZoneIndex > #MiningOrderList then
                            currentZoneIndex = 1
                        end
                    end
                end
            end)
        else
            task.wait(0.5)
        end
        task.wait(0.1)
    end
end)

task.spawn(function()
    while true do
        if getgenv().AutoCatchChickenRunning and not IsFarmBusy and not IsMiningBusy and not IsCatchBusy and not getgenv().IsKandangBusy then
            pcall(function()
                local chicken = FindNearestChicken()
                if chicken then
                    AutoEquipNet()
                    local chickenPart = chicken:IsA("Model") and (chicken.PrimaryPart or chicken:FindFirstChildWhichIsA("BasePart"))
                    if chickenPart then
                        SafeTeleport(CFrame.new(chickenPart.Position + Vector3.new(0, 3, 0)))
                        TouchTargetWithTool(chickenPart)
                        if SwingNetEvent then SwingNetEvent:FireServer() end
                    end
                end
            end)
            task.wait(0.05)
        else
            task.wait(0.5)
        end
    end
end)

task.spawn(function()
    while true do
        if getgenv().AutoCatchButterflyRunning and not IsFarmBusy and not IsMiningBusy and not IsCatchBusy and not getgenv().IsKandangBusy then
            pcall(function()
                local butterfly = FindNearestButterfly()
                if butterfly then
                    AutoEquipNet()
                    local bflyPart = butterfly:IsA("Model") and (butterfly.PrimaryPart or butterfly:FindFirstChildWhichIsA("BasePart")) or (bflyPart:IsA("BasePart") and butterfly)
                    
                    if bflyPart then
                        SafeTeleport(bflyPart.CFrame + Vector3.new(0, 0.5, 0))
                        TouchTargetWithTool(bflyPart)
                        
                        if SwingNetEvent then 
                            SwingNetEvent:FireServer() 
                        end
                        
                        if CatchButterflyEvent then
                            CatchButterflyEvent:FireServer(butterfly.Name)
                        end
                    end
                end
            end)
            task.wait(0.01)
        else
            task.wait(0.3)
        end
    end
end)

-- Loop Kandang (Makan & Milk) dengan Deteksi Pemilik
task.spawn(function()
    while true do
        if getgenv().AutoFeedAnimalRunning or getgenv().AutoCollectMilkRunning then
            task.wait(120)
            pcall(function()
                getgenv().IsKandangBusy = true
                task.wait(0.5)
                if getgenv().AutoFeedAnimalRunning then TriggerCowBarnPrompt("FeedPrompt") task.wait(1.5) end
                if getgenv().AutoCollectMilkRunning then TriggerCowBarnPrompt("MilkPrompt") task.wait(1.5) end
                if getgenv().AutoFarmRunning then TeleportToSawah() end
                getgenv().IsKandangBridge = false
            end)
        else
            task.wait(2)
        end
    end
end)

