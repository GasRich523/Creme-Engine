--!strict

--[[
Use this sparingly, it's bad for performance.
--]]

----- Services -----

local RunService = game:GetService("RunService")

----- Variables -----

local Internal = require(script.Parent.Internal)

local Tables: Internal.Tables = {}

----- Module -----

local ClientChanged = {}

--- Connect ---

function ClientChanged:Connect<T, S, U>(Table: T, Signal: S, UpdateRate: U): T
	assert(typeof(Table) == "table", "Passed argument isn't a table.")
	assert(typeof(Signal) == "table" and Signal.Fire ~= nil, "Passed argument isn't a signal.")
	assert(typeof(UpdateRate) == "number", "Passed argument isn't a number.")
	
	--Find Self
	if Internal.FindTable(Tables, Table) then
		warn("Table already connected.")
		return Table
	end
	
	--Copy
	local self: Internal.Table = {Table = Table, LastTime = os.clock()}
	local LastCopy: T = Internal.DeepCopy(Table)
	
	--Run
	local function Run(): ()
		local CurrentTime = os.clock()
		if CurrentTime - self.LastTime >= UpdateRate then
			
			--If data changed
			if not Internal.AreTablesEqual(Table, LastCopy) then
				Internal.ForEach(Table, function(Key, Value, Table, LastTable) --Fire Changed Values
					local OldValue = LastTable and LastTable[Key] or Value --Can't tell if this is a bug or not
					if typeof(Value) ~= "table" and Value ~= OldValue then
						Signal:Fire(Key, Value, OldValue, Table)
					end
				end, LastCopy)
				LastCopy = Internal.DeepCopy(Table) --Copy
			end
			
			self.LastTime = CurrentTime
		end
	end
	if self.Connection then self.Connection:Disconnect() end
	self.Connection = RunService.PostSimulation:Connect(Run)	
	
	Tables[#Tables + 1] = self
	return Table
end

--- Disconnect ---

function ClientChanged:Disconnect<T>(Table: T): T
	assert(typeof(Table) == "table", "Passed argument isn't a table.")
	local Found: boolean = false
	for i: number, t: {[any]: any} in Tables do
		for k: string, self: any in t do	
			if k == "Table" and self == Table then
				if self.Connection then self.Connection:Disconnect() end		
				table.remove(Tables, i)
				Found = true
			end
		end
	end
	if not Found then
		warn("Table not connected.")
	end
	return Table
end

return ClientChanged