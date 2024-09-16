--!strict

----- Services -----

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

----- Variables -----

local Assets = ReplicatedStorage:WaitForChild("Assets")
local Animations = Assets.Animations
local Effects = Assets.Effects

local Moveset = require(script.Parent.Parent)

local Player = Players.LocalPlayer
local C0: CFrame

----- Move -----

--- Respawned ---

local function Respawned(newCharacter: Model): ()
	C0 = (newCharacter:WaitForChild("LowerTorso"):WaitForChild("Root") :: Motor6D).C0
end
Player.CharacterAdded:Connect(Respawned)
if Player.Character then Respawned(Player.Character) end

--- Method ---

return function(self: Moveset.InternalObject, Active: boolean): ()
	local LowerTorso = self.Character and self.Character:FindFirstChild("LowerTorso")
	local Root = LowerTorso and LowerTorso:FindFirstChild("Root") :: Motor6D
	assert(self.Humanoid and self.Humanoid.RootPart and self.Character and Root)
	
	--Active
	if Active then
		
		--LongJumped
		local CanLongJump = not self.Moves.LongJump.Active and not self.Moves.LongJump.OnCooldown and not self.Moves.Dive.Active and not self.Moves.Glide.Active and not self.Moves.Backflip.Active and not self.Moves.Stun.Active
		local InAir = self.Humanoid.FloorMaterial == Enum.Material.Air
		if CanLongJump and not InAir then
			self.Moves.LongJump.Active = true
			
			--Cooldown
			self.Moves.LongJump.OnCooldown = true
			task.delay(0.1, function()
				self.Moves.LongJump.OnCooldown = false
			end)
			
			--Cleanup
			self.Moves.LongJump.Trove:Clean()
			
			--Impulse
			self.Humanoid.JumpHeight = self.Moves.JumpHeight
			self.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			self.Humanoid.RootPart.AssemblyLinearVelocity += Vector3.new(0, self.Moves.LongJump.HEIGHT, 0)
			
			--Update JumpCount
			self.Moves.Jump.Count = self.Moves.Jump.MAXJUMPS - 1
			
			--Run
			local function Run(): ()
				self.Humanoid.RootPart.AssemblyLinearVelocity = self.Humanoid.RootPart.CFrame.LookVector.Unit * self.Moves.LongJump.SPEED + Vector3.new(0, self.Humanoid.RootPart.AssemblyLinearVelocity.Y, 0)
				local LookAt = CFrame.lookAt(self.Humanoid.RootPart.Position, self.Humanoid.RootPart.Position + self.Humanoid.RootPart.AssemblyLinearVelocity)
				Root.C0 = (Root.Part0 :: BasePart).CFrame:Inverse() * LookAt * (Root.C1)
			end
			self.Moves.LongJump.Trove:Add(RunService.PostSimulation:Connect(Run))
			
			--Play Animation
			local PlayLongJump = self.Humanoid.Animator:LoadAnimation(Animations.Moveset.LongJump)
			self.Moves.LongJump.Trove:Add(function()
				if PlayLongJump then PlayLongJump:Stop(); PlayLongJump:Destroy() end
			end)
			PlayLongJump:Play(0.2)
			
			--Show Effect
			local Effect = Effects.Moveset.AirTrail:Clone()
			Effect.Attachment0 = self.Humanoid.RootPart:FindFirstChild("RootAttachment")
			Effect.Attachment1 = self.Humanoid.RootPart:FindFirstChild("RootRigAttachment")
			Effect.Parent = self.Humanoid.RootPart
			self.Moves.LongJump.Trove:Add(function()
				if Effect then
					Effect.Enabled = false
					task.delay(0.3, function()
						if Effect then Effect:Destroy() end
					end)
				end
			end)
		end
		
	else --Inactive
		
		--Cleanup
		self.Moves.LongJump.Trove:Clean()
		
		--Stop Vel
		Root.C0 = C0
		if self.Moves.LongJump.Active then
			self.Humanoid.RootPart.AssemblyLinearVelocity = Vector3.zero
		end
		self.Moves.LongJump.Active = false
	end
end