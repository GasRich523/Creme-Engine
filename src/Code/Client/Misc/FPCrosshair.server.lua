--strict

----- Services -----

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

----- Variables -----

local Player = Players.LocalPlayer
local PlayerGui: PlayerGui = Player:WaitForChild("PlayerGui")
local CrosshairGui = script.FPCrosshairGui; CrosshairGui.Enabled = false; CrosshairGui.Parent = PlayerGui

----- Code -----

local function Run(): ()
	local Character = Player.Character
	local Head = Character and Character:FindFirstChild("Head")
	if Head then
		
		--Hide Mouse/Show Crosshair
		CrosshairGui.Enabled = Head.LocalTransparencyModifier == 1
		UserInputService.MouseIconEnabled = not CrosshairGui.Enabled
	end
end
RunService.PostSimulation:Connect(Run)
