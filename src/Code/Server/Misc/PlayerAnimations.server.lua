--!strict

--[[
Overrides player's R15/R6 animations.
--]]

----- Services -----

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

----- Code -----

--- PlayerAdded ---

local function PlayerAdded(Player: Player)
	task.spawn(function()

		local UserId: number = Player.UserId
		local PlayerInfo: any = Players:GetCharacterAppearanceInfoAsync(UserId)
		local Connection: RBXScriptConnection? = nil
		local Connection2: RBXScriptConnection? = nil
		local StrafeAnim: AnimationTrack? = nil
		
		-- CharacterAdded --

		local function CharacterAdded(Character: Model)
			
			--Wait for character to be parented
			if not Character:IsDescendantOf(game) then
				Character.AncestryChanged:Wait()
			end

			--Get Description
			local Humanoid: Humanoid? = Character:WaitForChild("Humanoid", 5) :: Humanoid
			local Animator: Animator? = Humanoid and Humanoid:WaitForChild("Animator", 5) :: Animator
			local DefaultHumanoidDescription: HumanoidDescription? = Humanoid and Humanoid:WaitForChild("HumanoidDescription", 5) :: HumanoidDescription
			local HumanoidDescription: HumanoidDescription? = DefaultHumanoidDescription and DefaultHumanoidDescription:Clone()
			if Humanoid and HumanoidDescription then

				--Override Animations
				if PlayerInfo and PlayerInfo.playerAvatarType == "R6" then --R6
					HumanoidDescription.ClimbAnimation = 18841256584
					HumanoidDescription.FallAnimation = 18841214544
					HumanoidDescription.IdleAnimation = 18841250703
					HumanoidDescription.JumpAnimation = 18841220027
					HumanoidDescription.RunAnimation = 18841196544
					HumanoidDescription.SwimAnimation = 18841233520
					HumanoidDescription.WalkAnimation = 18841206101
				else --R15
					HumanoidDescription.ClimbAnimation = 18841070988
					HumanoidDescription.FallAnimation = 18841060863
					HumanoidDescription.IdleAnimation = 18841050975
					HumanoidDescription.JumpAnimation = 18841054819
					HumanoidDescription.RunAnimation = 18841038331
					HumanoidDescription.SwimAnimation = 18841079328
					HumanoidDescription.WalkAnimation = 18841066911
				end			
					
				--Landed Connection
				local OnCooldown = false
				Connection = Humanoid.StateChanged:Connect(function(Old: Enum.HumanoidStateType, New: Enum.HumanoidStateType): ()
					if (New == Enum.HumanoidStateType.Landed or (Old == Enum.HumanoidStateType.Freefall and New == Enum.HumanoidStateType.Running)) and Animator then
						OnCooldown = true

						local Anim: AnimationTrack?
						if PlayerInfo.playerAvatarType == "R6" then
							Anim = Animator:LoadAnimation(script.R6Land)
						else
							Anim = Animator:LoadAnimation(script.R15Land)
						end
						if Anim then
							Anim.Ended:Once(function()
								OnCooldown = false
								Anim:Destroy()
							end)
							Anim:Play(nil, 0.5)
						else
							OnCooldown = false
						end
					end
				end)

				--Reload Description
				Humanoid:ApplyDescription(HumanoidDescription)

				--Refresh Animations
				Humanoid:ChangeState(Enum.HumanoidStateType.Landed)
			end
		end
		Player.CharacterAdded:Connect(CharacterAdded)
		if Player.Character then
			CharacterAdded(Player.Character)
		end
		
		--Cleanup Connections
		Player.CharacterRemoving:Once(function()
			if Connection then Connection:Disconnect() end
			if Connection2 then Connection2:Disconnect() end
			if StrafeAnim then StrafeAnim:Stop(); StrafeAnim:Destroy() end
		end)
	end)
end
Players.PlayerAdded:Connect(PlayerAdded)
for _, Player: Player in Players:GetPlayers() do
	PlayerAdded(Player)
end