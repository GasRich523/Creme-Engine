--!strict

----- Services -----

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

----- Variables -----

local Assets = ReplicatedStorage:WaitForChild("Assets")
local Animations = Assets.Animations

local Moveset = require(script.Parent.Parent)

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
	local Head = self.Character and self.Character:FindFirstChild("Head") :: BasePart
	assert(self.Character and self.Humanoid and self.Humanoid.RootPart and Head)
	
	--[[
	I'm aware this move has a handful of issues but I give up trying to fix those
	atm as i'm not good at maths. If someone manages to improve it, please share it.
	
	Suggested Fixes:
	* SpeedFactor is wrong as it's speed is inconsistent
	* Raycast code repeats itself, it could be shortened
	* The chunk of code that cancels the move has false positives when switching ledges/moving
	* Only non-tilted part shapes are supported, it should be possible to support cylinders by
	adding additional raycasts, other shapes would require better math
	* If 2 walls are near each other they can bug out, a way to fix this is to setup a RayParams
	for the current ledge's part so it ignores all others
	--]]
	
	--Active
	if Active then
		local FixedHeadCF = CFrame.new(Head.Position, self.Humanoid.RootPart.Position + self.Humanoid.RootPart.CFrame.LookVector)
		local LookVector, RightVector, UpVector = (FixedHeadCF.LookVector * Vector3.new(1, 0, 1)).Unit, FixedHeadCF.RightVector, self.Humanoid.RootPart.CFrame.UpVector
		
		--Raycasts
		local UpperHeadRay = workspace:Raycast(FixedHeadCF.Position + Vector3.new(0, 1, 0), LookVector * self.Moves.LedgeGrab.DISTANCE, self.PlayerParams)
		local LowerHeadRay = workspace:Raycast(FixedHeadCF.Position + Vector3.new(0, -1, 0), LookVector * self.Moves.LedgeGrab.DISTANCE, self.PlayerParams)
		local SurfaceRay = workspace:Raycast(FixedHeadCF.Position + Vector3.new(0, 1, 0) + (LookVector * self.Moves.LedgeGrab.DISTANCE), UpVector * -self.Moves.LedgeGrab.DISTANCE, self.PlayerParams)
		local ValidWall = (not UpperHeadRay and LowerHeadRay and SurfaceRay) and (LowerHeadRay.Instance == SurfaceRay.Instance) and (LowerHeadRay.Instance:IsA("Part") and LowerHeadRay.Instance.Shape == Enum.PartType.Block) and (SurfaceRay.Normal.Y == 1) and (LowerHeadRay.Instance.CanCollide and LowerHeadRay.Instance.Transparency < 1)
		local Whitelisted = ValidWall and ((self.Moves.LedgeGrab.FILTER_TYPE == "Whitelist" and LowerHeadRay.Instance.Name == self.Moves.LedgeGrab.FILTER_NAME) or (self.Moves.LedgeGrab.FILTER_TYPE == "Blacklist" and LowerHeadRay.Instance.Name ~= self.Moves.LedgeGrab.FILTER_NAME))
		
		--LedgeGrabbed
		local CanLedgeGrab = not self.Moves.LedgeGrab.Active and not self.Moves.LedgeGrab.OnCooldown and not self.Moves.WallSlide.Active and self.Humanoid.FloorMaterial == Enum.Material.Air and Whitelisted
		local Busy = self.Humanoid:GetState() == Enum.HumanoidStateType.Swimming or self.Humanoid:GetState() == Enum.HumanoidStateType.Seated or self.Humanoid:GetState() == Enum.HumanoidStateType.Climbing
		if CanLedgeGrab and not Busy then		
			self.Moves.LedgeGrab.Active = true
			
			--Calculate Ledge Position
			local RawLedgePosition = Vector3.new(LowerHeadRay.Position.X, SurfaceRay.Position.Y, LowerHeadRay.Position.Z)
			local CharXOffset, CharYOffset = (self.Humanoid.RootPart.Size.Z / 2) + 0.5, Head.Size.Y
			local LedgePosition = RawLedgePosition - (LookVector.Unit * CharXOffset) - Vector3.new(0, CharYOffset, 0)
			
			--AlignPos
			local AlignPos = self.Moves.LedgeGrab.Trove:Add(Instance.new("AlignPosition"))
			AlignPos.Mode = Enum.PositionAlignmentMode.OneAttachment
			AlignPos.Attachment0 = self.Humanoid.RootPart:FindFirstChild("RootAttachment") :: Attachment
			AlignPos.Position = LedgePosition
			AlignPos.RigidityEnabled = true
			AlignPos.Parent = self.Humanoid.RootPart
			
			--AlignRot
			local AlignRot = self.Moves.LedgeGrab.Trove:Add(Instance.new("AlignOrientation"))
			AlignRot.Mode = Enum.OrientationAlignmentMode.OneAttachment
			AlignRot.Attachment0 = AlignPos.Attachment0
			AlignRot.CFrame = CFrame.new(self.Humanoid.RootPart.CFrame.Position, self.Humanoid.RootPart.CFrame.Position - LowerHeadRay.Normal)
			AlignRot.RigidityEnabled = true
			AlignRot.Parent = self.Humanoid.RootPart
			
			--Vars
			local LastLedgeGrabSpeed: number?
			local PlayLedgeGrab: AnimationTrack
			local AnimTrove: typeof(self.Trove) = self.Moves.LedgeGrab.Trove:Extend()
			
			--Run
			local function Run(dt: number): ()				
				local FixedHeadCF = CFrame.new(Head.Position, self.Humanoid.RootPart.Position + self.Humanoid.RootPart.CFrame.LookVector)
				local LookVector, RightVector, UpVector = (FixedHeadCF.LookVector * Vector3.new(1, 0, 1)).Unit, FixedHeadCF.RightVector, self.Humanoid.RootPart.CFrame.UpVector
				local Speed = math.round(workspace.Camera.CFrame:VectorToObjectSpace(self.Humanoid.MoveDirection).X)
				
				--Check if we are still on a ledge
				local UpperHeadRay = workspace:Raycast(FixedHeadCF.Position + Vector3.new(0, 1, 0), LookVector * self.Moves.LedgeGrab.DISTANCE, self.PlayerParams)
				local LowerHeadRay = workspace:Raycast(FixedHeadCF.Position + Vector3.new(0, -1, 0), LookVector * self.Moves.LedgeGrab.DISTANCE, self.PlayerParams)
				local SurfaceRay = workspace:Raycast(FixedHeadCF.Position + Vector3.new(0, 1, 0) + (LookVector * self.Moves.LedgeGrab.DISTANCE), UpVector * -self.Moves.LedgeGrab.DISTANCE, self.PlayerParams)
				local ValidWall = (not UpperHeadRay and LowerHeadRay and SurfaceRay) and (LowerHeadRay.Instance == SurfaceRay.Instance) and (LowerHeadRay.Instance:IsA("Part") and LowerHeadRay.Instance.Shape == Enum.PartType.Block) and (SurfaceRay.Normal.Y == 1) and (LowerHeadRay.Instance.CanCollide and LowerHeadRay.Instance.Transparency < 1)
				local Whitelisted = ValidWall and ((self.Moves.LedgeGrab.FILTER_TYPE == "Whitelist" and LowerHeadRay.Instance.Name == self.Moves.LedgeGrab.FILTER_NAME) or (self.Moves.LedgeGrab.FILTER_TYPE == "Blacklist" and LowerHeadRay.Instance.Name ~= self.Moves.LedgeGrab.FILTER_NAME))
				if not Whitelisted then
					return self.Moves.LedgeGrab.Toggle(self, false)
				end
				
				--Animate
				if Speed ~= LastLedgeGrabSpeed then
					AnimTrove:Clean()
					if Speed ~= 0 then --Moving
						if Speed > 0 then --Right
							PlayLedgeGrab = self.Humanoid.Animator:LoadAnimation(Animations.Moveset.LedgeGrabRight)
						else --Left
							PlayLedgeGrab = self.Humanoid.Animator:LoadAnimation(Animations.Moveset.LedgeGrabLeft)
						end
					else --Idle
						PlayLedgeGrab = self.Humanoid.Animator:LoadAnimation(Animations.Moveset.LedgeGrabIdle)
					end
					AnimTrove:Add(function()
						if PlayLedgeGrab then PlayLedgeGrab:Stop(); PlayLedgeGrab:Destroy() end
					end)
					LastLedgeGrabSpeed = Speed --Update Speed
					PlayLedgeGrab:Play(0.15) --Play
				end
				
				--Move
				if Speed ~= 0 then
					
					--Look for other surfaces (starts at the direction you are going, goes in parallel to that)
					local SpeedFactor = (self.Humanoid.WalkSpeed / 10) * dt
					local UpperSideRay = workspace:Raycast(FixedHeadCF.Position + Vector3.new(0, 1, 0) + (RightVector * Speed * self.Moves.LedgeGrab.DISTANCE * math.sqrt(2) * SpeedFactor), (RightVector * -Speed * self.Moves.LedgeGrab.DISTANCE * math.sqrt(2) * SpeedFactor) + (LookVector * self.Moves.LedgeGrab.DISTANCE * math.sqrt(2) * SpeedFactor), self.PlayerParams)
					local LowerSideRay = workspace:Raycast(FixedHeadCF.Position + Vector3.new(0, -1, 0) + (RightVector * Speed * self.Moves.LedgeGrab.DISTANCE * math.sqrt(2) * SpeedFactor), (RightVector * -Speed * self.Moves.LedgeGrab.DISTANCE * math.sqrt(2) * SpeedFactor) + (LookVector * self.Moves.LedgeGrab.DISTANCE * math.sqrt(2) * SpeedFactor), self.PlayerParams)
					local SurfaceSideRay = workspace:Raycast(FixedHeadCF.Position + Vector3.new(0, 1, 0) + (RightVector * Speed * self.Moves.LedgeGrab.DISTANCE * math.sqrt(2) * SpeedFactor), (RightVector * -Speed * self.Moves.LedgeGrab.DISTANCE * math.sqrt(2) * SpeedFactor) + (LookVector * self.Moves.LedgeGrab.DISTANCE * math.sqrt(2) * SpeedFactor) + Vector3.new(0, -self.Moves.LedgeGrab.DISTANCE, 0), self.PlayerParams)
					if (not UpperSideRay and LowerSideRay and SurfaceSideRay) and (NormalToFace(LowerSideRay) ~= NormalToFace(LowerHeadRay)) then
						
						--Calculate new ledge's Position
						local RawLedgePosition = Vector3.new(LowerSideRay.Position.X, SurfaceSideRay.Position.Y, LowerSideRay.Position.Z)
						local CharXOffset, CharYOffset = (self.Humanoid.RootPart.Size.Z / 2) + 0.5, Head.Size.Y
						local LedgePosition = RawLedgePosition - (LookVector * CharXOffset) - Vector3.new(0, CharYOffset, 0)
						
						--Update AlignPos/AlignRot
						AlignPos.Position = LedgePosition
						AlignRot.CFrame = CFrame.new(self.Humanoid.RootPart.CFrame.Position, self.Humanoid.RootPart.CFrame.Position - LowerSideRay.Normal)
						
					else --Move to side
						
						--Calculate new ledge's Position
						local RawLedgePosition = Vector3.new(LowerHeadRay.Position.X, SurfaceRay.Position.Y, LowerHeadRay.Position.Z)
						local CharXOffset, CharYOffset = (self.Humanoid.RootPart.Size.Z / 2) + 0.5, Head.Size.Y
						local LedgePosition = RawLedgePosition - (LookVector * CharXOffset) - Vector3.new(0, CharYOffset, 0) + (LookVector * SpeedFactor)

						--Update AlignPos/AlignRot
						AlignPos.Position = LedgePosition
						AlignRot.CFrame = CFrame.new(self.Humanoid.RootPart.CFrame.Position, self.Humanoid.RootPart.CFrame.Position - LowerHeadRay.Normal)
					end
				end
			end
			self.Moves.LedgeGrab.Trove:Add(RunService.PostSimulation:Connect(Run))
		end
	else --Inactive
		
		--Cleanup
		self.Moves.LedgeGrab.Trove:Clean()
		
		--Restore Movement
		if self.Moves.LedgeGrab.Active then
			self.Humanoid.RootPart.Anchored = false
			self.Humanoid.AutoRotate = true
			self.Moves.Jump.Count = 0
			
			--Cooldown
			self.Moves.LedgeGrab.OnCooldown = true
			task.delay(0.3, function()
				self.Moves.LedgeGrab.OnCooldown = false
			end)
		end
		self.Moves.LedgeGrab.Active = false
	end
end