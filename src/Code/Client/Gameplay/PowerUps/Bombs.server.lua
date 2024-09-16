--!strict

----- Services -----

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

----- Variables -----

local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local RootPart = Character:WaitForChild("HumanoidRootPart") :: BasePart

local Code = workspace:WaitForChild("Code")
local Shared = Code:WaitForChild("Shared")
local Goodies = Shared:WaitForChild("Goodies")

local Assets = ReplicatedStorage:WaitForChild("Assets")
local Sounds = Assets.Sounds
local Effects = Assets.Effects

local GameplayFolder = workspace:WaitForChild("Gameplay")
local PowerUpsFolder = GameplayFolder:WaitForChild("PowerUps")
local BombsFolder = PowerUpsFolder:WaitForChild("Bombs")
local DestroyableFolder = BombsFolder:WaitForChild("Destroyable")

local PowerUps = require(script.Parent)
local QuickSpring = require(Goodies.Utils.QuickSpring)

local OverParams = OverlapParams.new()
OverParams.FilterDescendantsInstances = {DestroyableFolder}
OverParams.FilterType = Enum.RaycastFilterType.Include
local PlrOverParams = OverlapParams.new()
PlrOverParams.FilterDescendantsInstances = {Character}
PlrOverParams.FilterType = Enum.RaycastFilterType.Include

local Effect: ParticleEmitter

----- Code -----

--- Setup ---

local BombsPowerup = PowerUps.new(Player, {
	Type = "Bomb",
	Icon = "rbxassetid://15751166965",
	Container = BombsFolder,
	Duration = 10
})

--- Toggled ---

local function StateChanged(State: PowerUps.PowerupStates, BombModel: Instance): ()
	
	--Attributes
	local PowerupDuration = BombModel:GetAttribute("PowerupDuration") or 6
	local Range = BombModel:GetAttribute("Range") or 15
	
	--Active
	if State == "Active" then
		
		--Play sound
		Sounds.PowerUps["Bomb Fuse"]:Play()
		
	--Inactive
	else
		
		--Completed
		if State == "Completed" then
			
			--Sound
			Sounds.PowerUps.Explosion:Play()
			
			--Effect
			if Effect then Effect:Destroy() end
			Effect = Effects.PowerUps.Explosion:Clone(); Effect.Parent = RootPart
			Effect:Emit(20)
			task.delay(1, function()
				if Effect then Effect:Destroy() end
			end)
			
			--Trigger Bomb
			local PartsFound = workspace:GetPartBoundsInRadius(RootPart.Position, Range, OverParams)
			if #PartsFound > 0 then
				local Model: Model = PartsFound[1].Parent --Gets the container model
				for _, DestroyablePart in Model:GetChildren() do
					if DestroyablePart:IsA("BasePart") then

						--Hide
						local Collide = DestroyablePart.CanCollide
						local Transparency = DestroyablePart.Transparency
						DestroyablePart.CanCollide = false
						DestroyablePart.Transparency = 1

						--Restore
						task.delay(PowerupDuration - 1, function()
							
							--Wait until player is out of range
							local ModelCF: CFrame, ModelSize: Vector3 = Model:GetBoundingBox()
							repeat 
								local PlayerInBounds: {Instance} = workspace:GetPartBoundsInRadius(ModelCF.Position, (ModelSize.X + ModelSize.Y + ModelSize.Z) / 3, PlrOverParams)
								task.wait(0.1)
							until #PlayerInBounds == 0
							
							--Restore
							if DestroyablePart then
								QuickSpring(DestroyablePart, 1, 0.8, {
									Transparency = Transparency
								}, function()
									DestroyablePart.CanCollide = Collide
								end)
							end
						end)
					end
				end
			end
		end
		
		--Cleanup
		Sounds.PowerUps["Bomb Fuse"]:Stop()
	end
end
BombsPowerup.StateChanged:Connect(StateChanged)

--- Respawned ---

local function Respawned(newChar: Model): ()
	Character = newChar
	RootPart = Character:WaitForChild("HumanoidRootPart") :: BasePart
	
	--Update Params
	PlrOverParams.FilterDescendantsInstances = {Character}
end
Player.CharacterAdded:Connect(Respawned)