--!strict

----- Services -----

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

----- Variables -----

local Assets = ReplicatedStorage:WaitForChild("Assets")
local Animations = Assets.Animations
local Effects = Assets.Effects

local Moveset = require(script.Parent.Parent)

local Player = Players.LocalPlayer
local C0: CFrame

local RayParams = RaycastParams.new()
RayParams.FilterType = Enum.RaycastFilterType.Exclude

----- Move -----

--- Respawned ---

local function Respawned(newCharacter: Model): ()
	C0 = (newCharacter:WaitForChild("LowerTorso"):WaitForChild("Root") :: Motor6D).C0
	RayParams.FilterDescendantsInstances = {newCharacter}
end
Player.CharacterAdded:Connect(Respawned)
if Player.Character then Respawned(Player.Character) end

--- Method ---

return function(self: Moveset.InternalObject, Active: boolean, State: Enum.HumanoidStateType?): ()
	local LowerTorso = self.Character and self.Character:FindFirstChild("LowerTorso")
	local Root = LowerTorso and LowerTorso:FindFirstChild("Root") :: Motor6D
	local BHS, BTS, BPS = self.Humanoid and self.Humanoid:FindFirstChild("BodyHeightScale") :: NumberValue, self.Humanoid and self.Humanoid:FindFirstChild("BodyTypeScale") :: NumberValue, self.Humanoid and self.Humanoid:FindFirstChild("BodyProportionScale") :: NumberValue --Yeah sorry I don't like this long line either
	local Height: number = BHS and BTS and BPS and BHS.Value * (4 + BTS.Value * (math.pi / 2 - 0.6 * BHS.Value)) + 1 or 1
	assert(self.Humanoid and self.Humanoid.RootPart and Root and Height)
	assert(not State or State == Enum.HumanoidStateType.Freefall or State == Enum.HumanoidStateType.Landed)
	
	--Active
	if Active then
		
		--Stunned
		local CanStun = (not self.Moves.Stun.Active or State == Enum.HumanoidStateType.Landed) and not self.Moves.Stun.OnCooldown
		if CanStun then
			self.Moves.Stun.Active = true
			
			--Cleanup
			self.Moves.Stun.Trove:Clean()
			
			--Cooldown
			self.Moves.Stun.OnCooldown = true
			task.delay(0.2, function()
				self.Moves.Stun.OnCooldown = false
			end)
			
			--Effect
			local Effect = Effects.Moveset.AirTrail:Clone()
			Effect.Attachment0 = self.Humanoid.RootPart:FindFirstChild("RootAttachment")
			Effect.Attachment1 = self.Humanoid.RootPart:FindFirstChild("RootRigAttachment")
			Effect.Parent = self.Humanoid.RootPart
			self.Moves.Stun.Trove:Add(function(): ()
				if Effect then
					Effect.Enabled = false
					task.delay(0.5, function(): ()
						if Effect then Effect:Destroy() end
					end)
				end
			end)
			
			--Particle
			local Particle = Effects.Moveset.DustCloud:Clone()
			Particle.Parent = self.Humanoid.RootPart:FindFirstChild("RootAttachment")
			Particle:Emit(5)
			task.delay(1, function()
				if Particle then Particle:Destroy() end
			end)
			
			--Air Stun
			local PlayStun: AnimationTrack = nil
			if State == Enum.HumanoidStateType.Freefall then
				
				--Animation
				PlayStun = self.Humanoid.Animator:LoadAnimation(Animations.Moveset.StunAir)
				
				--Impulse
				self.Humanoid.JumpHeight = self.Moves.JumpHeight
				self.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
				self.Humanoid.RootPart.AssemblyLinearVelocity += Vector3.new(0, self.Moves.Stun.HEIGHT, 0)
				
				--Prevent Jumping
				self.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
				
				--Run
				local function Run(): ()
					self.Humanoid.AutoRotate = false
					self.Humanoid.WalkSpeed = 0
					
					--Push
					self.Humanoid.RootPart.AssemblyLinearVelocity = self.Humanoid.RootPart.CFrame.LookVector.Unit * -self.Moves.Stun.SPEED + Vector3.new(0, self.Humanoid.RootPart.AssemblyLinearVelocity.Y, 0)
					local LookAt = CFrame.lookAt(self.Humanoid.RootPart.Position, self.Humanoid.RootPart.Position - self.Humanoid.RootPart.AssemblyLinearVelocity)
					Root.C0 = (Root.Part0 :: BasePart).CFrame:Inverse() * LookAt * (Root.C1)
					
					--Collision
					local FloorFound = workspace:Raycast(self.Humanoid.RootPart.Position, Vector3.new(0, -Height, 0), RayParams)
					if FloorFound then
						self.Moves.Stun.Toggle(self, true, Enum.HumanoidStateType.Landed)
					end
				end
				self.Moves.Stun.Trove:Add(RunService.PostSimulation:Connect(Run))
				
			--Ground Stun
			elseif State == Enum.HumanoidStateType.Landed then
				
				--Animation
				PlayStun = self.Humanoid.Animator:LoadAnimation(Animations.Moveset.StunGround)
				
				--Restore State
				self.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
				
				--Run
				local StartTime = os.clock()
				local function Run(): ()
					self.Humanoid.AutoRotate = false
					self.Humanoid.WalkSpeed = 0
					
					--Push
					local TimePassed = os.clock() - StartTime
					local Factor = TimePassed / (self.Moves.Stun.DURATION * 1.5)
					local Speed = self.Moves.Stun.SPEED * (1 - Factor)
					self.Humanoid.RootPart.AssemblyLinearVelocity = self.Humanoid.RootPart.CFrame.LookVector.Unit * -Speed + Vector3.new(0, self.Humanoid.RootPart.AssemblyLinearVelocity.Y, 0)
					Root.C0 = C0
					
					--Cancel
					if TimePassed >= self.Moves.Stun.DURATION or self.Humanoid.FloorMaterial == Enum.Material.Air then
						return self.Moves.Stun.Toggle(self, false)
					end
				end
				self.Moves.Stun.Trove:Add(RunService.PostSimulation:Connect(Run))
			end
			
			--Play Animation
			self.Moves.Stun.Trove:Add(function()
				if PlayStun then PlayStun:Stop(); PlayStun:Destroy() end
			end)
			PlayStun:Play()
		end
		
	else --Inactive
		
		--Cleanup
		self.Moves.Stun.Trove:Clean()
		
		--Restore AutoRotate/WalkSpeed
		if self.Moves.Stun.Active then
			self.Humanoid.AutoRotate = true
			self.Humanoid.WalkSpeed = self.Moves.WalkSpeed
			self.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
			Root.C0 = C0
		end
		self.Moves.Stun.Active = false
	end
end