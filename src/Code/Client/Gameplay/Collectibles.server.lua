--strict

--[[
Game's client-side collectible system.

Read the server script/database for information on it's usage.
--]]

----- Service -----

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

----- Variables -----

local Player = Players.LocalPlayer
local Character: Model = Player.Character or Player.CharacterAdded:Wait()
local Humanoid: Humanoid & {Animator: Animator} = Character:WaitForChild("Humanoid") :: Humanoid & {Animator: Animator}
local RootPart: BasePart = Character:WaitForChild("HumanoidRootPart") :: Part
local PlayerGui: PlayerGui = Player:WaitForChild("PlayerGui")

local Gui = script:WaitForChild("Collectibles"); Gui.Enabled = false; Gui.Parent = PlayerGui
local CollectedFrame = Gui:WaitForChild("CollectedFrame")
--local MainFrame = Gui:WaitForChild("MainFrame")
--local WipeFrame = Gui:WaitForChild("WipeFrame") --Current UI is a placeholder

local Assets = ReplicatedStorage:WaitForChild("Assets")
local Animations = Assets:WaitForChild("Animations")
local Effects = Assets:WaitForChild("Effects")
local Sounds = Assets:WaitForChild("Sounds")

local Code = workspace:WaitForChild("Code")
local Client = Code:WaitForChild("Client")
local Shared = Code:WaitForChild("Shared")
local Resources = Shared:WaitForChild("Resources")
local Goodies = Shared:WaitForChild("Goodies")

local GameplayFolder = workspace:WaitForChild("Gameplay")
local CollectiblesFolder = GameplayFolder:WaitForChild("Collectibles")
local MusicGroup = workspace:WaitForChild("Volume").Music

local PickupMusic = Sounds.Collectibles.PickupMusic
local PickupAnim = Animations.Collectibles.Pickup

local QuickTween = require(Goodies.Utils.QuickTween)
local Mute = require(Goodies.Utils.Mute)
local Net = require(Resources.RbxUtil.Net)
local Trove = require(Resources.RbxUtil.Trove)

local Remote = Net:RemoteEvent("Collectibles")

local SpinSpeed: number = 120
local FloatHeight: number = 0.025
local FloatSpeed: number = 0.00075
local WipeCooldown: number = 10
local WipeOnCooldown: boolean = false
local AnimateDebounce: boolean = false
local PlayPickupAnim: AnimationTrack? = nil
local LastCollectible: BasePart?, LastCollectiblePos: CFrame? = nil, nil

local Stored: {[Instance]: {
	InitialCF: CFrame,
	Active: boolean,
	Count: number,
	DirUp: boolean,
	Trove: Trove.Trove,
}} = {}

----- Code -----

--- Grab Collectible ---

--[[
Plays main collectible grabbing animation.
--]]

local function GrabCollectible(Active: boolean, Collectible: BasePart, CollectibleData: {[any]: any}?): ()
	if not AnimateDebounce then
		AnimateDebounce = true
		
		--Toggle
		if Active then
		
			--Disable movement
			RootPart.Anchored = true
			Humanoid:MoveTo(RootPart.Position)
			Mute(MusicGroup, true)
			
			--Apply Description
			if CollectibleData then
				CollectedFrame.Title.Text = CollectibleData.Title
				CollectedFrame.Description.Text = CollectibleData.Description
			end

			--Sound
			PickupMusic.Ended:Once(function()
				Mute(MusicGroup, false)
			end)
			PickupMusic:Play()

			--Position collectible
			local StoredPos = Collectible.CFrame
			Collectible.CFrame = RootPart.CFrame + Vector3.new(0, 4, 0)
			LastCollectible = Collectible
			LastCollectiblePos = StoredPos
			
			--Anim
			if PlayPickupAnim then PlayPickupAnim:Stop(); PlayPickupAnim:Destroy() end
			PlayPickupAnim = Humanoid.Animator:LoadAnimation(PickupAnim); assert(PlayPickupAnim)
			PlayPickupAnim:Play()

			-- UI Anim --

			--Setup
			CollectedFrame.LowerBar.Position = UDim2.new(-0.5, 0, 1, 0)
			CollectedFrame.UpperBar.Position = UDim2.new(1.5, 0, 0, 0)
			CollectedFrame.MiddleBar.BackgroundTransparency = 1
			CollectedFrame.Title.TextTransparency = 1
			CollectedFrame.Description.TextTransparency = 1
			CollectedFrame.Visible = true

			--Tween In
			QuickTween(CollectedFrame.LowerBar, TweenInfo.new(1.5, Enum.EasingStyle.Quart), {Position = UDim2.new(0.5, 0, 1, 0)})
			QuickTween(CollectedFrame.UpperBar, TweenInfo.new(1.5, Enum.EasingStyle.Quart), {Position = UDim2.new(0.5, 0, 0, 0)})
			QuickTween(CollectedFrame.MiddleBar, TweenInfo.new(1.5, Enum.EasingStyle.Sine), {BackgroundTransparency = 0})
			QuickTween(CollectedFrame.Title, TweenInfo.new(1.5), {TextTransparency = 0})
			QuickTween(CollectedFrame.Description, TweenInfo.new(1.5), {TextTransparency = 0}, function()

				--Wait for input
				QuickTween(CollectedFrame.Continue, TweenInfo.new(1.5 / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.In, -1, true), {TextTransparency = 1, TextStrokeTransparency = 1})
				UserInputService.InputBegan:Wait()
				CollectedFrame.Continue.TextTransparency = 1
				CollectedFrame.Continue.TextStrokeTransparency = 1

				--Tween Out
				QuickTween(CollectedFrame.LowerBar, TweenInfo.new(1.5 / 2, Enum.EasingStyle.Quart), {Position = UDim2.new(-0.5, 0, 1, 0)})
				QuickTween(CollectedFrame.UpperBar, TweenInfo.new(1.5 / 2, Enum.EasingStyle.Quart), {Position = UDim2.new(1.5, 0, 0, 0)})
				QuickTween(CollectedFrame.MiddleBar, TweenInfo.new(1.5 / 2, Enum.EasingStyle.Sine), {BackgroundTransparency = 1})
				QuickTween(CollectedFrame.Title, TweenInfo.new(1.5 / 2), {TextTransparency = 1})
				QuickTween(CollectedFrame.Description, TweenInfo.new(1.5 / 2), {TextTransparency = 1}, function()
					
					--End
					GrabCollectible(false, Collectible)
				end)
			end)
		end
		
	--Toggle Off
	elseif not Active then
		
		--Restore settings
		CollectedFrame.LowerBar.Position = UDim2.new(0.5, 0, 1, 0)
		CollectedFrame.UpperBar.Position = UDim2.new(0.5, 0, 0, 0)
		CollectedFrame.MiddleBar.BackgroundTransparency = 1
		CollectedFrame.Title.TextTransparency = 1
		CollectedFrame.Description.TextTransparency = 1
		CollectedFrame.Visible = false

		--Cleanup
		if LastCollectiblePos then Collectible.CFrame = LastCollectiblePos end
		if PlayPickupAnim then PlayPickupAnim:Stop(); PlayPickupAnim:Destroy() end

		--Restore movement
		RootPart.Anchored = false
		AnimateDebounce = false
	end
end

--- Animate Collectible ---

--[[
Handles the collectible's float & particle idle effects.
--]]

local function AnimateCollectible(Toggle: boolean, Collectible: BasePart): ()
	
	--Self
	local self = Stored[Collectible] or {
		InitialCF = Collectible.CFrame,
		Active = false,
		Count = 0,
		DirUp = false,
		Trove = Trove.new(),
	}
	Stored[Collectible] = self
	
	--Toggle On	
	if Toggle and not self.Active then
		self.Active = true
		
		--Spawn Task (delay didn't work)
		task.spawn(function(): ()
		
			--Randomize (so the positions of the collectibles differ)
			task.wait(Random.new():NextInteger(0, 2))
			
			--Run
			self.Trove:Clean()
			self.Trove:Add(RunService.PostSimulation:Connect(function(dt)
				
				--Direction/Speed
				local AnimDirection: Vector3 = Collectible:GetAttribute("AnimDirection") or Vector3.new(0, 1, 0)
				
				--Spin
				Collectible.CFrame *= CFrame.Angles((-math.rad(SpinSpeed) * dt) * AnimDirection.X, (-math.rad(SpinSpeed) * dt) * AnimDirection.Y, (-math.rad(SpinSpeed) * dt) * AnimDirection.Z)

				--Float
				if self.Count < FloatHeight then
					self.Count += FloatSpeed
					local Pos = if self.DirUp then self.Count else -self.Count
					Collectible.CFrame *= CFrame.new(Pos * AnimDirection.X, Pos * AnimDirection.Y, Pos * AnimDirection.Z)
				else
					self.DirUp = not self.DirUp
					self.Count = 0
				end
			end))
		end)
		
	--Toggle Off
	elseif not Toggle and not self.Active then
		
		--Cleanup
		self.Trove:Clean()
		if self.InitialCF then Collectible.CFrame = self.InitialCF end --Reset CF
		self.Active = false
	end
end

--- Award Collectible ---

--[[
Shows the collectible's pickup effect if data is passed, otherwise it just
shows/hides it.
--]]

local function AwardCollectible(Give: boolean, Collectible: BasePart, CollectibleData: {[any]: any}?): ()
	
	--Pickup Effect
	if Give and CollectibleData and Collectible.Parent then

		--Sound
		local Sound: Sound? = Sounds.Collectibles:FindFirstChild(Collectible.Parent.Name)
		if Sound then
			Sound:Play()
		end

		--Effect
		local Effect: Part? = Effects.Collectibles:FindFirstChild(Collectible.Parent.Name) :: Part
		local Att: Attachment? = Effect and Effect:FindFirstChild("CollectAtt") :: Attachment
		if Att then
			local Clone = Att:Clone(); Clone.Parent = Collectible
			local P1: ParticleEmitter, P2: ParticleEmitter = Clone:FindFirstChild("Particle") :: ParticleEmitter, Clone:FindFirstChild("Particle2") :: ParticleEmitter
			if P1 and P2 then P1:Emit(1); P2:Emit(15) end
			task.delay(1, function()
				if Clone then Clone:Destroy() end
			end)
		end

		--Grab
		if CollectibleData.Description then
			GrabCollectible(Give, Collectible, CollectibleData)
		end
	end

	--Particles
	for _, Particles in Collectible:GetDescendants() do
		if Particles:IsA("ParticleEmitter") then
			Particles.Enabled = not Give
		end
	end

	--Appearence
	Collectible.Transparency = Give and 1 or 0
	
	--Animate
	AnimateCollectible(not Give, Collectible)
end

--- Wipe Data ---

--[[
Server side this wipes the player's data, client side it just
resets the collectible's appearence.
--]]

local function WipeData(): ()
	if not WipeOnCooldown then
		WipeOnCooldown = true

		--Loop through every single collectible
		for _, CollectibleType: Folder in CollectiblesFolder:GetChildren() do
			for _, Collectible in CollectibleType:GetChildren() do
				if Collectible:IsA("BasePart") then
					AwardCollectible(false, Collectible)
				end
			end
		end

		--Cooldown
		task.delay(WipeCooldown, function(): ()
			WipeOnCooldown = false
		end)
	end
end

--- Game Loaded ---

--[[
Yep, the game loaded.

SwiftLoader needs a cleanup so i'll comment it out for this release.
--]]

local function GameLoaded(): ()
	Gui.Enabled = true --Enable UI
end

--Loaded
--if SwiftLoader.IsLoaded then
--	GameLoaded()
--else
--	SwiftLoader.PreLoaded:Connect(GameLoaded)
--end
GameLoaded()

--- Remote Called ---

--[[
Server requested the client to do something.
--]]

local function RemoteCalled(Command: string, ...: any): ()
	
	--Collected
	if Command == "Collected" then
		local Args: {any} = {...}
		local Active: boolean = Args[1]
		local HitArray: {[any]: any} = typeof(Args[2]) == "table" and Args[2] or {Args[2]} --This is just to save a couple lines
		local CollectibleData: {[any]: any}? = Args[3]
		
		--Award
		if HitArray.Enable then --Dictionary of Collectibles
			for Key: string, Array: {BasePart} in HitArray :: {[string]: {BasePart}} do
				if Key == "Enable" then --Enable
					for _, Part: BasePart in Array :: {BasePart} do
						AwardCollectible(Active, Part, CollectibleData)
					end
				else --Disable
					for _, Part: BasePart in Array :: {BasePart} do
						AwardCollectible(not Active, Part, CollectibleData)
					end
				end
			end
		else --Array of Collectibles
			for _, Part: BasePart in HitArray :: {BasePart} do
				AwardCollectible(Active, Part, CollectibleData)
			end
		end
	end
end
Remote.OnClientEvent:Connect(RemoteCalled)

--- Respawned ---

--[[
Player respawned.
--]]

local function Respawned(newCharacter: Model)
	Character = newCharacter
	Humanoid = Character:WaitForChild("Humanoid") :: Humanoid & {Animator: Animator}
	RootPart = Humanoid.RootPart :: Part
	
	--Cleanup
	if LastCollectible then
		GrabCollectible(false, LastCollectible)
	end
	AnimateDebounce = false
end
Player.CharacterAdded:Connect(Respawned)