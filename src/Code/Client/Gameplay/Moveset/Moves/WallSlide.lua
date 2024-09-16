--!strict

----- Services -----

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

----- Variables -----

local Assets = ReplicatedStorage:WaitForChild("Assets")
local Animations = Assets.Animations
local Effects = Assets.Effects

local Moveset = require(script.Parent.Parent)

local LastResult: RaycastResult?

----- Move -----

--- Get Normal From Face ---

function GetNormalFromFace(Part: BasePart, NormalId: Enum.NormalId): Vector3
	return Part.CFrame:VectorToWorldSpace(Vector3.FromNormalId(NormalId))
end

--- Normal To Face ---

function NormalToFace(Result: RaycastResult?): Enum.NormalId?
	local Tolerance = 0.75 --(1 - 0.001) --This works better for cylinders
	local NormalIds = {
		Enum.NormalId.Front,
		Enum.NormalId.Back,
		Enum.NormalId.Bottom,
		Enum.NormalId.Top,
		Enum.NormalId.Left,
		Enum.NormalId.Right
	}    
	
	--If close enough, return normal id
	for _, NormalId in NormalIds do
		if Result and Result.Instance:IsA("BasePart") then
			if GetNormalFromFace(Result.Instance, NormalId):Dot(Result.Normal) > Tolerance then
				return NormalId
			end
		end
	end
	return nil
end

--- Method ---

return function(self: Moveset.InternalObject, Active: boolean): ()
	local BHS, BTS, BPS = self.Humanoid and self.Humanoid:FindFirstChild("BodyHeightScale") :: NumberValue, self.Humanoid and self.Humanoid:FindFirstChild("BodyTypeScale") :: NumberValue, self.Humanoid and self.Humanoid:FindFirstChild("BodyProportionScale") :: NumberValue --Yeah sorry I don't like this long line either
	local Height: number = BHS and BTS and BPS and BHS.Value * (4 + BTS.Value * (math.pi / 2 - 0.6 * BHS.Value)) + 1 or 1
	local Head = self.Character and self.Character:FindFirstChild("Head") :: BasePart
	assert(self.Character and self.Humanoid and self.Humanoid.RootPart and Head and Height)
	
	--[[
	This was made before the LedgeGrab so the char doesn't align to the wall quite
	right yet, i'll port the maths for that over once I fix the LedgeGrab, if I ever do so
	--]]
	
	--Active
	if Active then
		
		--Raycasts
		local RootRay = workspace:Raycast(self.Humanoid.RootPart.Position, self.Humanoid.RootPart.CFrame.LookVector * self.Moves.WallSlide.DISTANCE, self.PlayerParams)
		local HeadRay = workspace:Raycast(Head.Position + Vector3.new(0, Head.Size.Y * 2, 0), Head.CFrame.LookVector * self.Moves.WallSlide.DISTANCE, self.PlayerParams)
		local ValidWall = (RootRay and HeadRay) and (RootRay.Instance == HeadRay.Instance) and (RootRay.Instance.CanCollide and RootRay.Instance.Transparency < 1)
		local Whitelisted = ValidWall and ((self.Moves.WallSlide.FILTER_TYPE == "Whitelist" and RootRay.Instance.Name == self.Moves.WallSlide.FILTER_NAME) or (self.Moves.WallSlide.FILTER_TYPE == "Blacklist" and RootRay.Instance.Name ~= self.Moves.WallSlide.FILTER_NAME))
		
		--WallSlided
		local Face, LastFace = NormalToFace(RootRay), NormalToFace(LastResult)
		local CanWallSlide = not self.Moves.WallSlide.Active and not self.Moves.LedgeGrab.Active and not self.Moves.LedgeGrab.OnCooldown and self.Humanoid.FloorMaterial == Enum.Material.Air and Whitelisted and (not LastResult or (LastResult.Instance ~= RootRay.Instance or (not Face or not LastFace or Face ~= LastFace)))
		local Busy = self.Humanoid:GetState() == Enum.HumanoidStateType.Swimming or self.Humanoid:GetState() == Enum.HumanoidStateType.Seated or self.Humanoid:GetState() == Enum.HumanoidStateType.Climbing
		if CanWallSlide and not Busy then
			self.Moves.WallSlide.Active = true
			self.Moves.Jump.Count = 0
			
			--Store Wall
			LastResult = RootRay
			
			--Cleanup
			self.Moves.WallSlide.Trove:Clean()
			
			--Face opposite side of wall
			self.Humanoid.AutoRotate = false
			self.Humanoid.RootPart.CFrame = CFrame.new(self.Humanoid.RootPart.Position, self.Humanoid.RootPart.Position + RootRay.Normal)
			
			--Force downwards
			local SlideVel = self.Moves.WallSlide.Trove:Add(Instance.new("LinearVelocity"))
			SlideVel.Attachment0 = self.Humanoid.RootPart:FindFirstChild("RootAttachment") :: Attachment
			SlideVel.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
			SlideVel.MaxForce = 1000000
			SlideVel.VectorVelocity = Vector3.new(0, -self.Moves.WallSlide.SPEED, 0)
			SlideVel.Parent = self.Humanoid.RootPart
			
			--Play Animation/Sound
			local PlayWallSlide = self.Humanoid.Animator:LoadAnimation(Animations.Moveset.WallSlide)
			self.Moves.WallSlide.Trove:Add(function()
				if PlayWallSlide then PlayWallSlide:Stop(); PlayWallSlide:Destroy() end
			end)
			PlayWallSlide:Play(0.2)
			
			--Show Particle
			local Particle = Effects.Moveset.DustCloud:Clone()
			Particle.Parent = self.Humanoid.RootPart:FindFirstChild("RootAttachment")
			Particle.Rate = 5; Particle.Enabled = true
			self.Moves.WallSlide.Trove:Add(function()
				if Particle then
					Particle.Enabled = false
					task.delay(0.3, function()
						if Particle then Particle:Destroy() end
					end)
				end
			end)
			
			--Run
			local function Run(): ()
				self.Humanoid.RootPart.CFrame = CFrame.new(self.Humanoid.RootPart.CFrame.Position, self.Humanoid.RootPart.CFrame.Position + RootRay.Normal)
				local FloorFound = workspace:Raycast(self.Humanoid.RootPart.Position, Vector3.new(0, -Height, 0), self.PlayerParams)
				local BackWallFound = workspace:Raycast(self.Humanoid.RootPart.Position, self.Humanoid.RootPart.CFrame.LookVector * -self.Moves.WallSlide.DISTANCE, self.PlayerParams)
				if FloorFound and BackWallFound then
					self.Moves.WallSlide.Toggle(self, false)
				end
			end
			self.Moves.WallSlide.Trove:Add(RunService.PostSimulation:Connect(Run))
			
		end
		
	else --Inactive
		
		--Cleanup
		self.Moves.WallSlide.Trove:Clean()
		
		--Forget Wall
		LastResult = self.Humanoid.FloorMaterial == Enum.Material.Air and LastResult or nil
		
		--Restore AutoRotate
		if self.Moves.WallSlide.Active then
			self.Humanoid.AutoRotate = true
		end
		self.Moves.WallSlide.Active = false
	end
end