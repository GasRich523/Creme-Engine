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
		
		--Dived
		local CanDive = not self.Moves.Dive.Active and not self.Moves.Dive.OnCooldown and not self.Moves.LongJump.Active and not self.Moves.Glide.Active and not self.Moves.Backflip.Active and not self.Moves.Stun.Active
		local InAir = self.Humanoid.FloorMaterial == Enum.Material.Air
		if CanDive and InAir then
			self.Moves.Dive.Active = true
			self.Moves.Dive.OnCooldown = true --Will end when the player lands
			
			--Cleanup
			self.Moves.Dive.Trove:Clean()
			
			--Impulse
			self.Humanoid.JumpHeight = self.Moves.JumpHeight
			self.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			self.Humanoid.RootPart.AssemblyLinearVelocity += Vector3.new(0, self.Moves.Dive.HEIGHT, 0)
			
			--Update JumpCount
			self.Moves.Jump.Count = self.Moves.Jump.MAXJUMPS - 1
			
			--Run
			local function Run(): ()
				self.Humanoid.RootPart.AssemblyLinearVelocity = self.Humanoid.RootPart.CFrame.LookVector.Unit * self.Moves.Dive.SPEED + Vector3.new(0, self.Humanoid.RootPart.AssemblyLinearVelocity.Y, 0)
				local LookAt = CFrame.lookAt(self.Humanoid.RootPart.Position, self.Humanoid.RootPart.Position + self.Humanoid.RootPart.AssemblyLinearVelocity)
				Root.C0 = (Root.Part0 :: BasePart).CFrame:Inverse() * LookAt * (Root.C1)
			end
			self.Moves.Dive.Trove:Add(RunService.PostSimulation:Connect(Run))
			
			--Play Animation
			local PlayDive = self.Humanoid.Animator:LoadAnimation(Animations.Moveset.Dive)
			self.Moves.Dive.Trove:Add(function()
				if PlayDive then PlayDive:Stop(); PlayDive:Destroy() end
			end)
			PlayDive:Play(0.2)
			
			--Show Effect
			local Effect = Effects.Moveset.AirTrail:Clone()
			Effect.Attachment0 = self.Humanoid.RootPart:FindFirstChild("RootAttachment")
			Effect.Attachment1 = self.Humanoid.RootPart:FindFirstChild("RootRigAttachment")
			Effect.Parent = self.Humanoid.RootPart
			self.Moves.Dive.Trove:Add(function()
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
		self.Moves.Dive.Trove:Clean()
		
		--Stop Vel
		Root.C0 = C0
		if self.Moves.Dive.Active then
			self.Humanoid.RootPart.AssemblyLinearVelocity = Vector3.zero
		end
		self.Moves.Dive.Active = false
	end
end