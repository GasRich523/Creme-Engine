--!strict
local MusicZones = require(script.Parent)
MusicZones:Toggle(true)

--StateChanged
MusicZones.StateChanged:Connect(function(State: MusicZones.States)
	print("StateChanged: "..State)
end)

--PlaylistChanged
MusicZones.PlaylistChanged:Connect(function(Playlist: MusicZones.Playlist)
	print("PlaylistChanged: "..Playlist.Container.Name)
end)

--SoundChanged
MusicZones.SoundChanged:Connect(function(Sound: Sound)
	print("SoundChanged: "..Sound.Name)
end)