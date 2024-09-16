--!strict

----- Services -----

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

----- Variables -----

local Code = workspace:WaitForChild("Code")
local Shared = Code:WaitForChild("Shared")
local Resources = Shared:WaitForChild("Resources")

local Signal = require(Resources.RbxUtil.Signal)
local Trove = require(Resources.RbxUtil.Trove)

local ConstraintLimits = {
	["LeftAnkle"] = {Limits = true, Twist = true, UpperAngle = 30, LowerAngle = 0, TwistLowerAngle = -45, TwistUpperAngle = 30},
	["RightAnkle"] = {Limits = true, Twist = true, UpperAngle = 30, LowerAngle = 0, TwistLowerAngle = -45, TwistUpperAngle = 30},
	["LeftElbow"] = {Limits = true, Twist = false, UpperAngle = 135, LowerAngle = 0, TwistLowerAngle = 0, TwistUpperAngle = 0},
	["RightElbow"] = {Limits = true, Twist = false, UpperAngle = 135, LowerAngle = 0, TwistLowerAngle = 0, TwistUpperAngle = 0},
	["LeftHip"] = {Limits = true, Twist = true, UpperAngle = 50, LowerAngle = 0, TwistLowerAngle = 100, TwistUpperAngle = -45},
	["RightHip"] = {Limits = true, Twist = true, UpperAngle = 50, LowerAngle = 0, TwistLowerAngle = 100, TwistUpperAngle = -45},
	["LeftKnee"] = {Limits = true, Twist = false, UpperAngle = 0, LowerAngle = -140, TwistLowerAngle = 0, TwistUpperAngle = 0}, 
	["RightKnee"] = {Limits = true, Twist = false, UpperAngle = 0, LowerAngle = -140, TwistLowerAngle = 0, TwistUpperAngle = 0},
	["Neck"] = {Limits = true, Twist = true, UpperAngle = 60, LowerAngle = 0, TwistLowerAngle = -75, TwistUpperAngle = 60},
	["LeftShoulder"] = {Limits = true, Twist = true, UpperAngle = 45, LowerAngle = 0, TwistLowerAngle = -90, TwistUpperAngle = 150}, 
	["RightShoulder"] = {Limits = true, Twist = true, UpperAngle = 45, LowerAngle = 0, TwistLowerAngle = -90, TwistUpperAngle = 150},
	["Waist"] = {Limits = true, Twist = true, UpperAngle = 30, LowerAngle = 0, TwistLowerAngle = -55, TwistUpperAngle = 25},
	["LeftWrist"] = {Limits = true, Twist = true, UpperAngle = 30, LowerAngle = 0, TwistLowerAngle = -45, TwistUpperAngle = 45},
	["RightWrist"] = {Limits = true, Twist = true, UpperAngle = 30, LowerAngle = 0, TwistLowerAngle = -45, TwistUpperAngle = 45},
}

----- Module -----

local Ragdoll = {}
Ragdoll.__index = Ragdoll

--- Types ---

--Object
export type Object = { 
	State: RagdollStates,
	StateChanged: Signal.Signal<Player, RagdollStates>,
	Ragdoll: (self: Object) -> (),
	Unragdoll: (self: Object) -> (),
	Destroy: (self: Object) -> ()
}
type InternalObject = Object & {
	Player: Player,
	Character: Model?,
	Humanoid: Humanoid?,
	Trove: Trove.Trove,
	Run: RBXScriptConnection,
	SetupRagdoll: (self: InternalObject) -> (),
	SetupConnections: (self: InternalObject) -> ()
}

--Class
type Class = {
	new: (Player: Player) -> Object
}

--RagdollStates
export type RagdollStates = "Active" | "Inactive"

--- Methods ---

-- Constructor --

function Ragdoll.new(Player: Player): Object
	assert(Player, "Player missing.")
	local self = {} :: InternalObject

	--Vars
	self.Player = Player
	self.State = "Inactive"
	self.StateChanged = Signal.new()
	self.Trove = Trove.new()
	
	--Setup
	Ragdoll.SetupConnections(self)
	
	return setmetatable(self, Ragdoll)
end

-- Destroy --

function Ragdoll.Destroy(self: InternalObject)
	self.Trove:Destroy() --Cleanup connections
	self = nil :: any --Dispose of class
end

-- Ragdoll --

function Ragdoll.Ragdoll(self: InternalObject)
	assert(self.Character and self.Humanoid)
	if self.State == "Inactive" then
		self.State = "Active"
		
		--Setup
		self.Humanoid.AutomaticScalingEnabled = false
		for _, Limb in self.Character:GetDescendants() do
			if Limb:IsA("BallSocketConstraint") then
				Limb.Enabled = true
			elseif Limb:IsA("WeldConstraint") then
				Limb.Enabled = true
			elseif Limb:IsA("Motor6D") and Limb.Name ~= "Root" then
				Limb.Enabled = false
			end
		end
		
		--Network Ownership
		for _, Limb in self.Character:GetDescendants() do
			if Limb:IsA("BasePart") then
				Limb:SetNetworkOwner(self.Player)
			end
		end
		
		--Setup Force
		local Head = self.Character:FindFirstChild("Head") :: BasePart
		local Root = self.Humanoid.RigType == Enum.HumanoidRigType.R15 and self.Character:FindFirstChild("HumanoidRootPart") :: BasePart or self.Character:FindFirstChild("Torso") :: BasePart
		local LeftHand = self.Character:FindFirstChild("LeftHand") :: BasePart or self.Character:FindFirstChild("Left Arm") :: BasePart
		local RightHand = self.Character:FindFirstChild("RightHand") :: BasePart or self.Character:FindFirstChild("Right Arm") :: BasePart
		local Att = Instance.new("Attachment"); Att.Name = "MoveForce"; Att.Parent = Root
		local Force = Instance.new("VectorForce"); Force.Parent = Att; Force.Attachment0 = Att
		Force.RelativeTo = Enum.ActuatorRelativeTo.World; Force.Force = Vector3.zero
		assert(Root, LeftHand, RightHand)
		
		--Run Force
		if self.Run then self.Trove:Remove(self.Run) end
		self.Run = self.Trove:Add(RunService.PostSimulation:Connect(function()
			if Root then Root.CanCollide = false end; if Head then Head.CanCollide = true end
			if self.Humanoid and self.Humanoid:GetState() ~= Enum.HumanoidStateType.Dead then
				local MoveInterval: number = 0.1
				local LastMoved: number = os.time()
				local Moving: boolean = false
				self.Humanoid.AutoRotate = false --First person breaks otherwise
				
				--Move
				task.delay(MoveInterval * 2, function()
					local MoveDir = ((self.Humanoid.MoveDirection.Magnitude > 0) and (self.Humanoid.MoveDirection.Unit * Vector3.new(1, 0, 1) * (self.Humanoid.WalkSpeed * workspace.Gravity/300))) or Vector3.zero
					if not Moving and MoveDir.Magnitude > 0 and os.time() - LastMoved >= MoveInterval then
						Moving = true
						LastMoved = os.time()

						--Push Arms
						LeftHand.AssemblyLinearVelocity = MoveDir.Unit * self.Humanoid.WalkSpeed + Vector3.new(0, workspace.Gravity/3, 0)
						RightHand.AssemblyLinearVelocity = MoveDir.Unit * self.Humanoid.WalkSpeed + Vector3.new(0, workspace.Gravity/3, 0)

						--Push
						Root.AssemblyLinearVelocity = MoveDir

						--Stop
						task.delay(MoveInterval, function()
							Force.Force = Vector3.zero
							Moving = false
						end)
					end
				end)
			end
		end))
		
		--State Changed
		self.StateChanged:Fire(self.Player, self.State)
	end
end

-- Unragdoll --

function Ragdoll.Unragdoll(self: InternalObject)
	assert(self.Character and self.Humanoid)
	if self.State == "Active" then
		
		--Setup
		for _, Limb in self.Character:GetDescendants() do
			if Limb:IsA("BallSocketConstraint") then
				Limb.Enabled = false
			elseif Limb:IsA("WeldConstraint") then
				Limb.Enabled = false
			elseif Limb:IsA("Motor6D") then
				Limb.Enabled = true
			end
		end
		self.Humanoid.AutomaticScalingEnabled = true
		self.Humanoid.BreakJointsOnDeath = true
		self.Humanoid.AutoRotate = true
		
		--Destroy Force
		local Root = self.Humanoid.RootPart
		local Force = Root and Root:FindFirstChild("MoveForce")
		if Force then
			Force:Destroy()
		end
		
		--Network Ownership
		for _, Limb in self.Character:GetDescendants() do
			if Limb:IsA("BasePart") then
				Limb:SetNetworkOwner(self.Player)
			end
		end
		
		--Cleanup
		if self.Run then self.Trove:Remove(self.Run) end
		
		self.State = "Inactive"
		self.StateChanged:Fire(self.Player, self.State)
	end
end

--- Internal Methods ---

--Sets up Ragdoll
function Ragdoll.SetupRagdoll(self: InternalObject): ()
	assert(self.Character, "Character missing.")
	
	--Setup Constraints
	for _, Limb in self.Character:GetDescendants() do
		if Limb:IsA("Motor6D") then

			--Setup constraints
			local Att0 = Instance.new("Attachment"); Att0.Parent = Limb.Part0; Att0.CFrame = Limb.C0
			local Att1 = Instance.new("Attachment"); Att1.Parent = Limb.Part1; Att1.CFrame = Limb.C1
			local Constraint = Instance.new("BallSocketConstraint"); Constraint.Parent = Limb.Part0
			Constraint.Attachment0 = Att0; Constraint.Attachment1 = Att1
			Constraint.LimitsEnabled = true; Constraint.TwistLimitsEnabled = true
			Constraint.Enabled = false
			
			--Apply Limits
			if ConstraintLimits[Limb.Name] then
				Constraint.LimitsEnabled = ConstraintLimits[Limb.Name]["Limits"]
				Constraint.TwistLimitsEnabled = ConstraintLimits[Limb.Name]["Twist"]
				Constraint.UpperAngle = ConstraintLimits[Limb.Name]["UpperAngle"]
				Constraint.TwistLowerAngle = ConstraintLimits[Limb.Name]["TwistLowerAngle"]
				Constraint.TwistUpperAngle = ConstraintLimits[Limb.Name]["TwistUpperAngle"]
			end

		elseif Limb.Name == "AccessoryWeld" and Limb:IsA("Weld") then

			--Welds
			local Weld = Instance.new("WeldConstraint"); Weld.Parent = Limb.Parent
			Weld.Part0 = Limb.Part0
			Weld.Part1 = Limb.Part1
			Weld.Enabled = true
		end
	end
end

--Sets up Connections
function Ragdoll.SetupConnections(self: InternalObject): ()
	
	--Died
	local function Died(): ()
		if self.State == "Inactive" then
			self:Ragdoll()
		end
	end
	
	--Character Added
	local function CharacterAdded(newCharacter: Model): ()
		
		--Update Character
		if not newCharacter:IsDescendantOf(game) then newCharacter.AncestryChanged:Wait() end --Wait for character to be parented
		self.Character = newCharacter
		self.Humanoid = newCharacter:FindFirstChild("Humanoid") :: Humanoid		
		assert(self.Humanoid).BreakJointsOnDeath = false
		self.Humanoid.RequiresNeck = false
		
		--Connections
		self.Trove:Add(assert(self.Humanoid, "Humanoid not found.").Died:Once(Died))
		
		--Setup
		self:SetupRagdoll()
		self:Unragdoll()
	end
	if self.Player.Character then CharacterAdded(self.Player.Character) end
	self.Trove:Add(self.Player.CharacterAdded:Connect(CharacterAdded))
end

return Ragdoll :: Class