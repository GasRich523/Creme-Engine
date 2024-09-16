--!strict

----- Variables -----

local Misc = workspace:WaitForChild("Misc")
local Floaties = Misc:WaitForChild("Floaties")

----- Code -----

--Wait for game to load
if not game:IsLoaded() then
	game.Loaded:Wait()
end

--Set NetworkOwner to Client
local function SetNetworkOwner(ServerPart: BasePart): ()
	
	--[[
	Roblox is so inconsistent and garbage with how they handle replication
	that they will sometimes delete a cloned part by no reason, so I have
	to clone it manually, and it still deletes it sometimes anyways...
	--]]
	
	task.delay(1, function()
		if not ServerPart:IsDescendantOf(game) then
			ServerPart.AncestryChanged:Wait()
		end
		local ClientPart = Instance.fromExisting(ServerPart)
		ClientPart.Parent = Floaties
		ClientPart.CFrame = ServerPart.CFrame
		ClientPart.Destroying:Connect(function()
			SetNetworkOwner(ClientPart)
		end)
		ServerPart:Destroy()
	end)
end

--Setup
for _, Floatie in Floaties:GetChildren() do
	if Floatie:IsA("BasePart") then
		task.spawn(SetNetworkOwner, Floatie)
	end
end