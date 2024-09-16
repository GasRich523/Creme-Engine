--!strict

----- Module -----

local Internal = {}

--- Types ---

export type Table = {
	Table: {[any]: any},
	Connection: RBXScriptConnection?,
	LastTime: number
}
export type Tables = {[number]: Table}
export type PlayerTables = {[Player]: Tables}

--- Methods ---

-- For Each --

--[[
This takes a deep table and runs the passed callback against all of its values, additional
copies of the first table can optionally be passed for comparisions.
--]]

function Internal.ForEach<T>(Table: T, Callback: (string, any, T, ...T) -> (), ...: T): ()
	assert(typeof(Table) == "table", "Passed argument isn't a table.")

	local Args = {...}
	for _, v in Args do
		assert(typeof(v) == "table", "Passed argument isn't a table.")
	end

	for k, v in Table do
		if typeof(v) == "table" then
			local Values = {}
			for _, t in Args do
				Values[#Values + 1] = assert(typeof(t) == "table" and t)[k]
			end
			Internal.ForEach(v, Callback, table.unpack(Values))
		end
		Callback(k, v, Table, ...)
	end
end

-- Are Tables Equal --

--[[
This compares 2 deep tables against each other.
--]]

function Internal.AreTablesEqual<T1, T2>(Table1: T1, Table2: T2): boolean
	assert(typeof(Table1) == "table" and typeof(Table2) == "table", "Passed arguments aren't tables.")
	for k, v1 in Table1 do
		local v2 = Table2[k]
		if type(v1) == "table" and type(v2) == "table" then
			if not Internal.AreTablesEqual(v1, v2) then
				return false
			end
		elseif v1 ~= v2 then
			return false
		end
	end
	return true
end

-- Deep Copy --

--[[
Deep copies the given table.
--]]

function Internal.DeepCopy<T>(Table: T): T
	assert(typeof(Table) == "table", "Passed argument isn't a table.")
	local TableCopy = table.clone(Table)
	for k, v in TableCopy do
		if type(v) == "table" then
			TableCopy[k] = Internal.DeepCopy(v)
		end
	end
	return (TableCopy :: any) :: T
end

-- FindSelf --

--[[
Looks for the target Table in the Container table's keys.
--]]

function Internal.FindTable<T, S>(Container: T, Target: S): boolean
	assert(typeof(Container) == "table" and typeof(Target) == "table", "Passed arguments aren't tables.")
	for _, t: {[any]: any} in Container do
		for _, v in t do
			if v == Target then
				return true
			end
		end
	end
	return false
end

return Internal