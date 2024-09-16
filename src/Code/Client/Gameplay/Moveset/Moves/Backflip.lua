--!strict

----- Services -----

local ReplicatedStorage = game:GetService("ReplicatedStorage")

----- Variables -----

local Assets = ReplicatedStorage:WaitForChild("Assets")
local Animations = Assets.Animations

local Moveset = require(script.Parent.Parent)

----- Move -----

--- Method ---

return function(self: Moveset.InternalObject, Active: boolean): ()
	assert(self.Humanoid)
	
	--Active
	if Active then
		
		--Backflipped
		local CanBackflip = not self.Moves.Backflip.Active and not self.Moves.Glide.Active and not self.Moves.Stun.Active
		local InAir = self.Humanoid.FloorMaterial == Enum.Material.Air
		if CanBackflip and not InAir then
			self.Moves.Backflip.Active = true
			
			--Cleanup
			self.Moves.Backflip.Trove:Clean()
			
			--Jump
			self.Humanoid.JumpHeight = self.Moves.Backflip.HEIGHT
			self.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			self.Moves.Jump.Count = self.Moves.Jump.MAXJUMPS
			
			--Play Animation
			local PlayBackflip = self.Humanoid.Animator:LoadAnimation(Animations.Moveset.Backflip)
			self.Moves.Backflip.Trove:Add(function()
				if PlayBackflip then PlayBackflip:Stop(); PlayBackflip:Destroy() end
			end)
			PlayBackflip:Play(0.2, nil, 3.5)
			
			--End Move
			task.delay(self.Moves.Backflip.DURATION, function()
				self.Moves.Backflip.Toggle(self, false)
			end)
		end
		
	else --Inactive
		
		--Cleanup
		self.Moves.Backflip.Trove:Clean()
		
		--Restore Height
		if self.Moves.Backflip.Active then
			self.Humanoid.JumpHeight = self.Moves.JumpHeight
		end
		self.Moves.Backflip.Active = false
	end
end