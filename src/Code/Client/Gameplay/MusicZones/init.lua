--!strict

--[[
Handles the game's music.
--]]

----- Services -----

local Players = game:GetService("Players")

----- Variables -----

local Player = Players.LocalPlayer
local PlayerGui: PlayerGui = Player:WaitForChild("PlayerGui")

local Code = workspace:WaitForChild("Code")
local Shared = Code:WaitForChild("Shared")
local Resources = Shared:WaitForChild("Resources")
local Goodies = Shared:WaitForChild("Goodies")

local GameplayFolder = workspace:WaitForChild("Gameplay")
local ZonesFolder = GameplayFolder:WaitForChild("Music Zones")

local ZoneUI = script:WaitForChild("MusicZoneUI"); ZoneUI.Enabled = true
local ZoneFrame = ZoneUI:WaitForChild("Frame"); ZoneFrame.GroupTransparency = 1
local ZoneTitle = ZoneFrame:WaitForChild("Title"); ZoneUI.Parent = PlayerGui
local ZoneTitleSize: UDim2 = ZoneTitle.Size; ZoneTitle.Size = UDim2.fromScale(ZoneTitleSize.X.Scale/2, ZoneTitleSize.Y.Scale/2)

local Signal = require(Resources.RbxUtil.Signal)
local Trove = require(Resources.RbxUtil.Trove)
local Icon = require(Resources.TopbarPlus.Icon)
local QuickTween = require(Goodies.Utils.QuickTween)
local Playlist = require(script.Playlist)

local ZonesTrove = Trove.new()
local ZoneTrove = ZonesTrove:Extend()
local TweenTrove = ZonesTrove:Extend()

local PlayingLabel: TextLabel = nil
local RewindIcon, PlayingIcon, SkipIcon

local PlayOnlyWithinBounds = false --Stops the current playlist when the player is not inside a zone
local OnCooldown = false

local StoredPlaylists: {
	[Instance]: Playlist.Object
} = {}

----- Module -----

local MusicZones = {}

MusicZones.State = "Stopped" :: Playlist.States
MusicZones.CurrentSound = nil :: Sound?
MusicZones.CurrentPlaylist = nil :: Playlist.Object?

MusicZones.StateChanged = Signal.new() :: Signal.Signal<Playlist.States>
MusicZones.SoundChanged = Signal.new() :: Signal.Signal<Sound>
MusicZones.PlaylistChanged = Signal.new() :: Signal.Signal<Playlist.Object>

--- Types ---

export type States = Playlist.States
export type Playlist = Playlist.Object

--- Methods ---

-- Toggle --

function MusicZones:Toggle(Active: boolean): ()
	
	--Icons
	ToggleIcons(Active)
	
	if Active then
		
		--Update trove
		ZoneTrove = ZoneTrove or ZonesTrove:Extend()
		TweenTrove = TweenTrove or ZonesTrove:Extend()
		
		--Spawned connection
		ZonesTrove:Add(Player.CharacterAdded:Connect(Spawned))
		if Player.Character then
			Spawned(Player.Character)	
		end
	else
		ZonesTrove:Clean() --Clean connections
	end
end

--- Internal Methods ---

-- ToggleIcons --

function ToggleIcons(Active: boolean): ()
	
	--Rewind
	RewindIcon = ZonesTrove:Add(Icon.new())
		:setName("Rewind")
		:setImage("rbxassetid://11422922556")
		:setCaption("Rewind")
		:align("Right")
		:oneClick(true)
		:call(function(Icon: any): ()
			if not MusicZones.CurrentPlaylist or #MusicZones.CurrentPlaylist.Sounds == 1 then
				Icon:lock()
			end
			ZonesTrove:Add(MusicZones.PlaylistChanged:Connect(function()
				if MusicZones.CurrentPlaylist and #MusicZones.CurrentPlaylist.Sounds > 1 then
					Icon:unlock()
				else
					Icon:lock()
				end
			end))
		end)
		.selected:Connect(function(): ()
			if MusicZones.CurrentPlaylist then
				MusicZones.CurrentPlaylist:Rewind()
			end
		end)
	
	--Playing
	PlayingIcon = ZonesTrove:Add(Icon.new())
		:setName("Playing")
		:setImage("rbxassetid://11432850205")
		:setLabel(string.rep(" ", 35))
		:call(function(Icon: any): () --Scaled Label
			PlayingLabel = Instance.new("TextLabel")
			PlayingLabel.BackgroundTransparency = 1; PlayingLabel.Font = Enum.Font["Montserrat"] --How is a font that just released even deprecated
			PlayingLabel.AnchorPoint = Vector2.new(0.5, 0.5); PlayingLabel.Position = UDim2.fromScale(0.5, 0.5)
			PlayingLabel.Size = UDim2.fromScale(1, 0.75); PlayingLabel.TextScaled = true
			PlayingLabel.TextYAlignment = Enum.TextYAlignment.Center
			PlayingLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
			PlayingLabel.RichText = true; PlayingLabel.Parent = Icon:getInstance("IconLabelContainer")
			PlayingLabel.Text = "Playing: Nothing"
		end)
		:align("Right")
		:lock()
	
	--Skip
	SkipIcon = ZonesTrove:Add(Icon.new())
		:setName("Skip")
		:setImage("rbxassetid://11422923443")
		:setCaption("Skip")
		:align("Right")
		:oneClick(true)
		:call(function(Icon: any): ()
			if not MusicZones.CurrentPlaylist or #MusicZones.CurrentPlaylist.Sounds == 1 then
				Icon:lock()
			end
			ZonesTrove:Add(MusicZones.PlaylistChanged:Connect(function()
				if MusicZones.CurrentPlaylist and #MusicZones.CurrentPlaylist.Sounds > 1 then
					Icon:unlock()
				else
					Icon:lock()
				end
			end))
		end)
		.selected:Connect(function(): ()
			if MusicZones.CurrentPlaylist then
				MusicZones.CurrentPlaylist:Skip()
			end
		end)
end

-- Show Zone UI --

function ShowZoneUI(Show: boolean): ()
	local Start, End = (Show and 1 or 0), (Show and 0 or 1)
	local Multiplier = (Start and 0.75 or 0.5)
	local Time = math.abs(Start - End) * Multiplier
	
	--Cleanup
	TweenTrove:Clean()
	
	--Update Title
	local TitleTween = QuickTween(ZoneTitle, TweenInfo.new(Time, Enum.EasingStyle.Quad), {
		Size = Show and ZoneTitleSize or UDim2.fromScale(ZoneTitleSize.X.Scale/2, ZoneTitleSize.Y.Scale/2)
	})
	TweenTrove:Add(TitleTween)
	ZoneTitle.Text = MusicZones.CurrentPlaylist and MusicZones.CurrentPlaylist.Container.Name or ZoneTitle.Text

	--Transition
	local FrameTween = QuickTween(ZoneFrame, TweenInfo.new(Time, Enum.EasingStyle.Quad), {
		GroupTransparency = End
	}, function(): ()
		if Show then
			local Thread: thread = task.delay(1, function() --Fades out automatically
				ShowZoneUI(not Show)
			end)
			TweenTrove:Add(function()
				if Thread and Thread ~= coroutine.running() then task.cancel(Thread) end
			end)
		end
		ZoneFrame.GroupTransparency = End
	end)
	TweenTrove:Add(FrameTween)
end

-- Touched --

function Touched(Hit: Instance): ()
	local IsDescendant = (Hit.Parent and Hit.Parent.Parent == ZonesFolder)
	local NewPlaylist = IsDescendant and (not MusicZones.CurrentPlaylist or StoredPlaylists[assert(Hit.Parent)] ~= MusicZones.CurrentPlaylist)
	if NewPlaylist and not OnCooldown then
		assert(Hit.Parent)
		OnCooldown = true

		--Update playlist
		ZoneTrove:Clean()
		if MusicZones.CurrentPlaylist then MusicZones.CurrentPlaylist:Stop() end
		StoredPlaylists[Hit.Parent] = StoredPlaylists[Hit.Parent] or Playlist.new(Hit.Parent, false, true)
		MusicZones.CurrentPlaylist = StoredPlaylists[Hit.Parent]
		assert(MusicZones.CurrentPlaylist)
		
		--Show UI
		ShowZoneUI(true)
		
		--SoundChanged connection
		local function SoundChanged(Sound: Sound): ()
			PlayingLabel.Text = "Playing: "..Sound.Name --Update topbar label
			MusicZones.SoundChanged:Fire(Sound)
		end
		ZoneTrove:Add(MusicZones.CurrentPlaylist.SoundChanged:Connect(SoundChanged))
		
		--Play
		MusicZones.CurrentPlaylist:Play()
		MusicZones.PlaylistChanged:Fire(MusicZones.CurrentPlaylist)
		
		--Cooldown
		task.delay(0.5, function()
			OnCooldown = false
		end)
	end
end

-- TouchEnded --

function TouchEnded(Hit: BasePart, RootPart: BasePart): ()
	local IsDescendant = (Hit.Parent and Hit.Parent.Parent == ZonesFolder)
	local CurrentPlaylist = IsDescendant and (MusicZones.CurrentPlaylist and StoredPlaylists[assert(Hit.Parent)] == MusicZones.CurrentPlaylist)
	local NotInPart = CurrentPlaylist and not PartInZone(RootPart, ZonesFolder)
	print(PartInZone(RootPart, ZonesFolder))
	if NotInPart and not OnCooldown then
		
		--Update playlist
		ZoneTrove:Clean()
		if MusicZones.CurrentPlaylist then MusicZones.CurrentPlaylist:Stop() end
		MusicZones.CurrentPlaylist = nil
		
		--Update topbar label
		PlayingLabel.Text = "Playing: Nothing"
		
		--Cooldown
		task.delay(0.5, function()
			OnCooldown = false
			
			--Check for initial touch
			for _, Part in RootPart:GetTouchingParts() do
				Touched(Part)
			end
		end)
	end	
end

-- PartInZone --

--Used by TouchEnded
function PartInZone(Subject: BasePart, Container: Instance): ()
	for _, Hit in Subject:GetTouchingParts() do
		local IsDescendant = (Hit.Parent and Hit.Parent.Parent == ZonesFolder)
		if IsDescendant then
			return true
		end
	end
	return false
end

-- Spawned --

function Spawned(newChar: Model): ()
	local Character = newChar
	local Humanoid = Character:WaitForChild("Humanoid") :: Humanoid
	local RootPart = Character:WaitForChild("HumanoidRootPart") :: BasePart

	--Connections
	ZonesTrove:Add(Humanoid.Touched:Connect(Touched))
	if PlayOnlyWithinBounds then
		ZonesTrove:Add(RootPart.TouchEnded:Connect(function(Hit: BasePart) --Thanks for not adding this method to the humanoid I guess
			task.delay(0.5, function()
				TouchEnded(Hit, RootPart)
			end)
		end))
	end
	for _, Part in RootPart:GetTouchingParts() do --Initial touch often fails, this triggers it manually
		Touched(Part)
	end
end

return MusicZones