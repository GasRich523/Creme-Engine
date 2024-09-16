--!strict

----- Services -----

local RunService = game:GetService("RunService")

----- Variables -----

local GameplayFolder = workspace:WaitForChild("Gameplay")
local MechanicsFolder = GameplayFolder:WaitForChild("Mechanics")
local MovingPlatformsFolder = MechanicsFolder:WaitForChild("Moving Platforms")

local Code = workspace:WaitForChild("Code")
local Shared = Code:WaitForChild("Shared")
local Resources = Shared:WaitForChild("Resources")

local Trove = require(Resources.RbxUtil.Trove)
local Signal = require(Resources.RbxUtil.Signal)

local Stored: {[Model]: {
	Trove: Trove.Trove,
	Signal: Signal.Signal<...any>,
	Accumulator: number
}} = {}

----- Code -----

--- Setup ---

local function Setup(Platform: BasePart, Points: Folder): ()
	local Model: Model = assert(Platform.Parent) :: Model
	local Container: Model = assert(Model.Parent) :: Model
	
	--Create Attachment
	local Attachment = Instance.new("Attachment")
	Attachment.Name = "PlatformAttachment"
	Attachment.Parent = Platform
	
	--Create AlignPosition
	local AlignPosition = Instance.new("AlignPosition") :: AlignPosition
	AlignPosition.Mode = Enum.PositionAlignmentMode.OneAttachment
	AlignPosition.Attachment0 = Attachment
	AlignPosition.Position = Platform.Position
	AlignPosition.RigidityEnabled = true
	AlignPosition.Parent = Attachment

	--Create AlignOrientation
	local AlignOrientation = Instance.new("AlignOrientation")
	AlignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	AlignOrientation.Attachment0 = Attachment
	AlignOrientation.CFrame = Platform.CFrame
	AlignOrientation.RigidityEnabled = true
	AlignOrientation.Parent = Attachment
	
	--Hide points
	for _, Point in Points:GetChildren() do
		if Point:IsA("BasePart") then
			Point.Transparency = 1
		end
	end
end

--- Move ---

local function Move(Platform: BasePart, Goal: CFrame): ()
	local Model: Model = assert(Platform.Parent) :: Model
	local Container: Model = assert(Model.Parent) :: Model
	local Attachment = assert(Platform:FindFirstChild("PlatformAttachment"), "Attachment missing.") :: Attachment
	local AlignPosition = assert(Attachment:FindFirstChild("AlignPosition")) :: AlignPosition
	local AlignOrientation = assert(Attachment:FindFirstChild("AlignOrientation")) :: AlignOrientation

	--Attributes
	local Speed = Container:GetAttribute("Speed") or 15
	local IgnoreRotation = Container:GetAttribute("NoRotate") or false
	local UpdateRate = Container:GetAttribute("Rate") or (1 / 60) --Constraints update rate

	--Self
	local self = Stored[Model] or {
		Trove = Trove.new(),
		Signal = Signal.new(),
		Accumulator = 0,
	}
	Stored[Model] = self
	
	--Reset Accumulator to avoid residual time from affecting future movements
	self.Accumulator -= self.Accumulator

	--Move
	self.Trove:Clean()
	self.Trove:Add(RunService.PostSimulation:Connect(function(dt: number): ()
		
		--Set Network Ownership (platforms will get stuck after a while otherwise)
		Platform:SetNetworkOwner(nil)
		
		--Enforce Rate
		self.Accumulator += dt
		if self.Accumulator >= UpdateRate then
			
			--Calculate Distance/Goal
			local StepDistance: number = Speed * self.Accumulator
			local CurrentPos: Vector3 = Platform.Position
			local TargetPos: Vector3 = Goal.Position
			local Direction: Vector3 = (TargetPos - CurrentPos).Unit
			local DistanceRemaining: number = (TargetPos - CurrentPos).Magnitude
			local NewPos: Vector3 = CurrentPos + Direction * math.min(StepDistance, DistanceRemaining)

			--Update Constraints
			AlignPosition.Position = NewPos
			if not IgnoreRotation then
				local CurrentOrientation: CFrame = Platform.CFrame - Platform.Position
				local TargetOrientation: CFrame = Goal - Goal.Position
				local Alpha = math.min(StepDistance / (DistanceRemaining / 2), 1)
				local NewOrientation = CurrentOrientation:Lerp(TargetOrientation, Alpha * 2) --Rotation is usually twice as fast as the movement speed
				AlignOrientation.CFrame = CFrame.new(NewPos) * NewOrientation
			end

			--Reset the accumulator
			self.Accumulator -= UpdateRate

			--Stop movement once goal is reached
			if DistanceRemaining <= StepDistance then
				AlignPosition.Position = TargetPos --Snap to final position
				if not IgnoreRotation then
					AlignOrientation.CFrame = Goal --Ensure final orientation is set
				end
				self.Trove:Clean() --Stop further updates
				assert(self.Signal :: any):Fire() --Signal that movement is complete
			end
		end
	end))

	--Wait for the movement to complete
	assert(self.Signal :: any):Wait()
end

--- Handle ---

local function Handle(Container: Model): ()
	local Points: Folder = assert(Container:FindFirstChild("Points"), "Platform has no points.") :: Folder
	local Model: Model = assert(Container:FindFirstChild("Platform"), "Platform has no model.") :: Model
	local Platform: BasePart = assert(Model.PrimaryPart, "Platform model has no primery part.")
	
	--Attributes
	local Pause = Container:GetAttribute("Pause") or 1.5
	local PausePerPoint = Container:GetAttribute("PausePerPoint") or false
	local IgnoreReverse = Container:GetAttribute("NoReverse") or false
	local InvertDirection = Container:GetAttribute("InvertDirection") or false
	
	--Values
	local Direction: "Forward" | "Backwards" = if not InvertDirection then "Forward" else "Backwards"
	local CurrentPoint: number = 1
	
	--Setup
	Setup(Platform, Points)
	
	--Handle
	while true do
		
		--Calculate Goal
		if Direction == "Forward" then
			if (CurrentPoint + 1) <= #Points:GetChildren() then --Hasn't reached limit
				CurrentPoint += 1
			else
				if not IgnoreReverse then --Counting down, reached limit
					Direction = "Backwards"
					CurrentPoint -= 1
				else --Restart
					CurrentPoint = 1
				end
			end
		elseif Direction == "Backwards" then --Counting down
			if (CurrentPoint - 1) >= 1 then --Hasn't reached limit
				CurrentPoint -= 1
			else
				if not IgnoreReverse then --Counting up, reached limit
					Direction = "Forward"
					CurrentPoint += 1
				else --Restart
					CurrentPoint = #Points:GetChildren()
				end
			end
		end
		
		--Move to Goal (Yields)
		Move(Platform, assert(Points:FindFirstChild(tostring(CurrentPoint)) :: BasePart).CFrame)
		
		--Delay
		if Pause > 0 and (not PausePerPoint or (CurrentPoint == #Points:GetChildren() or CurrentPoint == 1)) then
			task.wait(Pause)
		end
	end
end

--Get Platforms
for _, Platform: Model in MovingPlatformsFolder:GetChildren() do
	task.spawn(Handle, Platform)
end