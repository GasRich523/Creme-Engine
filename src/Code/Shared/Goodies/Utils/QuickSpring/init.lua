--!strict

--[[

----- ABOUT -----

Wrapper for Fractality's SPR.

--]]

----- Variables -----

local SPR = require(script.SPR)

local Stored: {
	[any]: any	
} = {}

----- Module -----

--- Stop ---

local function Stop(Inst: Instance, Property: string?): ()
	if Stored[Inst] then
		SPR.stop(Inst, Property)
		Stored[Inst] = nil
	end
end

--- Method ---

return function(Inst: Instance, DampingRatio: number, Frequency: number, Properties: {[string]: any}, Callback: (...any) -> (...any)): ()
	Stop(Inst) --Stop previous

	--Store time
	local Now = os.time()
	local Time = Stored[Inst] or os.time()
	Stored[Inst] = Time
	
	--Completed
	SPR.completed(Inst, function()
		if Stored[Inst] == Now then --Prevents Stacking
			if Callback then Callback() end
			Stop(Inst)
		end
	end)

	--Target
	SPR.target(Inst, DampingRatio, Frequency, Properties)
end