--!strict

--[[
Simple QuickTween Class.
--]]

----- Services -----

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

----- Variables -----

local Code = workspace:WaitForChild("Code")
local Shared = Code:WaitForChild("Shared")
local Resources = Shared:WaitForChild("Resources")

local Utils = ReplicatedStorage:WaitForChild("Utils", 0.5) or Instance.new("Folder"); Utils.Name = "Utils"; Utils.Parent = ReplicatedStorage
local Containter = Instance.new("Folder"); Containter.Name = "QuickTween"; Containter.Parent = Utils
local Trove = require(Resources.RbxUtil.Trove)

----- Module -----

--OnCompletion
local function OnCompletion(Tween: Tween, Callback: ((...any) -> ())?, ...: any?): ()
	if Tween then
		if Callback then Callback(...) end --Callback is ran if passed
		Tween:Destroy()
	end
end

--Method
return function(Inst: Instance, TInfo: TweenInfo, Properties: {[string]: any}, Callback: ((...any) -> ())?, ...: any): (Tween, ((...any) -> ())?)
	assert(typeof(Inst) == 'Instance', "Must be an instance")
	assert(typeof(TInfo) == 'TweenInfo', "Must be TweenInfo")
	assert(typeof(Properties) == 'table', "Must be a table")
	assert(Callback == nil or typeof(Callback) == "function", "Must be nil or a function")
	
	local Args = {...}
	local TweenTrove = Trove.new()	
	
	local Tween: Tween = TweenService:Create(Inst, TInfo, Properties)
	Tween.Name = Inst.Name.."'s Tween" --For debugging
	Tween.Parent = Containter
	
	TweenTrove:Add(Tween.Completed:Once(function(): ()
		OnCompletion(Tween, Callback, table.unpack(Args))
	end))
	TweenTrove:AttachToInstance(Tween)
	Tween:Play()

	return Tween, Callback
end