--!strict

----- Services -----

local ReplicatedStorage = game:GetService("ReplicatedStorage")

----- Variables -----

local Assets = ReplicatedStorage:WaitForChild("Assets")
local Animations = Assets.Animations

local Moveset = require(script.Parent.Parent)

----- Move -----

--- Method ---

return function(self: Moveset.InternalObject, Active: boolean, State: Enum.HumanoidStateType?): ()
	assert(self.Humanoid)
	
	--Active
	if Active then
		
		--Cleanup
		self.Moves.Jump.Trove:Clean()
		
		--Jumped
		local CanJump = not self.Moves.Jump.Active and not self.Moves.Glide.Active and not self.Moves.Crouch.Active and not self.Moves.Backflip.Active and not self.Moves.Roll.Active and not self.Moves.Stun.Active
		local ReachedMaxJumps = self.Moves.Jump.Count >= self.Moves.Jump.MAXJUMPS
		local Busy = self.Humanoid:GetState() == Enum.HumanoidStateType.Swimming or self.Humanoid:GetState() == Enum.HumanoidStateType.Seated
		if CanJump and not ReachedMaxJumps and not Busy then
			self.Moves.Jump.Active = true
			
			--Double Jump
			if self.Moves.Jump.Count >= 1 then
				
				--Play Animation
				local PlayDoubleJump = self.Humanoid.Animator:LoadAnimation(Animations.Moveset.DoubleJump)
				self.Moves.Jump.Trove:Add(function()
					if PlayDoubleJump then PlayDoubleJump:Stop(); PlayDoubleJump:Destroy() end
				end)
				PlayDoubleJump:Play()
				
				--Boost jump
				self.Humanoid.JumpHeight = self.Moves.JumpHeight * self.Moves.Jump.MULTIPLIER
			else
				self.Humanoid.JumpHeight = self.Moves.JumpHeight
			end
			
			--Jump
			self.Moves.Jump.Count += 1
			self.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			
		--Allows us to get out of the water/seat if we maxed the JumpCount
		elseif Busy then	
			self.Moves.Jump.Count = self.Moves.Jump.MAXJUMPS - 1
		else --Else
			self.Humanoid.JumpHeight = 0
		end
		
	else --Inactive
		
		--Landing
		if State == Enum.HumanoidStateType.Landed then
			
			--Cleanup
			self.Moves.Jump.Trove:Clean()
			
			self.Moves.Jump.Count = 0
			self.Humanoid.JumpHeight = 0
			self.Moves.Jump.Active = false

		--Resume
		elseif State == Enum.HumanoidStateType.Freefall then
			task.delay(0.2, function()
				self.Moves.Jump.Active = false
			end)
		end
	end
end