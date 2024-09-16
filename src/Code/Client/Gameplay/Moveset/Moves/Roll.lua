--!strict

----- Services -----

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

----- Variables -----

local Assets = ReplicatedStorage:WaitForChild("Assets")
local Animations = Assets.Animations

local Moveset = require(script.Parent.Parent)

----- Move -----

--- Method ---

return function(self: Moveset.InternalObject, Active: boolean, Landing: boolean?): ()
	assert(self.Humanoid and self.Character and self.Humanoid.RootPart and self.Character:FindFirstChild("Head"))
	
	--Active
	if Active then
		
		--Rolled
		local CanRoll = not self.Moves.Roll.Active and not self.Moves.Stun.Active
		local OnAir = self.Humanoid.FloorMaterial == Enum.Material.Air
		if CanRoll and not OnAir then
			self.Moves.Roll.Active = true
			
			--Cleanup
			self.Moves.Roll.Trove:Clean()
			
			--Play Animation
			local PlayRoll = self.Humanoid.Animator:LoadAnimation(Animations.Moveset.Roll)
			self.Moves.Roll.Trove:Add(function()
				if PlayRoll then PlayRoll:Stop(); PlayRoll:Destroy() end
			end)
			PlayRoll:Play()
			
			--Run
			local function Run(): ()
				local MoveDir = self.Humanoid.RootPart.CFrame.LookVector
				local Speed = (MoveDir * (not Landing and self.Moves.Roll.SPEED or self.Moves.Roll.SHORT_SPEED) + Vector3.new(0, self.Humanoid.RootPart.AssemblyLinearVelocity.Y, 0))
				self.Humanoid.RootPart.AssemblyLinearVelocity = Speed
			end
			self.Moves.Roll.Trove:Add(RunService.PostSimulation:Connect(Run))
			
			--End Move
			task.delay(self.Moves.Roll.DURATION, function()
				if self.Moves.Roll.Active then
					self.Moves.Roll.Toggle(self, false)
				end
			end)
		end
		
	else --Inactive
		
		--Cleanup
		self.Moves.Roll.Trove:Clean()
		self.Moves.Roll.Active = false	
	end
end