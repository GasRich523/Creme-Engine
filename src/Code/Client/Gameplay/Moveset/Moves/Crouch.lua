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

return function(self: Moveset.InternalObject, Active: boolean): ()
	assert(self.Humanoid and self.Character and self.Humanoid.RootPart and self.Character:FindFirstChild("Head"))
	
	--Active
	if Active then
		
		--Crouched
		local CanCrouch = not self.Moves.Crouch.Active and not self.Moves.Backflip.Active and not self.Moves.LongJump.Active and not self.Moves.Stun.Active
		local InAir = self.Humanoid.FloorMaterial == Enum.Material.Air
		if CanCrouch and not InAir then
			self.Moves.Crouch.Active = true
			
			--Cleanup
			self.Moves.Crouch.Trove:Clean()
			
			--Vars
			local LastCrouchSpeed: number?
			local PlayCrouch: AnimationTrack
			local AnimTrove: typeof(self.Trove) = self.Moves.Crouch.Trove:Extend()
			
			--Run
			local function Run(): ()
				local Speed = math.round(self.Humanoid.MoveDirection.Magnitude)
				if Speed ~= LastCrouchSpeed then
					AnimTrove:Clean()
					if Speed > 0 then --Walk
						PlayCrouch = self.Humanoid.Animator:LoadAnimation(Animations.Moveset.CrouchWalk)
					else --Idle
						PlayCrouch = self.Humanoid.Animator:LoadAnimation(Animations.Moveset.CrouchIdle)
					end
					AnimTrove:Add(function()
						if PlayCrouch then PlayCrouch:Stop(); PlayCrouch:Destroy() end
					end)
					LastCrouchSpeed = Speed --Update Speed
					PlayCrouch:Play(0.15) --Play
				end
			end
			self.Moves.Crouch.Trove:Add(RunService.PostSimulation:Connect(Run))
		end
		
	else --Inactive
		
		--Cleanup
		self.Moves.Crouch.Trove:Clean()
		self.Moves.Crouch.Active = false
	end
end