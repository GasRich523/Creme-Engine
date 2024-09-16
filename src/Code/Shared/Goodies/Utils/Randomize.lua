--!strict

--[[

----- ABOUT -----

Utility randomizer class.

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

return function (Min: number, Max: number, LastRandom: (number? | {number}?), Range: number?): number?

	--Internal Method
	local function Internal(Min: number, Max: number, LastRandom: (number? | {[number]: number}?), Range: number?, _PreventOverflow: number, _Random: Random): number?
		assert(_PreventOverflow <= 5000, "Task Overflow")
		assert(Max and Min, "Arguments Missing")
		assert(not Range or Range < math.abs(Min - Max), "Range greater or equal to the available numbers")

		--Randomizes Number
		local Randomized = if (math.floor(Min) == Min and math.floor(Max) == Max) then _Random:NextInteger(Min, Max) else _Random:NextNumber(Min, Max) --Generates a number (if integers are passed, it'll look for the next int, else, a float)

		--Check if range is respected
		local OnRange = false
		if Range and LastRandom then 
			OnRange = type(LastRandom) == "number" and math.abs(Randomized - LastRandom) <= Range
			if type(LastRandom) == "table" then
				local RemovalCount = math.floor(#LastRandom * (_PreventOverflow / 5000))
				local Table = table.clone(LastRandom) --Avoids changes taking effect in the actual table
				for i = 1, RemovalCount do --Avoids hitting the stack overflow by slowly removing the oldest members in the table
					table.remove(Table, 1)
				end
				for i, v in Table do
					OnRange = math.abs(Randomized - v) <= Range; if OnRange then break end
				end 
			end
		end

		--If number is the same as last time, or inside a range we provided, repeat
		local OnRepeat = if LastRandom and (Randomized == LastRandom) or (Randomized ~= Randomized) then true else false

		--Checks
		if OnRepeat or OnRange then --If number is repeated, recursion
			return Internal(Min, Max, LastRandom, Range, _PreventOverflow + 1, _Random)
		else --If number is new, return it
			return Randomized
		end
	end
	return Internal(Min, Max, LastRandom, Range, 1, Random.new(os.time()))
end