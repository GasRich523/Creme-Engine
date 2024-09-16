--!strict

----- Services -----

local ReplicatedStorage = game:GetService("ReplicatedStorage")

----- Variables -----

local Assets = ReplicatedStorage:WaitForChild("Assets")
local Animations = Assets.Animations
local Effects = Assets.Effects

local Moveset = require(script.Parent.Parent)

----- Move -----

--- Method ---

return function(self: Moveset.InternalObject, Active: boolean): ()
	assert(self.Humanoid and self.Character)
	
	--Active
	if Active then
		
		--Glided
		local CanGlide =  not self.Moves.Glide.Active and not self.Moves.Jump.Active and not self.Moves.LongJump.Active and not self.Moves.Dive.Active and not self.Moves.Backflip.Active and not self.Moves.Stun.Active and not self.Moves.WallSlide.Active and not self.Moves.LedgeGrab.Active
		local InAir = self.Humanoid.FloorMaterial == Enum.Material.Air
		local JumpedTwice = self.Moves.Jump.Count > 1
		if CanGlide and InAir and JumpedTwice then
			self.Moves.Glide.Active = true
			
			--Cleanup
			self.Moves.Glide.Trove:Clean()
			
			--Play Animation
			local PlayGlide = self.Humanoid.Animator:LoadAnimation(Animations.Moveset.Glide)
			self.Moves.Glide.Trove:Add(function()
				if PlayGlide then PlayGlide:Stop(); PlayGlide:Destroy() end
			end)
			PlayGlide:Play(0.5, nil, 3)
			
			--Velocity
			local GlideForce = self.Moves.Glide.Trove:Add(Instance.new("Attachment"))
			local Vel = Instance.new("LinearVelocity"); Vel.Attachment0 = GlideForce
			Vel.VelocityConstraintMode = Enum.VelocityConstraintMode.Line; Vel.MaxForce = 1000000
			Vel.LineDirection = Vector3.new(0, 1, 0); Vel.LineVelocity = self.Moves.Glide.SPEED
			Vel.Parent = GlideForce; GlideForce.Parent = self.Humanoid.RootPart
			
			--Effect
			for _, Hand in self.Character:GetChildren() do
				if Hand:IsA("BasePart") and Hand.Name:find("Hand") then
					local Att0, Att1 = Hand:FindFirstChild(Hand.Name:gsub("Hand", "").."GripAttachment"), Hand:FindFirstChild(Hand.Name:gsub("Hand", "").."WristRigAttachment")
					if Att0 and Att1 then
						local GlideClone = self.Moves.Glide.Trove:Add(Effects.Moveset.AirTrail:Clone())
						GlideClone.Attachment0 = Att0; GlideClone.Attachment1 = Att1
						GlideClone.WidthScale = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 0)})
						GlideClone.Lifetime = 0.1
						GlideClone.Parent = Hand
					end
				end
			end
		end	
		
	else --Inactive
		
		--Cleanup
		self.Moves.Glide.Trove:Clean()
		self.Moves.Glide.Active = false
	end
end