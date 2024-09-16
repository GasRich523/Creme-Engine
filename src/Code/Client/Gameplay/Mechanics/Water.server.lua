--!strict

----- Services -----

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

----- Variables -----

local Player = Players.LocalPlayer
local Character: Model = Player.Character or Player.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid") :: Humanoid & {Animator: Animator}
local RootPart = Character:WaitForChild("HumanoidRootPart") :: BasePart
local Camera = workspace.Camera

local Code = workspace:WaitForChild("Code")
local Client = Code:WaitForChild("Client")
local Shared = Code:WaitForChild("Shared")
local Goodies = Shared:WaitForChild("Goodies")
local Resources = Shared:WaitForChild("Resources")

local Assets = ReplicatedStorage:WaitForChild("Assets")
local Effects = Assets:WaitForChild("Effects")
local Animations = Assets:WaitForChild("Animations")
local Sounds = Assets:WaitForChild("Sounds")

local MusicGroup = workspace:WaitForChild("Volume")
local UnderwaterBlur = Effects.Water.Blur; UnderwaterBlur.Parent = Lighting
local UnderwaterColor = Effects.Water.Color; UnderwaterColor.Parent = Lighting
local UnderwaterEqualizer = Effects.Water.Equalizer; UnderwaterEqualizer.Parent = MusicGroup
local UnderwaterSound = Sounds.Water.Underwater
local RippleEffect = Effects.Water.Ripple
local SplashEffect = Effects.Water.Splash
local DrownAnim = Animations.Water.Drown
local BubbleEffect = Effects.Water.Bubbles
local DrownSound = Sounds.Water.Drown

local Gameplay = workspace:WaitForChild("Gameplay")
local Mechanics = Gameplay:WaitForChild("Mechanics")
local Misc = workspace:WaitForChild("Misc")
local WaterFolder = Mechanics:WaitForChild("Water")
local FloatiesFolder = Misc:WaitForChild("Floaties")

local QuickTween = require(Goodies.Utils.QuickTween)
local Trove = require(Resources.RbxUtil.Trove)
local Moveset = require(Client.Gameplay.Moveset)

local JumpHeight = Humanoid.JumpHeight
local Swimming, Drowned = false, false
local OnCooldown, Cooldown, RippleCounter, RippleInterval = false, 0.25, 0, 0.3
local Force: Attachment, CurrentWaterPart: BasePart? = nil, nil
local PlayDrownAnim: AnimationTrack, BubbleClone = nil, nil

local WaterParams = OverlapParams.new()
WaterParams.FilterType = Enum.RaycastFilterType.Include
WaterParams.FilterDescendantsInstances = {Character, FloatiesFolder}
local FloatieParams, FloatieRayParams = OverlapParams.new(), RaycastParams.new()
FloatieParams.FilterType, FloatieRayParams.FilterType = Enum.RaycastFilterType.Include, Enum.RaycastFilterType.Include
FloatieParams.FilterDescendantsInstances, FloatieRayParams.FilterDescendantsInstances = {WaterFolder}, {WaterFolder}

local Stored: {[BasePart]: {
	Trove: Trove.Trove,
	RippleInterval: number,
	RippleCounter: number
}} = {}

----- Code -----

--- Ripple ---

local function SpawnRipple(Subject: BasePart): ()
	local Moving = (Vector3.new(math.round(Subject.AssemblyLinearVelocity.X), 0, math.round(Subject.AssemblyLinearVelocity.Z))).Magnitude ~= 0 and true or false
	
	--Converts position in 3D space to SurfaceGui position (WON'T WORK WHEN ROTATED, OFFSET A FRAME TO WORK AROUND THAT)
	local function PosToUdim2(SurfacePart, SurfaceGui, Image)
		local RelativePos = (Subject.Position + Subject.CFrame.LookVector * 1 - SurfacePart.Position) * SurfaceGui.PixelsPerStud
		return UDim2.new(Image.AnchorPoint.X, RelativePos.X, Image.AnchorPoint.Y, RelativePos.Z)
	end

	--Spawn Ripple
	local Origin: Vector3, Direction: Vector3 = Subject.CFrame.Position + Vector3.new(0, Subject.Size.Y * 1.5, 0), Vector3.new(0, -2, 0) * (Subject.Size.Y * 1.5)
	local OnSurface = workspace:Raycast(Origin, Direction, FloatieRayParams)
	if OnSurface then
		
		--Clone
		local RippleClone = RippleEffect:Clone(); RippleClone.Parent = OnSurface.Instance
		local Frame = RippleClone:FindFirstChild("Frame")
		local Image = Frame and Frame:FindFirstChild("ImageLabel")

		--Animate
		if Image then
			local RippleTime = 1.5
			local AvrgSizeX = (Image.Size.X.Offset/3) * (Subject.Size.X) + 50
			local AvrgSizeY = (Image.Size.Y.Offset/3) * (Subject.Size.Y) + 50
			Image.Position = PosToUdim2(OnSurface.Instance, RippleClone, Image)
			Frame.Rotation = OnSurface.Instance.Orientation.Y + 90
			Image.Size = UDim2.fromOffset(AvrgSizeX, AvrgSizeY)
			
			--Tween
			local RippleTween = QuickTween(Image, TweenInfo.new(if Moving then RippleTime/2 else RippleTime, Enum.EasingStyle.Quad), {ImageTransparency = 1, Size = UDim2.fromOffset(Image.Size.X.Offset * 2, Image.Size.Y.Offset * 2)})
			RippleTween.Completed:Connect(function()
				if RippleClone then RippleClone:Destroy() end
				if RippleTween then RippleTween:Destroy() end
			end)
			RippleTween:Play()
		end
		
		--Trigger splash particle
		if Moving then
			local SplashClone = SplashEffect:Clone()
			SplashClone.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1.5),
				NumberSequenceKeypoint.new(1, 1.5)
			})
			SplashClone:Emit(5)
			SplashClone.Parent = Subject

			--Clean
			task.delay(1, function()
				if SplashClone then SplashClone:Destroy() end
			end)
		end
	end
end

--- Float ---

local function Float(Active: boolean, Floatie: BasePart): ()
	local self = {}
	if Active then
		
		--Setup Trove
		self.Trove = Trove.new()
		self.Trove:AttachToInstance(Floatie)
		self.Trove:Add(function()
			if Stored[Floatie] then Stored[Floatie] = nil end
		end)
		
		local Offset, OffsetTime, OffsetRange = 0, 1, Vector2.new(-0.25, 0.25)
		self.RippleCounter, self.RippleInterval = 0, 0.5
		
		--Create Attachment
		local Attachment = self.Trove:Add(Floatie:FindFirstChild("PlatformAttachment") :: Attachment or Instance.new("Attachment"))
		Attachment.Name = "PlatformAttachment"
		Attachment.Parent = Floatie

		--Create AlignPosition
		local AlignPosition = self.Trove:Add(Floatie:FindFirstChild("AlignPosition") or Instance.new("AlignPosition")) :: AlignPosition
		AlignPosition.Mode = Enum.PositionAlignmentMode.OneAttachment
		AlignPosition.Attachment0 = Attachment
		AlignPosition.ForceLimitMode = Enum.ForceLimitMode.PerAxis
		AlignPosition.MaxVelocity = math.huge
		AlignPosition.Responsiveness = 200
		AlignPosition.Enabled = false
		AlignPosition.Parent = Attachment
		
		--Run
		self.Trove:Add(RunService.PostSimulation:Connect(function(dt: number)
			local PartsInPart = workspace:GetPartsInPart(Floatie, FloatieParams)
			if #PartsInPart > 0 then

				--Update Offset
				Offset = (Offset + dt) % OffsetTime
				local Phase = (Offset / OffsetTime) * (2 * math.pi)
				local OscillationOffset = OffsetRange.X + (OffsetRange.Y - OffsetRange.X) * (0.5 * (math.sin(Phase) + 1))

				--Calculate Bouyancy
				local Result = PartsInPart[1]
				local FloatieHeight = Floatie.Position.Y - (Floatie.Size.Y / 2)
				local ResultHeight = Result.Position.Y + (Result.Size.Y / 2)

				--Update AlignPosition properties
				AlignPosition.MaxAxesForce = Vector3.new(0, workspace.Gravity * Floatie:GetMass() * 2, 0)
				AlignPosition.Position = Vector3.new(Floatie.Position.X, ResultHeight + OscillationOffset, Floatie.Position.Z)
				
				--Spawn Ripple
				local Moving = (Vector3.new(math.round(Floatie.AssemblyLinearVelocity.X), 0, math.round(Floatie.AssemblyLinearVelocity.Z))).Magnitude ~= 0 and true or false
				if ((os.clock() - self.RippleCounter) > (Moving and self.RippleInterval / 2 or self.RippleInterval)) or self.RippleCounter == 0 then
					self.RippleCounter = os.clock()
					SpawnRipple(Floatie)
				end
			end
			AlignPosition.Enabled = #PartsInPart > 0
		end))
	else
		self.Trove:Destroy()
		self = nil :: any
	end
	Stored[Floatie] = self
end

--- Drown ---

local function Drown(Hit: BasePart): () --Messiest part of the whole thing
	if not Drowned then
		Drowned = true
		
		--Disable Movement
		RootPart.Anchored = true
		--Movement:ToggleMovement(false)
		Camera.CameraType = Enum.CameraType.Scriptable

		--Snap to Surface
		local BHS, BTS, BPS = Humanoid:FindFirstChild("BodyHeightScale") :: NumberValue, Humanoid:FindFirstChild("BodyTypeScale") :: NumberValue, Humanoid:FindFirstChild("BodyProportionScale") :: NumberValue
		local Height = BHS and BTS and BPS and BHS.Value * (4 + BTS.Value * (math.pi / 2 - 0.6 * BHS.Value)) + 1 or 1
		RootPart.CFrame = (RootPart.CFrame + Vector3.new(0, - RootPart.Position.Y + Hit.Position.Y + (Hit.Size.Y * 0.5) + ((Height/2) - 1), 0)) * CFrame.Angles(math.rad(90), 0, 0)

		--Effect
		local Effect = SplashEffect:Clone(); Effect.Parent = RootPart
		Effect:Emit(5)

		--Sound
		DrownSound:Play()

		--Animate
		if PlayDrownAnim then PlayDrownAnim:Stop() end
		PlayDrownAnim = Humanoid.Animator:LoadAnimation(DrownAnim)
		PlayDrownAnim.Ended:Once(function()

			--Re-enable movement
			--Movement:ToggleMovement(true)
			RootPart.Anchored = false

			--Kill Player
			Humanoid:TakeDamage(100)

			--Restore Cam
			Player.CharacterAdded:Once(function(newChar: Model): ()
				task.spawn(function()
					Camera.CameraType = Enum.CameraType.Custom
					Camera.CameraSubject = newChar:WaitForChild("Humanoid")
				end)
			end)
		end)
		PlayDrownAnim:Play()

		--Transparency
		for _, CharParts in Character:GetDescendants() do
			if CharParts:IsA("BasePart") or CharParts:IsA("Decal") and CharParts.Transparency == 0 then
				QuickTween(CharParts, TweenInfo.new(2.63, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {Transparency = 1})
			end
		end
	end
end

--- Swim ---

local function Swim(Active: boolean): ()
	if Active and not OnCooldown then
		Swimming = true
		
		--Set State
		if Humanoid:GetState() ~= Enum.HumanoidStateType.Swimming then
			Humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
			Humanoid:ChangeState(Enum.HumanoidStateType.Swimming)
		end
		
		--Apply Force
		if Force then Force:Destroy() end --Att
		Force = Instance.new("Attachment")
		Force.Name = "ForceAttachment"
		local F = Instance.new("LinearVelocity") --Vel
		F.Attachment0 = Force; F.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
		F.RelativeTo = Enum.ActuatorRelativeTo.World; F.MaxForce = 10000
		F.VectorVelocity = Vector3.new(0, 1, 0)
		F.Parent = Force; Force.Parent = RootPart --Parent
		
		--Apply Particle
		BubbleClone = BubbleClone or BubbleEffect:Clone(); BubbleClone.Parent = RootPart
		BubbleClone.Rate = 1.5; BubbleClone.Enabled = false
	else
		
		--End State
		if Humanoid.Health > 0 then
			Humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
			Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		end
		
		--Cleanup
		if Force then Force:Destroy() end
		if BubbleClone then BubbleClone:Destroy(); BubbleClone = nil end
		CurrentWaterPart = nil
		Swimming = false
	end
end

--- Run ---

local function Run(dt: number): ()
	
	--Underwater Camera
	local CameraUnderwater = workspace:GetPartBoundsInBox(Camera.CFrame, Vector3.zero, FloatieParams)
	if #CameraUnderwater > 0 then
		UnderwaterBlur.Enabled = true
		UnderwaterColor.Enabled = true
		UnderwaterEqualizer.Enabled = true
		if not UnderwaterSound.IsPlaying then
			UnderwaterSound:Resume()
		end
	else
		UnderwaterBlur.Enabled = false
		UnderwaterColor.Enabled = false
		UnderwaterEqualizer.Enabled = false
		UnderwaterSound:Pause()
	end
	
	--Water
	local LocalIgnoreForce: boolean = false
	local PlayerFound: boolean = false
	for _, WaterPart in WaterFolder:GetChildren() do
		local IgnoreForce = WaterPart:GetAttribute("IgnoreForce") or false
		local Drowns = WaterPart:GetAttribute("Drowns") or false
		
		local PartsOnWater = workspace:GetPartBoundsInBox(WaterPart.CFrame, WaterPart.Size, WaterParams) --Might be better to have no params at all if there's too many floaties
		if #PartsOnWater > 0 then
			for _, PartOnWater in PartsOnWater do
				
				--Swimming
				if PartOnWater == RootPart and Humanoid.Health > 0 then
					PlayerFound = not Drowns and true
					LocalIgnoreForce = IgnoreForce
					if (not Swimming or CurrentWaterPart and CurrentWaterPart ~= WaterPart) and not Drowns then --Swim
						CurrentWaterPart = WaterPart
						Swim(true)
					elseif Drowns then --Drown
						Drown(WaterPart)
					end
				end
				
				--Floating
				if PartOnWater:IsDescendantOf(FloatiesFolder) then
					if not PartOnWater.Anchored and not Stored[PartOnWater] then
						Float(true, PartOnWater)
					end
				end
			end
		end
		
		--Floating Removal
		if #Stored > 0 then
			for StoredFloatie, _ in Stored do
				if not PartsOnWater[StoredFloatie] then
					Float(false, StoredFloatie)
				end
			end
		end
	end
	
	--Handle Swimming
	if Swimming and Humanoid.Health > 0 then
		
		--Swimming Removal
		if not PlayerFound then
			Swim(false)
			return
		end
		
		--Spawn Ripple
		local Moving = (Vector3.new(math.round(RootPart.AssemblyLinearVelocity.X), 0, math.round(RootPart.AssemblyLinearVelocity.Z))).Magnitude ~= 0 and true or false
		if ((os.clock() - RippleCounter) > (Moving and RippleInterval / 2 or RippleInterval)) or RippleCounter == 0 then
			RippleCounter = os.clock()
			SpawnRipple(RootPart)
		end
		
		--Prevent Jumping (and handle the Bubble Particle)
		local BHS, BTS, BPS = Humanoid:FindFirstChild("BodyHeightScale") :: NumberValue, Humanoid:FindFirstChild("BodyTypeScale") :: NumberValue, Humanoid:FindFirstChild("BodyProportionScale") :: NumberValue
		local Height = BHS and BTS and BPS and BHS.Value * (4 + BTS.Value * (math.pi / 2 - 0.6 * BHS.Value)) + 1 or 1
		if CurrentWaterPart then
			local AtTop = RootPart.Position.Y + Height >= (CurrentWaterPart.Position.Y + (CurrentWaterPart.Size.Y * 0.5))
			if BubbleClone then
				BubbleClone.Enabled = not AtTop
				BubbleClone.Rate = Moving and 4 or 1.5
			end
			Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, AtTop)
		end
		
		--Upwards/Downwards Swimming
		assert(Humanoid.RootPart)
		for _, Obj: InputObject in UserInputService:GetKeysPressed() do
			
			--[[
			PLACEHOLDER:
			_Correct way to do this is to add a way to retrieve the player's moveset from the moveset
			module (example: local Moveset = Moveset:FindMoveset(Player)).
			_Said method would return the controls, which would allow the player to rebind their
			controls in a menu as they please, and the water would adapt to that.
			--]]
			
			--Upwards
			if Obj.KeyCode == Enum.KeyCode.Space or Obj.KeyCode == Enum.KeyCode.ButtonA then
				RootPart.AssemblyLinearVelocity = Vector3.new(RootPart.AssemblyLinearVelocity.X, Humanoid.WalkSpeed, RootPart.AssemblyLinearVelocity.Z)
				RootPart.AssemblyAngularVelocity = (RootPart.CFrame.UpVector:Cross(Vector3.new(0, 1, 0))).Unit * math.min(math.acos(RootPart.CFrame.UpVector:Dot(Vector3.new(0, 1, 0))) * 15, Humanoid.WalkSpeed)
			--Downwards	
			elseif Obj.KeyCode == Enum.KeyCode.LeftShift or Obj.KeyCode == Enum.KeyCode.ButtonR2 then
				RootPart.AssemblyLinearVelocity = Vector3.new(RootPart.AssemblyLinearVelocity.X, -Humanoid.WalkSpeed, RootPart.AssemblyLinearVelocity.Z)
				RootPart.AssemblyAngularVelocity = (RootPart.CFrame.UpVector:Cross(Vector3.new(0, -1, 0))).Unit * math.min(math.acos(RootPart.CFrame.UpVector:Dot(Vector3.new(0, -1, 0))) * 20, Humanoid.WalkSpeed)
			end
		end
		
		--Refresh State (Ragdolling while swimming for example would set the state off, this prevents that)
		Humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
		Humanoid:ChangeState(Enum.HumanoidStateType.Swimming)
		
		--Update Force
		if Force and CurrentWaterPart then
			local F = Force:FindFirstChild("LinearVelocity") :: LinearVelocity
			if F and Humanoid:GetState() ~= Enum.HumanoidStateType.Ragdoll then
				if not LocalIgnoreForce then
					F.VectorVelocity = (Humanoid.MoveDirection * Vector3.new(1, 0, 1)) * Humanoid.WalkSpeed + Vector3.new(0, ((CurrentWaterPart.Position.Y + (CurrentWaterPart.Size.Y/2)) - RootPart.Position.Y - 0.5), 0)
				else
					local IntendedPosition = RootPart.Position + ((Humanoid.MoveDirection * Humanoid.WalkSpeed) * dt)
					local WaterTop = CurrentWaterPart.Position.Y + (CurrentWaterPart.Size.Y * 0.5)
					local WaterBottom = CurrentWaterPart.Position.Y - (CurrentWaterPart.Size.Y * 0.5) + (Height * 0.5)

					--Apply force
					F.VectorVelocity = Humanoid.MoveDirection * Humanoid.WalkSpeed

					--Clamp
					if IntendedPosition.Y > WaterTop then
						F.VectorVelocity = Vector3.new(F.VectorVelocity.X, 0, F.VectorVelocity.Z)
					elseif IntendedPosition.Y < WaterBottom then
						F.VectorVelocity = Vector3.new(F.VectorVelocity.X, (WaterBottom - RootPart.Position.Y) / dt, F.VectorVelocity.Z)
					end
				end		
			elseif F then
				F.VectorVelocity = Vector3.zero
			end
		end
	end
end
RunService.PostSimulation:Connect(Run)

--- Jumped ---

local function Jumped()
	if Swimming and not OnCooldown and Humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping) then
		Swim(false)
		
		--Cooldown
		OnCooldown = true
		task.delay(Cooldown, function()
			Humanoid.JumpHeight = JumpHeight
			OnCooldown = false
		end)

		--Jump
		Humanoid.JumpHeight *= 1.5
		Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end
end
UserInputService.JumpRequest:Connect(Jumped)

--- Died ---

local function Died(): ()
	Swim(false)
end

--- Respawned ---

local function Respawned(newChar: Model): ()
	Character = newChar
	Humanoid = Character:WaitForChild("Humanoid") :: Humanoid & {Animator: Animator}
	RootPart = Character:WaitForChild("HumanoidRootPart") :: BasePart
	
	JumpHeight = Humanoid.JumpHeight
	Swimming, Drowned = false, false
	WaterParams.FilterDescendantsInstances = {Character, FloatiesFolder}
	
	--Signals
	Humanoid.Died:Connect(Died)
end
Player.CharacterAdded:Connect(Respawned)