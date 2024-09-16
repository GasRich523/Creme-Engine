--!strict

--[[
Credits to D_I for the ImpactVFX's particles.
--]]

----- Services -----

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

----- Variables -----

local Assets = ReplicatedStorage:WaitForChild("Assets")
local Effects = Assets.Effects

local Moveset = require(script.Parent.Parent)

local CurrentMaterial: Enum.Material = Enum.Material.Air

----- Effect -----

--- SplitCamelCase ---

local function SplitCamelCase(Name: string): {string}
	local Result = {}
	for Chunk in Name:gmatch("%u%l*") do
		table.insert(Result, Chunk)
	end
	return Result
end

--- Find Material ---

local function FindParticle(Material: Enum.Material, Container: Folder): Instance?
	local MaterialName = Material.Name:lower()
	local CommonKeywords = {"wood", "stone", "plank", "brick", "metal", "glass", "sand", "dirt", "grass"}
	
	--[[
	I could have totally written all the names one by one, I didn't feel like it.
	--]]
	
	for _, v in Container:GetChildren() do
		local ParticleName = v.Name:lower()

		--1. Look for exact match
		if v.Name == Material.Name or ParticleName:find(MaterialName) then
			return v
		end

		--2. Look for partial matches by splitting CamelCase
		local Chunks = SplitCamelCase(Material.Name)
		for _, Chunk in ipairs(Chunks) do
			if ParticleName:find(Chunk:lower()) then
				return v
			end
		end
		
		--3. Look for common keywords found in both material and particle names
		for _, Keyword in ipairs(CommonKeywords) do
			if MaterialName:find(Keyword) and ParticleName:find(Keyword) then
				return v
			end
		end
	end

	return nil
end

--- Method ---

return function(self: Moveset.InternalObject, Active: boolean): ()
	if Active then
		assert(self.Humanoid and self.Humanoid.RootPart)
		
		--Trove
		local MaterialsTrove: typeof(self.Effects.Footsteps.Trove) = self.Trove:Extend()
		
		--Run
		local function Run(): ()
			local Busy = self.Humanoid.MoveDirection.Magnitude == 0 or self.Humanoid.FloorMaterial == Enum.Material.Air
			local NotRepeated = not Busy and self.Humanoid.FloorMaterial ~= CurrentMaterial
			local ParticleFound = (NotRepeated and FindParticle(self.Humanoid.FloorMaterial, Effects.Moveset.Footsteps)) :: Instance?
			if ParticleFound then
				
				--Update Material
				CurrentMaterial = self.Humanoid.FloorMaterial

				--Clean
				MaterialsTrove:Clean()

				--Show Effect
				local Att = Instance.new("Attachment")
				Att.Position = Vector3.new(0, -self.Humanoid.HipHeight, 1)
				Att.Parent = self.Humanoid.RootPart
				for _, Effect: ParticleEmitter in ParticleFound:GetChildren() :: any do	
					local Effect = Effect:Clone()
					Effect.Parent = Att
					Effect.Enabled = true
					if Effect:GetAttribute("UseColor") then
						local FloorFound = workspace:Raycast(self.Humanoid.RootPart.Position, Vector3.new(0, -self.Humanoid.HipHeight * 1.5, 0), self.PlayerParams)
						if FloorFound then
							Effect.Color = ColorSequence.new(FloorFound.Instance.Color)
						end
					end
					MaterialsTrove:Add(function()
						if Effect then
							Effect.Enabled = false
							task.delay(1, function()
								if Att then Att:Destroy() end
							end)
						end
					end)
				end			
			elseif (Busy or NotRepeated) and CurrentMaterial ~= Enum.Material.Air then
				CurrentMaterial = Enum.Material.Air
				MaterialsTrove:Clean()
			end
		end
		self.Effects.Footsteps.Trove:Add(RunService.PostSimulation:Connect(Run))
	else
		self.Effects.Footsteps.Trove:Clean()
	end
end