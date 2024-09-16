--!strict

--[[
Basic sound playlist handler class.

This system makes a lot of assumptions such as you never wanting to reset
nor update the contents of the playlist.

* Play here is the equivalent of sound.resume (except on ReShuffle).
* Stop here is the equivalent of sound.pause (except on ReShuffle).
* Newly added sounds won't be added to the playlist, and removed ones will break it.
* Directly altering the sounds will produce unwanted side effects.

For other projects with other needs, fork the module.

--]]

----- Variables -----

local Code = workspace:WaitForChild("Code")
local Shared = Code:WaitForChild("Shared")
local Resources = Shared:WaitForChild("Resources")
local Goodies = Shared:WaitForChild("Goodies")

local Signal = require(Resources.RbxUtil.Signal)
local Trove = require(Resources.RbxUtil.Trove)
local TableUtil = require(Resources.RbxUtil.TableUtil)
local QuickTween = require(Goodies.Utils.QuickTween)

----- Module -----

local Playlist = {}
Playlist.__index = Playlist

--- Types ---

--Object
export type Object = { 
	Container: Instance,
	State: States,
	CurrentSound: Sound?,
	Sounds: {Sound},
	StateChanged: Signal.Signal<States>,
	SoundChanged: Signal.Signal<Sound>,
	Play: (self: Object) -> (),
	Stop: (self: Object) -> (),
	Skip: (self: Object) -> (),
	Rewind: (self: Object) -> ()
}
type InternalObject = Object & {
	AutoPlay: boolean,
	ReShuffle: boolean,
	Trove: Trove.Trove,
	SoundsData: {[Sound]: SoundData}
}

--Class
type Class = {
	new: (Container: Instance, AutoPlay: boolean?, ReShuffle: boolean?) -> Object
}

--States
export type States = "Playing" | "Paused" | "Stopped"

--SoundData
type SoundData = {
	Volume: number,
	Tween: Tween?
}

--- Methods ---

-- Constructor --

function Playlist.new(Container: Instance, AutoPlay: boolean?, ReShuffle: boolean?): Object
	assert(Container, "Container missing.")
	local self = {} :: InternalObject
	
	self.Container = Container
	self.State = "Stopped"
	self.CurrentSound = nil
	self.AutoPlay = AutoPlay ~= nil and AutoPlay or false
	self.ReShuffle = ReShuffle ~= nil and ReShuffle or false
	self.Sounds, self.SoundsData = {}, {}
	self.Trove = Trove.new()
	self.StateChanged = Signal.new()
	self.SoundChanged = Signal.new()
	
	Initialize(self)
	
	return setmetatable(self, Playlist)
end

-- Play --

function Playlist.Play(self: Object): ()
	local self = self :: InternalObject --Refinement
	assert(self.CurrentSound)
	
	--Clean
	self.Trove:Clean()
	
	--Ended
	local function Ended(): ()
		self:Skip()
	end
	self.Trove:Add(self.CurrentSound.Ended:Connect(Ended))
	self.Trove:Add(self.CurrentSound.Stopped:Connect(Ended))
	
	--Play
	FadeIn(self)
	--if self.State ~= "Paused" then --This is correct when using a single playlist, it's not when switching between multiple ones
		self.SoundChanged:Fire(self.CurrentSound)
	--end
	self.State = "Playing"
	self.StateChanged:Fire("Playing")
end

-- Stop --

function Playlist.Stop(self: Object): ()
	local self = self :: InternalObject --Refinement
	if self.CurrentSound and self.State == "Playing" then
		FadeOut(self)
		self.State = "Paused"
		self.StateChanged:Fire("Paused")
		
		--ReShuffle
		if self.ReShuffle and #self.Sounds > 1 then
			local function ReShuffle()
				local ReShuffled = TableUtil.Shuffle(self.Sounds)
				if ReShuffled[1] ~= self.CurrentSound then
					return ReShuffled
				end
				return ReShuffle()
			end
			self.Sounds = ReShuffle()
			self.CurrentSound = self.Sounds[1]
		end
	end
end

-- Skip --

function Playlist.Skip(self: Object): ()
	local self = self :: InternalObject --Refinement
	if self.CurrentSound and self.State == "Playing" then
		self.Trove:Clean()
		for _, Sound in self.Sounds do
			Sound:Stop()
		end
		local CurrentIndex = assert(table.find(self.Sounds, self.CurrentSound))
		self.CurrentSound = self.Sounds[CurrentIndex + 1] or self.Sounds[1]
		self:Play()
	end
end

-- Revert --

function Playlist.Rewind(self: Object): ()
	local self = self :: InternalObject --Refinement
	if self.CurrentSound and self.State == "Playing" then
		self.Trove:Clean()
		for _, Sound in self.Sounds do
			Sound:Stop()
		end
		local CurrentIndex = assert(table.find(self.Sounds, self.CurrentSound))
		self.CurrentSound = self.Sounds[CurrentIndex - 1] or self.Sounds[#self.Sounds]
		self:Play()
	end
end

--- Internal Methods ---

-- FadeIn --

function FadeIn(self: InternalObject): ()
	local Sound = assert(self.CurrentSound)
	local SoundData: SoundData = self.SoundsData[Sound]
	
	Sound.Volume = 0
	Sound:Resume()
	
	if SoundData.Tween then SoundData.Tween:Pause(); SoundData.Tween:Destroy() end
	SoundData.Tween = QuickTween(Sound, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
		Volume = SoundData.Volume
	})
end

-- FadeOut --

function FadeOut(self: InternalObject): ()
	local Sound = assert(self.CurrentSound)
	local SoundData: SoundData = self.SoundsData[Sound]
	
	if SoundData.Tween then SoundData.Tween:Pause(); SoundData.Tween:Destroy() end
	SoundData.Tween = QuickTween(Sound, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
		Volume = 0
	}, function()
		if not self.ReShuffle or #self.Sounds == 1 then --When reshuffle is on the sound will never be resumed anyways
			Sound:Pause()
		else
			Sound:Stop()
		end
	end)
end

-- Initialize --

function Initialize(self: InternalObject): ()
	
	--Insert Sounds
	local Counter = 0
	for _, Sound in self.Container:GetChildren() do
		if Sound:IsA("Sound") then
			table.insert(self.Sounds, Sound)
			self.SoundsData[Sound] = {
				Volume = Sound.Volume
			}
			Counter += 1
		end
	end
	assert(Counter > 0, "Playlist container is empty.")
	
	--Shuffle Sounds
	self.Sounds = TableUtil.Shuffle(self.Sounds)
	self.CurrentSound = self.Sounds[1]
	
	--Autoplay
	if self.AutoPlay then
		self:Play()
	end
end

return Playlist :: Class