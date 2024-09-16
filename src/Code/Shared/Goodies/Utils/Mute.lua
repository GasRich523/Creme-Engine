--!strict

--[[

----- ABOUT -----

Utility Mute Class.

----- LICENSE -----

MIT NON-AI License

Copyright (c) 2024, JustBorgar & Caffeine Overflow

Permission is hereby granted, free of charge, to any person obtaining a copy of the software and associated documentation files (the "Software"),
to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions.

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

In addition, the following restrictions apply:

1. The Software and any modifications made to it may not be used for the purpose of training or improving machine learning algorithms,
including but not limited to artificial intelligence, natural language processing, or data mining. This condition applies to any derivatives,
modifications, or updates based on the Software code. Any usage of the Software in an AI-training dataset is considered a breach of this License.

2. The Software may not be included in any dataset used for training or improving machine learning algorithms,
including but not limited to artificial intelligence, natural language processing, or data mining.

3. Any person or organization found to be in violation of these restrictions will be subject to legal action and may be held liable
for any damages resulting from such use.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE
OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--]]

----- Variables -----

local Utils = script.Parent

local QuickTween = require(Utils.QuickTween)

local Stored: {[Instance]: {
	Volume: number,
	Changed: RBXScriptConnection?
}} = {}

----- Module -----

--- Method ---

return function(Sound: Sound, Toggle: boolean): ()
	assert(Sound, "Missing sound/playlist")
	
	--Self
	local self = Stored[Sound] or {
		Volume = Sound.Volume,
		Changed = nil :: RBXScriptConnection?
	}
	Stored[Sound] = self
	
	--Mute
	if Toggle then

		--Tween volume down
		QuickTween(Sound, TweenInfo.new(0.5), {Volume = 0}, function(self)
			if self then
				
				--Ignore if another script changed the volume
				if self.Changed then self.Changed:Disconnect() end
				self.Changed = Sound:GetPropertyChangedSignal("Volume"):Connect(function()
					if Sound.Volume > 0 then --Ignore if another script restored the volume
						if self.Changed then self.Changed:Disconnect() end
						self = nil :: any
						Stored[Sound] = self
					end
				end)
			end
		end, self)

	--Unmute
	elseif self then

		--Clean
		if self.Changed then self.Changed:Disconnect() end

		--Restore volume
		QuickTween(Sound, TweenInfo.new(0.5), {Volume = self.Volume}, function()
			self = nil :: any
		end)
	end
	Stored[Sound] = self
end