--!strict
--Needs to be moved to the moveset

----- Services -----

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

----- Variables -----

local Player = Players.LocalPlayer
local Character = (Player.Character or Player.CharacterAdded:Wait()) :: Model
local Humanoid = Character:WaitForChild("Humanoid") :: Humanoid
local Head = Character:WaitForChild("Head") :: BasePart

local Code = workspace:WaitForChild("Code")
local Shared = Code:WaitForChild("Shared")
local Resources = Shared:WaitForChild("Resources")

local Net = require(Resources.RbxUtil.Net)
local Trove = require(Resources.RbxUtil.Trove).new()

local Remote = Net:RemoteEvent("Ragdoll")

----- Code -----

game.UserInputService.InputBegan:Connect(function(key, pressed)
	if key.KeyCode == Enum.KeyCode.R and not pressed then
		if Humanoid.RootPart and not Humanoid.RootPart.Anchored then --Don't ragdoll if the rootpart is anchored
			Remote:FireServer()
		end
	end
end)

--Ragdoll
local function Ragdoll(State: "Active" | "Inactive")
	if State == "Active" then
		
		--Set state
		Humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
		
		--Run
		Trove:Clean()
		Trove:Add(RunService.PreRender:Connect(function(): ()
			
			--Set State
			if Humanoid:GetState() ~= Enum.HumanoidStateType.Dead then
				Humanoid:ChangeState(Enum.HumanoidStateType.Ragdoll)
			end
		end))
		
		--Disable Animations
		local Animator = Humanoid:FindFirstChild("Animator") :: Animator
		for _, Anim: AnimationTrack in Animator:GetPlayingAnimationTracks() do
			Anim:Stop(0)
		end
		
		--Push (R6 rigs tend to not fall, this pushes them a lil bit)
		if Humanoid.RigType == Enum.HumanoidRigType.R6 then
			local Force = 50
			if Humanoid.RootPart then
				Humanoid.RootPart.AssemblyLinearVelocity = Vector3.new(0, 0, (math.random(-1, 1) > 0 and 1 or -1) * Force)
			end		
		end
	else
		
		--Disable Animations
		local Animator = Humanoid:FindFirstChild("Animator") :: Animator
		for _, Anim: AnimationTrack in Animator:GetPlayingAnimationTracks() do
			Anim:Stop(0)
		end
		
		--Set State
		if Humanoid:GetState() ~= Enum.HumanoidStateType.Dead then
			Humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		end
		
		--Cleanup
		Trove:Clean()
	end
end
Remote.OnClientEvent:Connect(Ragdoll)

local function CharacterAdded(newCharacter: Model): ()
	Character = newCharacter
	Humanoid = Character:WaitForChild("Humanoid") :: Humanoid
	Head = Character:WaitForChild("Head") :: BasePart
end
Player.CharacterAdded:Connect(CharacterAdded)