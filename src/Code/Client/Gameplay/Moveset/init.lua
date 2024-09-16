--!strict

--[[
Game's moveset.

Much like the database, this works with black magic, so to add moves/effects just add them to the
types (Moves/Effects) for autocompletion, add the module to it's respective folder, edit the
state machine module to handle your move and... that's it, you're good to go.

For games with move variants like detriment for example I suggest you drop all the variants inside
the move itself (example: Dive.Dive, Dive.Dash, Dive.Charge), and require the move the player is
currently wearing on the spot (doesn't need to be in the fuction itself, you can have an event
that detects the changes and updates the variable the move's function uses), that way the state
machine remains static and you don't have to do anything crazy, it's easy and highly scalable.

Example:

```

--This is untested, so it might be slightly innacurate

local CurrentDive = require(script[Database.Moves.Dive])
Database.DataChanged:Connect(function(Plr: Player, Key: any, Value: any, OldValue: any, Table: {[any]: any})
	if Player == Plr and Table == Database.Moves and Key == "Dive" then
		CurrentDive = require(script[Value])
	end
end)

return function(self: Moveset.InternalObject, Active: boolean, ...): ()
	self.Moves.Dive.Trove:Clean()
	CurrentDive:Toggle(self, Active, ...)
end

```

--]]

----- Services -----

local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

----- Variables -----

local Code = workspace:WaitForChild("Code")
local Shared = Code:WaitForChild("Shared")
local Goodies = Shared:WaitForChild("Goodies")
local Resources = Shared:WaitForChild("Resources")

local TableChanged = require(Goodies.Utils.TableChanged.Client)
local Signal = require(Resources.RbxUtil.Signal)
local Trove = require(Resources.RbxUtil.Trove)
local TableUtil = require(Resources.RbxUtil.TableUtil)

----- Module -----

local Moveset = {}
Moveset.__index = Moveset

--- Types ---

--Object
export type Object = { 
	Moves: Moves,
	Effects: Effects,
	Controls: Controls,
	StateChanged: Signal.Signal<string, any, any, {[any]: any}>, --State, New, Old
	ToggleMovement: (self: Object, Active: boolean) -> (),
	ToggleReset: (self: Object, Active: boolean) -> (),
	Destroy: (self: Object) -> ()
}
export type InternalObject = Object & {
	Player: Player,
	Character: Model?,
	Humanoid: (Humanoid & {Animator: Animator})?,
	PlayerControls: any,
	StateMachine: (self: InternalObject, Active: boolean) -> (),
	PlayerParams: RaycastParams,
	Trove: Trove.Trove,
	StateMachineTrove: Trove.Trove,
	JumpOnCooldown: boolean,
	JumpHoldState: boolean,
	JumpHoldPress: number,
	SetupConnections: (self: InternalObject) -> (),
	SetupStateMachine: (self: InternalObject) -> ()
}

--Class
type Class = {
	new: (Player: Player) -> Object
}

-- Base Types --

type BaseContainer = {Enabled: boolean, Active: boolean}
type BaseMove = BaseContainer & {Toggle: (self: InternalObject, Active: boolean, ...any) -> (), Trove: Trove.Trove}
type BaseEffect = BaseMove
type BaseControl = {Desktop: Enum.KeyCode, Console: Enum.KeyCode}
type FilterType = "Blacklist" | "Whitelist"

-- Moveset Types --

export type Moves = BaseContainer & {
	Jump: BaseMove & {MULTIPLIER: number, MAXJUMPS: number, Count: number},
	Glide: BaseMove & {SPEED: number},
	Dive: BaseMove & {SPEED: number, HEIGHT: number, OnCooldown: boolean},
	LongJump: BaseMove & {SPEED: number, HEIGHT: number, OnCooldown: boolean},
	Backflip: BaseMove & {HEIGHT: number, DURATION: number},
	Crouch: BaseMove,
	Roll: BaseMove & {SPEED: number, SHORT_SPEED: number, DURATION: number, OnCooldown: boolean},
	Stun: BaseMove & {SPEED: number, HEIGHT: number, DURATION: number, OnCooldown: boolean},
	WallSlide: BaseMove & {SPEED: number, DISTANCE: number, FILTER_NAME: string, FILTER_TYPE: FilterType},
	LedgeGrab: BaseMove & {DISTANCE: number, FILTER_NAME: string, FILTER_TYPE: FilterType, OnCooldown: boolean},
	
	WalkSpeed: number,
	CrouchSpeed: number,
	JumpHeight: number
}

export type Effects = BaseContainer & {
	LandSpot: BaseEffect,
	Outline: BaseEffect,
	Tilt: BaseEffect,
	Damaged: BaseEffect,
	Died: BaseEffect,
	Footsteps: BaseEffect
}

export type Controls = {
	Move: BaseControl,
	Interact: BaseControl,
}

--- Methods ---

-- Constructor --

function Moveset.new(Player: Player): Object
	assert(Player, "Player missing.")
	local self = {} :: InternalObject
	
	self.PlayerParams = RaycastParams.new()
	self.PlayerParams.FilterType = Enum.RaycastFilterType.Exclude
	self.PlayerParams.IgnoreWater = true
	
	self.Player = Player
	self.Trove = Trove.new()
	self.StateMachineTrove = self.Trove:Add(Trove.new())
	self.StateChanged = self.Trove:Add(Signal.new())
	self.StateMachine = require(script.StateMachine) :: any
	Moveset.SetupConnections(self)
	
	return setmetatable(self, Moveset)
end

-- Destroy --

function Moveset.Destroy(self: InternalObject): ()
	self.Trove:Destroy()
	setmetatable(self, nil)
	table.clear(self)
	table.freeze(self)
end

-- Toggle Movement --

function Moveset.ToggleMovement(self: InternalObject, Active: boolean): ()
	assert(self.Character and self.Humanoid and self.Humanoid.RootPart and self.PlayerControls)
	if not Active then
		self.PlayerControls:Disable()
		self.Humanoid:MoveTo(self.Humanoid.RootPart.Position)
	else
		self.PlayerControls:Enable()
	end
	self.Moves.Enabled = Active
end

-- Toggle Reset --

function Moveset.ToggleReset(self: InternalObject, Active: boolean): ()
	repeat RunService.PreSimulation:Wait() until pcall(function()
		StarterGui:SetCore("ResetButtonCallback", Active)
	end)
end

--- Internal Methods ---

--Sets up Connections
function Moveset.SetupConnections(self: InternalObject): ()
	local BaseContainer: BaseContainer = {Enabled = true, Active = false}
	local BaseMove: BaseMove = TableUtil.Reconcile({Toggle = function(...: any): () end, Trove = Trove.new()}, BaseContainer)
	local BaseEffect: BaseEffect = BaseMove
	
	--Init Toggle
	local function InitToggle<T>(Component: T, Container: Folder): (Moves | Effects)
		assert(typeof(Component) == "table")
		for k, v in Component do
			if typeof(v) == "table" then
				local MoveFound = Container:FindFirstChild(k)
				local MoveFunc = MoveFound and require(MoveFound) :: any
				
				function v.Toggle(self: InternalObject, Active: boolean, ...: any): ()
					local Busy = not self.Humanoid or self.Humanoid:GetState() == Enum.HumanoidStateType.Ragdoll or self.Humanoid:GetState() == Enum.HumanoidStateType.Dead
					local CanToggle = ((Active and Component.Enabled and v.Enabled and not Busy) or not Active)
					if MoveFunc and CanToggle then --Moves can only be called if both the move and the moveset are active, or if the call is to cancel the move
						MoveFunc(self, Active, ...)
					end
				end
			end
		end
		return Component
	end
	
	--Moves
	self.Moves = TableChanged:Connect(InitToggle(TableUtil.Reconcile({
		Jump = TableUtil.Reconcile({MULTIPLIER = 1.1, MAXJUMPS = 2, Count = 0}, BaseMove),
		Glide = TableUtil.Reconcile({SPEED = -15}, BaseMove),
		Dive = TableUtil.Reconcile({SPEED = 80, HEIGHT = 25, OnCooldown = false}, BaseMove),
		LongJump = TableUtil.Reconcile({SPEED = 100, HEIGHT = 55, OnCooldown = false}, BaseMove),
		Backflip = TableUtil.Reconcile({HEIGHT = 22, DURATION = 0.3}, BaseMove),
		Crouch = TableUtil.Reconcile({}, BaseMove),
		Roll = TableUtil.Reconcile({SPEED = 65, SHORT_SPEED = 55, DURATION = 0.5, OnCooldown = false}, BaseMove),
		Stun = TableUtil.Reconcile({SPEED = 30, HEIGHT = 5, DURATION = 1, OnCooldown = false}, BaseMove),
		WallSlide = TableUtil.Reconcile({SPEED = 10, DISTANCE = 2.5, FILTER_NAME = "NoSlide", FILTER_TYPE = "Blacklist"}, BaseMove),
		LedgeGrab = TableUtil.Reconcile({DISTANCE = 4, FILTER_NAME = "NoGrab", FILTER_TYPE = "Blacklist"}, BaseMove),
		
		WalkSpeed = 25,
		CrouchSpeed = 15,
		JumpHeight = 7.2
	}, BaseContainer), script.Moves) :: Moves, self.StateChanged, 0.5)
	
	--Effects
	self.Effects = TableChanged:Connect(InitToggle(TableUtil.Reconcile({
		LandSpot = TableUtil.Reconcile({}, BaseEffect), --Make sure you don't set this to BaseEffect as that'll make all the values share the same reference, which you don't want
		Outline = TableUtil.Reconcile({}, BaseEffect),
		Tilt = TableUtil.Reconcile({}, BaseEffect),
		Damaged = TableUtil.Reconcile({}, BaseEffect),
		Died = TableUtil.Reconcile({}, BaseEffect),
		Footsteps = TableUtil.Reconcile({}, BaseEffect)
	}, BaseContainer), script.Effects) :: Effects, self.StateChanged, 0.5)

	--Controls
	self.Controls = TableChanged:Connect({
		Move = {Desktop = Enum.KeyCode.LeftShift, Console = Enum.KeyCode.ButtonB},
		Interact = {Desktop = Enum.KeyCode.E, Console = Enum.KeyCode.ButtonR1}
	} :: Controls, self.StateChanged, 0.5)
	
	--Cleanup
	self.Trove:Add(function()
		TableChanged:Disconnect(self.Moves)
		TableChanged:Disconnect(self.Effects)
		TableChanged:Disconnect(self.Controls)	
	end)
	
	--Died
	local function Died(): ()
		for _, Component in {self.Moves, self.Effects} :: {[number]: Moves | Effects} do --Cancel Moves/Effects
			for _, Move in pairs(Component) do
				if typeof(Move) == "table" and Move.Toggle then
					Move.Toggle(self, false)
				end
			end
		end
		self.StateMachine(self, false)
	end

	--Character Added
	local function CharacterAdded(newCharacter: Model): ()
		self.Character = newCharacter
		self.Humanoid = newCharacter:FindFirstChild("Humanoid") :: (Humanoid & {Animator: Animator})		
		self.PlayerControls = (require(self.Player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")) :: any):GetControls()
		assert(self.Humanoid, self.Character)
		
		self.PlayerParams.FilterDescendantsInstances = {self.Character}
		self.Humanoid.JumpHeight = self.Moves.JumpHeight
		self.Humanoid.WalkSpeed = self.Moves.WalkSpeed
		
		self.Humanoid.Died:Once(Died)
		for _, Effect: BaseEffect in pairs(self.Effects) do
			if typeof(Effect) == "table" and Effect.Toggle then
				Effect.Toggle(self, true)
			end
		end
		self.StateMachine(self, true)
	end
	self.Trove:Add(self.Player.CharacterAdded:Connect(CharacterAdded))
	if self.Player.Character then CharacterAdded(self.Player.Character) end
end

return Moveset :: Class