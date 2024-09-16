--!strict

----- Services -----

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")

----- Variables -----

local Gameplay = workspace:WaitForChild("Gameplay")
local Checkpoints = Gameplay:WaitForChild("Checkpoints")
local InitialSpawn = Checkpoints:WaitForChild("Spawn")
local RealSpawn: SpawnLocation = nil

----- Code -----

--Set autoload to false
Players.CharacterAutoLoads = false

--Configure "Fake" Spawn
RealSpawn = Instance.new("SpawnLocation"); RealSpawn.Name = "RealSpawn"; RealSpawn.Transparency = 1; RealSpawn.Duration = 0
RealSpawn.Anchored = true; RealSpawn.CanCollide = false; RealSpawn.CanQuery = false
RealSpawn.Position = InitialSpawn.Position; RealSpawn.Parent = workspace
InitialSpawn.Enabled = false; RealSpawn.Enabled = true

--- Apply Skins ---

--local function UpdateSkin(Player: Player, SkinName: string): ()
	
--	--Cleanup
--	local StarterCharacter = StarterPlayer:FindFirstChild("StarterCharacter") :: Model
--	if StarterCharacter then
--		StarterCharacter:Destroy()
--	end
	
--	--If there's a skin (else swaps to player's avatar)
--	if SkinName then

--		--Clone
--		local Skin: Model = ServerStorage.Skins:FindFirstChild(SkinName):Clone()

--		--Swap
--		Skin.Name = "StarterCharacter"
--		Skin.Parent = StarterPlayer

--		--Unanchor
--		local RootPart = Skin:FindFirstChild("HumanoidRootPart") :: BasePart
--		if RootPart then
--			RootPart.Anchored = false
--		end

--		--Applies Scripts and such
--		for _, Script in StarterPlayer.StarterCharacterScripts:GetChildren() do
--			Script.Parent = Skin
--		end
--	end
--end

--- Load Manually ---

--PlayerAdded
local function PlayerAdded(Player: Player): ()
	task.spawn(function()
		
		-- Init --

		--Load
		--UpdateSkin(Player, "Haru")
		Player:LoadCharacter()

		--Vars
		local Character = (Player.Character or Player.CharacterAdded:Wait()) :: Model
		local Humanoid = Character:WaitForChild("Humanoid") :: Humanoid

		-- Died --
		
		local function Died()
			task.wait(Players.RespawnTime)
			--UpdateSkin(Player, "Haru")
			Player:LoadCharacter() --Load
		end
		Humanoid.Died:Connect(Died)
		
		-- Respawned --
		
		local function Respawned(UpdateChar)
			Character = UpdateChar :: Model
			Humanoid = Character:WaitForChild("Humanoid") :: Humanoid
			Humanoid.Died:Connect(Died)
		end	
		Player.CharacterAdded:Connect(Respawned)
	end)
end
Players.PlayerAdded:Connect(PlayerAdded)
for _, Player in Players:GetPlayers() do
	PlayerAdded(Player)
end