--!strict

--[[

Game's database, all player data will be handled here.

-- Example of Usage --

--Require
local Database = require(Server.Database)

--[...]

--Changed
Database.DataChanged:Connect(function(Plr: Player, Table: {[any]: any}, Key: any, Value: any, OldValue: any)
	if Plr == Player and Table == Data.Pickables then
		print("Collected: "..tostring(Value).." "..Key.." ,had "..tostring(OldValue)) --Example: Collected 10 Bucks, had 5.
	end
end)

--Loaded
if Database:HasLoaded(Player) then
	local Data: Database.Data = Database:GetData(Player)
	Init(Data)
else
	Database.DataLoaded:Connect(function(Plr: Player, Data: Database.Data)
		if Plr == Player then
			Init(Data)
		end
	end)
end

-- Can I use this from the client? --

No and you shouldn't, use remotes with commands as done with collectibles.

--]]

----- Services -----

local Code = workspace:WaitForChild("Code")
local Shared = Code:WaitForChild("Shared")
local Resources = Shared:WaitForChild("Resources")

local Signal = require(Resources.RbxUtil.Signal)

----- Module -----

local Database = {}

--- Types ---

-- ProfileService --

--[[
I hate the fact ProfileService isn't strict typed, so here's some fake and probs
inaccurate typing for personal use.
--]]

--Profile
export type Profile = {
	Data: Data,
	MetaData: {
		ProfileCreateTime: number,
		SessionLoadCount: number,
		ActiveSession: {place_id: number?, game_job_id: number?}?,
		MetaTags: {[string]: any},
		MetaTagsLatest: {[any]: any}
	},
	MetaTagsUpdated: RBXScriptSignal,
	RobloxMetaData: {[any]: any},
	UserIds: {number},
	KeyInfo: DataStoreKeyInfo,
	KeyInfoUpdated: RBXScriptSignal,
	GlobalUpdates: any,
	IsActive: (self: {[any]: any}?) -> boolean,
	Reconcile: (self: {[any]: any}?) -> (),
	ListenToRelease: (self: {[any]: any}?, Listener: (...any) -> (...any)) -> RBXScriptConnection,
	Release: (self: {[any]: any}?) -> (),
	ListenToHopReady: (self: {[any]: any}?, Listener: (...any) -> (...any)) -> RBXScriptConnection,
	AddUserId: (self: {[any]: any}?, UserId: number) -> (),
	RemoveUserId: (self: {[any]: any}?, UserId: number) -> (),
	Identify: (self: {[any]: any}?, String: string) -> {[any]: any},
	SetMetaTag: (self: {[any]: any}?, tag_name: string, value: any) -> (),
	Save: (self: {[any]: any}?) -> (),
	ClearGlobalUpdates: (self: {[any]: any}?) -> (),
	OverwriteAsync: (self: {[any]: any}?) -> (),
	[any]: any
}

--Profiles
export type Profiles = {
	[Player]: Profile
}

--ProfileStore
export type ProfileStore = {
	LoadProfileAsync: (self: {[any]: any}, ProfileKey: string, Handler: ("ForceLoad" | "Steal" | (PlaceId: number?, GameJobId: string?) -> ("Repeat", "Cancel", "ForceLoad" | "Steal"))?) -> Profile?,
	GlobalUpdateProfileAsync: (self: {[any]: any}, ProfileKey: string, () -> ()) -> any?,
	ViewProfileAsync: (self: {[any]: any}, ProfileKey: string, Version: string) -> Profile?,
	ProfileVersionQuery: (self: {[any]: any}, ProfileKey: string, SortDir: Enum.SortDirection?, MinDate: DateTime? | number?, MaxDate: DateTime? | number?) -> any,
	WipeProfileAsync: (self: {[any]: any}, ProfileKey: string) -> boolean,
	Mock: ProfileStore
}

-- Base Collectibles --

export type Secondary = {Obtained: boolean}
export type Currency = Secondary & {ObtainDate: number?}
export type Main = Secondary & {Title: string?, Description: string?}

-- Collectibles --

--Brews
export type Brews = {
	Brew1: Main,
	Brew2: Main,
	Brew3: Main,
	Brew4: Main,
	Brew5: Main,
	Brew6: Main,
	Brew7: Main,
	Brew8: Main,
	Brew9: Main,
	Brew10: Main,
	Brew11: Main,
	Brew12: Main
}

--Crusts
export type Crusts = {
	Crust1: Secondary,
	Crust2: Secondary,
	Crust3: Secondary,
	Crust4: Secondary,
	Crust5: Secondary,
	Crust6: Secondary,
	Crust7: Secondary,
	Crust8: Secondary,
	Crust9: Secondary,
	Crust10: Secondary,
	Crust11: Secondary,
	Crust12: Secondary,
	Crust13: Secondary,
	Crust14: Secondary,
	Crust15: Secondary,
	Crust16: Secondary,
	Crust17: Secondary,
	Crust18: Secondary,
	Crust19: Secondary,
	Crust20: Secondary,
	Crust21: Secondary,
	Crust22: Secondary,
	Crust23: Secondary,
	Crust24: Secondary
}

--Bucks
export type Bucks = {
	[string?]: Currency
}

-- Database --

--PlaceNames
export type PlaceNames = "TestPlace" --| "Level1" | "Level2" --Etc...

--Places
export type Places = {
	[PlaceNames]: number
}

--Collectibles
export type Collectibles = {
	Brews: Brews,
	Crusts: Crusts,
	Bucks: Bucks
}

--Data
export type Data = {
	Places: Places,
	Collectibles: {
		[PlaceNames]: Collectibles
	},
	Progression: {
		[PlaceNames]: {
			Events: {},
			Quests: {},
			Example: boolean
		}
	},
	BucksCount: number,
	BucksCooldown: number
}

--- Signals ---

Database.DataLoaded = Signal.new() :: Signal.Signal<Player, Data>
Database.DataChanged = Signal.new() :: Signal.Signal<{[any]: any}, string, any, any>

--- Generic Values ---

local Crusts = {
	Crust1 = {Obtained = false, ObtainDate = nil},
	Crust2 = {Obtained = false, ObtainDate = nil},
	Crust3 = {Obtained = false, ObtainDate = nil},
	Crust4 = {Obtained = false, ObtainDate = nil},
	Crust5 = {Obtained = false, ObtainDate = nil},
	Crust6 = {Obtained = false, ObtainDate = nil},
	Crust7 = {Obtained = false, ObtainDate = nil},
	Crust8 = {Obtained = false, ObtainDate = nil},
	Crust9 = {Obtained = false, ObtainDate = nil},
	Crust10 = {Obtained = false, ObtainDate = nil},
	Crust11 = {Obtained = false, ObtainDate = nil},
	Crust12 = {Obtained = false, ObtainDate = nil},
	Crust13 = {Obtained = false, ObtainDate = nil},
	Crust14 = {Obtained = false, ObtainDate = nil},
	Crust15 = {Obtained = false, ObtainDate = nil},
	Crust16 = {Obtained = false, ObtainDate = nil},
	Crust17 = {Obtained = false, ObtainDate = nil},
	Crust18 = {Obtained = false, ObtainDate = nil},
	Crust19 = {Obtained = false, ObtainDate = nil},
	Crust20 = {Obtained = false, ObtainDate = nil},
	Crust21 = {Obtained = false, ObtainDate = nil},
	Crust22 = {Obtained = false, ObtainDate = nil},
	Crust23 = {Obtained = false, ObtainDate = nil},
	Crust24 = {Obtained = false, ObtainDate = nil}
} :: Crusts

--- Values ---

Database.Name = "GameData" :: string
Database.ProfileName = "Player_" :: string
Database.SaveOnPlaytests = false :: boolean
Database.ProfileStore = nil :: ProfileStore?
Database.Profiles = {} :: Profiles
Database.Template = {

	--Places
	Places = {
		TestPlace = 18927506428
	},

	--Collectibles
	Collectibles = {
		TestPlace = {
			Brews = {
				Brew1 = {Title = "Test #1", Description = "aaaaahh... wire!", Obtained = false},
				Brew2 = {Title = "Test #2", Description = "bottom text", Obtained = false},
				Brew3 = {Title = nil, Description = nil, Obtained = false},
				Brew4 = {Title = nil, Description = nil, Obtained = false},
				Brew5 = {Title = nil, Description = nil, Obtained = false},
				Brew6 = {Title = nil, Description = nil, Obtained = false},
				Brew7 = {Title = nil, Description = nil, Obtained = false},
				Brew8 = {Title = nil, Description = nil, Obtained = false},
				Brew9 = {Title = nil, Description = nil, Obtained = false},
				Brew10 = {Title = nil, Description = nil, Obtained = false},
				Brew11 = {Title = nil, Description = nil, Obtained = false},
				Brew12 = {Title = nil, Description = nil, Obtained = false}
			} :: Brews,
			Crusts = Crusts,
			Bucks = {} :: Bucks
		}
	},

	--Progression
	Progression = {
		TestPlace = {
			Events = {},
			Quests = {},
			Example = false
		}
	},

	--General
	BucksCount = 0,
	BucksCooldown = 43200,

} :: Data

--- Methods ---

-- Get Profile --

function Database:GetProfile(Player: Player): Profile?
	local Profile: Profile? = Database.Profiles[Player]
	if Profile then
		return Profile
	end
	return nil
end

-- Get ProfileStore --

function Database:GetProfileStore(): ProfileStore?
	local ProfileStore: ProfileStore? = Database.ProfileStore
	if ProfileStore then
		return ProfileStore
	end
	return nil
end

-- Get Data --

function Database:GetData(Player: Player): Data?
	local Profile: Profile? = Database:GetProfile(Player)
	local Data: Data? = Profile and Profile.Data
	if Data then
		return Data
	end
	return nil
end

-- Has Loaded --

function Database:HasLoaded(Player: Player): boolean
	local IsLoaded: boolean = if Database:GetProfile(Player) then true else false
	return IsLoaded
end

return Database