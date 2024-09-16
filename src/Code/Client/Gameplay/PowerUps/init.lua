--!strict

--[[

Check the Bomb/Rocket powerups for examples on
how to use this module.

Quick Tutorial:
_Construct a powerup object with the player and the powerup data.
_Connect to StateChanged to know when the player interacts with it.
_You can call trigger manually for powerups with special behaviour such as the rocket.

Handful of quick gotchas (because the structure of this is weird):
_You have to set the model's PrimaryPart to the handle.
_Attributes go inside each individual powerup's model, not its container nor it's handle.
_Powerup handles are expected to be a part, not a model, touching said part is what
triggers the powerup and hides it.
_Any instances inside the powerup's model that are not inside the handle are ignored as this
is convenient for decoration. Said instances are expected to be welded to float along
the handle.

The models are old and so is their structure, so I may or may not change the previous later,
lmk if this structure is inconvenient.
--]]

----- Services -----

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

----- Variables -----

local Assets = ReplicatedStorage:WaitForChild("Assets")
local Sounds = Assets.Sounds

local Code = workspace:WaitForChild("Code")
local Shared = Code:WaitForChild("Shared")
local Resources = Shared:WaitForChild("Resources")

local Signal = require(Resources.RbxUtil.Signal)
local Trove = require(Resources.RbxUtil.Trove)

local StoredPowerups: {
	[string]: InternalObject
} = {}

----- Module -----

local PowerUps = {}
PowerUps.__index = PowerUps

--- Types ---

--Object
export type Object = { 
	StateChanged: Signal.Signal<PowerupStates, Instance>,
	Gui: BillboardGui?,
	Frame: Frame?,
	Instances: {[Instance]: {
		InitialCFrame: CFrame, State: PowerupStates, CounterFrame: Frame?
	}},
	Trigger: (self: Object, Active: boolean, Instance: Instance) -> (),
	GetState: (self: Object, PowerupModel: Instance) -> ()
}
type InternalObject = Object & {
	Player: Player,
	Character: Model,
	Humanoid: Humanoid,
	Head: BasePart,
	Data: PowerupData,
	OnCooldown: boolean,
	Trove: Trove.Trove, --Cleans itself and it's extensions only when destroyed
	ConnectionsTrove: Trove.Trove, --Extends from main trove, cleans itself on death
	PowerupsTrove: Trove.Trove --Extends from main trove, cleans itself on powerup setup
}

--Class
type Class = {
	new: (Player: Player, Data: PowerupData) -> Object
}

--Powerup Data
export type PowerupData = {
	Type: string,
	Icon: string,
	Container: Folder | Model,
	Duration: number?,
	Cooldown: number?,
	PickupSound: Sound?,
	CounterSound: Sound?,
}

export type PowerupStates = "Active" | "Completed" | "Cancelled" | "Inactive"

--- Methods ---

-- Constructor --

function PowerUps.new(Player: Player, Data: PowerupData): Object
	assert(not StoredPowerups[Data.Type], Data.Type.." PowerUp exists already.")
	local self = {} :: InternalObject
	
	self.Player = Player
	self.Trove = Trove.new()
	self.ConnectionsTrove = self.Trove:Extend()
	self.PowerupsTrove = self.Trove:Extend()
	self.StateChanged = self.Trove:Add(Signal.new(), "Destroy")
	self.Instances = {}
	
	self.Data = Data
	self.Data.Duration = self.Data.Duration or 10
	self.Data.Cooldown = self.Data.Cooldown or 1
	self.Data.PickupSound = self.Data.PickupSound or Sounds.PowerUps.PowerUp
	self.Data.CounterSound = self.Data.CounterSound or Sounds.PowerUps.Counter
	self.OnCooldown = false
	
	SetupConnections(self)
	
	StoredPowerups[Data.Type] = self
	
	return setmetatable(self, PowerUps)
end

-- Destroy --

function PowerUps.Destroy(self: InternalObject): () --You are never expected to call this, so it's untested
	if StoredPowerups[self.Data.Type] then StoredPowerups[self.Data.Type] = nil end --Remove Powerup from stored
	for Model, _ in self.Instances do --Restore model
		local Handle = assert(Model:IsA("Model") and Model.PrimaryPart)
		Handle.CFrame = self.Instances[Model].InitialCFrame
		Handle.CanCollide = true
		Handle.Transparency = 1
		for _, Part: Instance in Handle:GetDescendants() do
			if Part:IsA("BasePart") or Part:IsA("Decal") then
				local Part = Part :: BasePart --Refinement
				Part.Transparency = 0
				Part.CanCollide = true
			end
		end
	end
	if self.Trove then self.Trove:Destroy() end --Cleanup connections
	self = nil :: any --Dispose of class
end

-- GetState --

function PowerUps.GetState(self: Object, PowerupModel: Model): PowerupStates?
	if self.Instances[PowerupModel] then
		return self.Instances[PowerupModel].State
	end
	return nil
end

-- Trigger --

function PowerUps.Trigger(self: InternalObject, Active: boolean, Model: Model): ()
	if Active and (self.OnCooldown or self.Instances[Model].State == "Active") then return end
	if Active then
		self.OnCooldown = true
		
		--Attributes
		local CounterDuration = Model:GetAttribute("CounterDuration") or self.Data.Duration
		local Cooldown = Model:GetAttribute("Cooldown") or self.Data.Cooldown
		
		--Get Label
		local Frame: Frame = SetupCounter(self, Model)
		local Label: TextLabel = Frame:FindFirstChild(self.Data.Type.."Label") :: TextLabel
		
		--Set State
		self.Instances[Model].State = "Active"
		self.StateChanged:Fire("Active", Model)

		--Countdown
		local function Countdown(Count: number, Goal: number, Increment: number): ()
			if self.Instances[Model].State == "Active" then

				--Show
				Label.Text = tostring(Count)
				assert(self.Data.CounterSound, "Powerup's sound missing."):Play()

				--Count
				if Count > Goal then
					Count += Increment
					task.delay(1, function()
						Countdown(Count, Goal, Increment)
					end)
				else --Completed
					self:Trigger(false, Model)
					self.StateChanged:Fire("Completed", Model)
					self.Instances[Model].State = "Inactive"
				end
			else --Cancelled
				self.StateChanged:Fire("Cancelled", Model)
				self.Instances[Model].State = "Inactive"
			end
		end
		Countdown(CounterDuration, 0, -1)
		
		--Cooldown
		task.delay(Cooldown, function()
			self.OnCooldown = false
		end)
		
	else
		
		--Counter
		if self.Instances[Model].CounterFrame then
			assert(self.Instances[Model].CounterFrame):Destroy() --Why
			self.Instances[Model].CounterFrame = nil :: any
		end
		
		--State
		if self.Instances[Model].State == "Active" then
			self.Instances[Model].State = "Inactive"
		else --Triggers cancelled state if inactive (needed by some powerups that cancel themselves after the counter ends, which technically isn't active)
			self.StateChanged:Fire("Cancelled", Model)
			self.Instances[Model].State = "Inactive"
		end
	end
	
	--Show/Hide PowerUp
	local Handle = assert(Model.PrimaryPart, "Powerup's handle missing.")
	Handle.Transparency = Active and 1 or 0
	for _, Part: Instance in Handle:GetDescendants() do
		if Part:IsA("BasePart") or Part:IsA("Decal") then
			(Part :: BasePart).Transparency = Active and 1 or 0 --Ah yes! Please give me a warning when both types clearly have the transparency property!
		end
	end
end

--- Internal Methods ---

-- IsDescendantOfDepth --

function IsDescendantOfDepth(Inst: Instance, Ancestor: Instance, MaxDepth: number): boolean
	local Current: Instance? = Inst
	local Depth: number = 0

	while (Current and Depth < MaxDepth) do
		if Current.Parent == Ancestor then
			return true
		end
		Current = Current.Parent
		Depth += 1
	end

	return false
end

-- Setup Gui --

function SetupGui(self: InternalObject): ()

	--Gui
	if not self.Head:FindFirstChild("PowerupsGui") then
		self.Gui = Instance.new("BillboardGui"); assert(self.Gui).Parent = self.Head
		self.Gui.Size = UDim2.fromScale(4, 100); self.Gui.StudsOffset = Vector3.new(0, 52, 0) --BillboardGuis ignore the ClipDescendants settings and clip everything anyway, which I didn't know, which made me lose 2 hours of my time, so thanks engineers for that I guess
		self.Gui.Adornee = self.Head; self.Gui.Name = "PowerupsGui"; self.Gui.ClipsDescendants = false

		--Container Frame
		self.Frame = Instance.new("Frame"); assert(self.Frame).Parent = self.Gui
		self.Frame.Name = "Container"; self.Frame.BackgroundTransparency = 1
		self.Frame.Position = UDim2.fromScale(0, 1); self.Frame.Size = UDim2.fromScale(1, 0.025)
		self.Frame.AnchorPoint = Vector2.new(0, 1)

		--Layout
		local Layout: UIGridLayout = Instance.new("UIGridLayout"); Layout.Parent = self.Frame
		Layout.CellPadding = UDim2.fromScale(0, 0); Layout.CellSize = UDim2.fromScale(1, 1)
		Layout.FillDirection = Enum.FillDirection.Horizontal; Layout.StartCorner = Enum.StartCorner.BottomLeft
		Layout.HorizontalAlignment = Enum.HorizontalAlignment.Left; Layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	else
		self.Gui = self.Head:FindFirstChild("PowerupsGui") :: BillboardGui
		self.Frame = assert(self.Gui):FindFirstChild("Container") :: Frame
	end
end

-- Setup Counter --

function SetupCounter(self: InternalObject, Model: Instance): Frame
	assert(self.Frame, "Can't setup "..self.Data.Type.."'s label, it's container frame is missing.")
	assert(not self.Instances[Model].CounterFrame, "Can't setup "..self.Data.Type.."'s label again, it already exists.")

	--Counter Frame
	local CounterFrame: Frame = Instance.new("Frame"); CounterFrame.Parent = self.Frame
	CounterFrame.Name = self.Data.Type; CounterFrame.BackgroundTransparency = 1
	CounterFrame.Size = UDim2.fromScale(1, 1)

	--Counter Label
	local CounterLabel: TextLabel = Instance.new("TextLabel"); CounterLabel.Parent = CounterFrame
	CounterLabel.Name = self.Data.Type.."Label"; CounterLabel.BackgroundTransparency = 1
	CounterLabel.Size = UDim2.fromScale(0.5, 1); CounterLabel.Position = UDim2.fromScale(1, 0)
	CounterLabel.AnchorPoint = Vector2.new(1, 0); CounterLabel.Font = Enum.Font.SourceSansLight
	CounterLabel.RichText = true; CounterLabel.TextScaled = true; CounterLabel.Text = ""
	CounterLabel.TextColor3 = Color3.fromRGB(255, 255, 255)

	--Counter Icon
	local CounterIcon: ImageLabel = Instance.new("ImageLabel"); CounterIcon.Parent = CounterFrame
	CounterIcon.Name = self.Data.Type.."Icon"; CounterIcon.Image = self.Data.Icon
	CounterIcon.Size = UDim2.fromScale(0.5, 1); CounterIcon.BackgroundTransparency = 1
	
	self.Instances[Model].CounterFrame = CounterFrame
	return CounterFrame
end

-- Setup Powerups --

function SetupPowerups(self: InternalObject, Active: boolean): ()

	--Clean Connections
	self.PowerupsTrove:Clean()

	--Setup
	for _, Model: Instance in self.Data.Container:GetChildren() do
		if Model:IsA("Model") then

			local Handle: BasePart = assert(Model.PrimaryPart, "Powerup model's primary part missing!")
			local SpinSpeed: number, LerpSpeed: number = 90, 1
			self.Instances[Model] = self.Instances[Model] or {
				InitialCFrame = Handle.CFrame,
				State = "Inactive"
			}

			--Set Collision
			Handle.CanCollide = not Active
			for _, Part: Instance in Handle:GetDescendants() do
				if Part:IsA("BasePart") then
					Handle.CanCollide = not Active
				end
			end

			--Reset CFrame
			Handle.CFrame = self.Instances[Model].InitialCFrame

			--Float Effect
			if Active then
				task.delay(Random.new():NextNumber(0, 1.5), function() --Makes unique, then plays the effect
					self.PowerupsTrove:Add(RunService.PostSimulation:Connect(function(dt: number)
						local X, Y, Z = math.rad(Handle.Orientation.X), math.rad(Handle.Orientation.Y), math.rad(Handle.Orientation.Z + 1)
						Handle.CFrame = Handle.CFrame:Lerp(Handle.CFrame * CFrame.Angles(0, 0, -math.rad(SpinSpeed)), 1 - math.exp(-LerpSpeed * dt))
					end))
				end)
			end
		end
	end
end

-- Setup Connections --

function SetupConnections(self: InternalObject): ()
	
	--Touched
	local function Touched(Hit: Instance): ()
		local Model = assert(Hit.Parent)
		if IsDescendantOfDepth(Hit, self.Data.Container, 2) and self.Instances[Model].State == "Inactive" then
			self:Trigger(true, Model)
		end
	end
	
	--Died
	local function Died(): ()
		for _, Model in self.Data.Container:GetChildren() do
			if Model:IsA("Model") then
				self:Trigger(false, Model) --Cancels powerup
			end
		end
		self.ConnectionsTrove:Clean()
	end
	
	--Respawned
	local function Respawned(newCharacter: Model): ()
		self.Character = newCharacter
		self.Humanoid = self.Character:WaitForChild("Humanoid") :: Humanoid
		self.Head = self.Character:WaitForChild("Head") :: BasePart

		--Update Connections
		self.ConnectionsTrove:Add(self.Humanoid.Touched:Connect(Touched))
		self.ConnectionsTrove:Add(self.Humanoid.Died:Connect(Died))

		--Setup
		SetupGui(self)
		SetupPowerups(self, true)
	end
	self.Trove:Add(self.Player.CharacterAdded:Connect(Respawned))
	if self.Player.Character then Respawned(self.Player.Character) end	
end

return PowerUps :: Class