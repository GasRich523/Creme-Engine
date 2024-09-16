--!strict

----- Services -----

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

----- Variables -----

local Code = workspace:WaitForChild("Code")
local Shared = Code:WaitForChild("Shared")
local Goodies = Shared:WaitForChild("Goodies")
local Resources = Shared:WaitForChild("Resources")

local Moveset = require(script.Parent)
local KeyBinder = require(Goodies.KeyBinder)
local TableUtil = require(Resources.RbxUtil.TableUtil)

----- State Machine -----

--- Method ---

return function(self: Moveset.InternalObject, Active: boolean): ()

	--[[
	Any behaviour edits to already existing moves or new ones should be
	done here (make sure you use Trove to handle your connections).
	--]]

	--Clenaup
	self.StateMachineTrove:Clean()

	if Active then
		assert(self.Humanoid)

		-- Jump Requested --

		local function JumpRequested(): ()
			if not self.JumpOnCooldown and self.Humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping) then
				self.JumpOnCooldown = true

				--LongJump
				if (self.Moves.Crouch.Active or (self.Moves.Roll.Active and not self.Moves.Roll.OnCooldown)) and self.Humanoid.MoveDirection.Magnitude > 0 then
					if self.Moves.Crouch.Active then
						self.Moves.Crouch.Toggle(self, false)
					elseif self.Moves.Roll.Active then
						self.Moves.Roll.Toggle(self, false)
					end
					self.Moves.LongJump.Toggle(self, true)

					--Backflip
				elseif self.Moves.Crouch.Active and self.Humanoid.MoveDirection.Magnitude == 0 then
					self.Moves.Crouch.Toggle(self, false)
					self.Moves.Backflip.Toggle(self, true)

					--Jump
				elseif not self.Moves.Glide.Active then
					if self.Humanoid.FloorMaterial ~= Enum.Material.Air then
						self.Moves.Stun.Toggle(self, false)
					end
					self.Moves.WallSlide.Toggle(self, false)
					self.Moves.LedgeGrab.Toggle(self, false)
					self.Moves.Glide.Toggle(self, false)
					self.Moves.LongJump.Toggle(self, false)
					self.Moves.Dive.Toggle(self, false)
					self.Moves.Jump.Toggle(self, true)
				end

				--Cooldown
				task.delay(0.2, function()
					self.JumpOnCooldown = false	
				end)
			end
		end
		self.StateMachineTrove:Add(UserInputService.JumpRequest:Connect(JumpRequested))

		-- Jump Hold Changed --

		local function JumpHoldChanged(): ()
			local JumpHoldState = self.Humanoid.Jump
			local JumpHoldPress = os.time()
			self.JumpHoldState = JumpHoldState
			self.JumpHoldPress = JumpHoldPress

			--Delay
			task.delay(0.2, function(): ()
				if self.JumpHoldPress == JumpHoldPress and self.JumpHoldState == JumpHoldState then

					--Glided
					if self.Moves.Jump.Count >= 1 and self.Humanoid:GetState() == Enum.HumanoidStateType.Freefall then
						self.Moves.Glide.Toggle(self, JumpHoldState)
					end
				end
			end)
		end
		self.StateMachineTrove:Add(self.Humanoid:GetPropertyChangedSignal("Jump"):Connect(JumpHoldChanged))

		-- State Changed --

		local function StateChanged(Old: Enum.HumanoidStateType, New: Enum.HumanoidStateType): ()

			--Falling
			if New == Enum.HumanoidStateType.Freefall then

				--Cancel Crouch
				self.Moves.Jump.Toggle(self, false, Enum.HumanoidStateType.Freefall)
				self.Moves.Crouch.Toggle(self, false)

				--Landed
			elseif New == Enum.HumanoidStateType.Landed and Old == Enum.HumanoidStateType.Freefall and self.Humanoid.FloorMaterial ~= Enum.Material.Air then

				--Dive Roll
				if self.Moves.Dive.Active then
					self.Moves.Dive.Toggle(self, false)
					self.Moves.Roll.Toggle(self, true, true)
				end
				self.Moves.Dive.OnCooldown = false

				--Cancel Moves
				self.Moves.Glide.Toggle(self, false)
				self.Moves.LongJump.Toggle(self, false)
				self.Moves.Backflip.Toggle(self, false)
				self.Moves.Jump.Toggle(self, false, Enum.HumanoidStateType.Landed)
				self.Moves.WallSlide.Toggle(self, false)

				--Climbing
			elseif New == Enum.HumanoidStateType.Climbing then

				--Cancel Moves
				self.Moves.Glide.Toggle(self, false)
				self.Moves.Jump.Toggle(self, false, Enum.HumanoidStateType.Landed) --Resets jump count

				--Swimming
			elseif New == Enum.HumanoidStateType.Swimming then

				--Cancel all moves (except jump)
				for Key, Move in pairs(self.Moves) do
					if typeof(Move) == "table" and Move.Toggle and Key ~= "Jump" then
						Move.Toggle(self, false)
					end
				end
			end	
		end
		self.StateMachineTrove:Add(self.Humanoid.StateChanged:Connect(StateChanged))

		-- Move --

		local function Move(ActionName: string, InputState: Enum.UserInputState): ()
			if ActionName == "Move" and InputState == Enum.UserInputState.Begin then

				--Air
				if self.Humanoid.FloorMaterial == Enum.Material.Air then
					self.Moves.Dive.Toggle(self, true)

				else --Ground

					--Moving
					if self.Humanoid.MoveDirection.Magnitude > 0 then

						--Roll
						if not self.Moves.Roll.OnCooldown then
							self.Moves.Crouch.Toggle(self, false)
							self.Moves.Roll.Toggle(self, true)
						end

					else --Idle

						--Crouch
						self.Moves.Crouch.Toggle(self, not self.Moves.Crouch.Active)
					end
				end
			end
		end
		KeyBinder:BindAction("Move", Move, true, self.Controls.Move.Desktop, self.Controls.Move.Console)
		KeyBinder:SetTitle("Move", "Move")
		self.StateMachineTrove:Add(function() --Unbinds on cleanup
			KeyBinder:UnbindAction("Move")
		end)

		-- Run --

		local function Run(dt: number): ()

			local Busy = not self.Humanoid or self.Humanoid:GetState() == Enum.HumanoidStateType.Ragdoll or self.Humanoid:GetState() == Enum.HumanoidStateType.Dead
			if self.Moves.Enabled and not Busy then

				--Update Attributes
				if not self.Moves.Stun.Active then
					self.Humanoid.WalkSpeed = not self.Moves.Crouch.Active and self.Moves.WalkSpeed or self.Moves.CrouchSpeed
				end

				--Update Collision
				local Head = self.Character and self.Character:FindFirstChild("Head") :: BasePart
				if self.Humanoid.RootPart and Head then
					self.Humanoid.RootPart.CanCollide = not ((self.Moves.Crouch.Active or self.Moves.Roll.Active or self.Moves.LedgeGrab.Active) and self.Humanoid:GetState() ~= Enum.HumanoidStateType.Ragdoll)
					Head.CanCollide = self.Humanoid.RootPart.CanCollide
				end
			elseif Busy and self.Humanoid.RootPart then --Prevents ragdoll breaking
				self.Humanoid.RootPart.CanCollide = false
			end
		end
		self.StateMachineTrove:Add(RunService.PostSimulation:Connect(Run))

		-- Touched --

		local function Touched(Hit: BasePart): ()
			if Hit == workspace.Terrain then return end --I have no clue how to tell if you touched water, so we ignore all terrain instead
			local BHS, BTS, BPS = self.Humanoid and self.Humanoid:FindFirstChild("BodyHeightScale") :: NumberValue, self.Humanoid and self.Humanoid:FindFirstChild("BodyTypeScale") :: NumberValue, self.Humanoid and self.Humanoid:FindFirstChild("BodyProportionScale") :: NumberValue --Yeah sorry I don't like this long line either
			local Height: number = BHS and BTS and BPS and BHS.Value * (4 + BTS.Value * (math.pi / 2 - 0.6 * BHS.Value)) + 1 or 1
			assert(self.Character, self.Humanoid, self.Humanoid.RootPart, Height)

			--Values
			local FloorFound = workspace:Raycast(self.Humanoid.RootPart.Position, Vector3.new(0, -Height, 0), self.PlayerParams)
			local WallFound = workspace:Raycast(self.Humanoid.RootPart.Position, self.Humanoid.RootPart.CFrame.LookVector * 2, self.PlayerParams)
			local CanStun = self.Moves.Roll.Active or self.Moves.Dive.Active or self.Moves.LongJump.Active

			--State
			local AirStun = CanStun and (not FloorFound) and self.Humanoid.FloorMaterial == Enum.Material.Air
			local GroundStun = CanStun and (FloorFound and Hit ~= FloorFound.Instance and WallFound)
			local Stunned = (GroundStun or AirStun) and Hit.CanCollide
			local WallSlided = not CanStun and not FloorFound and Hit.CanCollide and Hit.Transparency < 1 --We don't want players sliding on invisible walls, even if the filter isn't set up

			--Stunned
			if Stunned then
				self.Moves.Dive.Toggle(self, false)
				self.Moves.LongJump.Toggle(self, false)
				self.Moves.Roll.Toggle(self, false)
				self.Moves.WallSlide.Toggle(self, false)
				self.Moves.Stun.Toggle(self, true, self.Humanoid.FloorMaterial == Enum.Material.Air and Enum.HumanoidStateType.Freefall or Enum.HumanoidStateType.Landed)

				--Stun Cancelled
			elseif FloorFound and Hit ~= FloorFound.Instance and not self.Moves.Stun.OnCooldown then
				self.Moves.Stun.Toggle(self, false)

				--WallSlided
			elseif WallSlided then
				self.Moves.Glide.Toggle(self, false)
				self.Moves.LedgeGrab.Toggle(self, true)
				self.Moves.WallSlide.Toggle(self, true)
			end
		end
		self.StateMachineTrove:Add(self.Humanoid.Touched:Connect(Touched))

		-- Root Anchored --

		--Disables the moveset if the RootPart is anchored (comment out if you don't want this, but yeah, it acts as a shortcut for 90% of scripts in your game)
		assert(self.Humanoid.RootPart)
		local function RootAnchored(): ()
			self.Moves.Enabled = not self.Humanoid.RootPart.Anchored
		end
		self.StateMachineTrove:Add(self.Humanoid.RootPart.Changed:Connect(RootAnchored))

		-- Moveset Changed --

		local function MovesetChanged(Key: string, Value: any, OldValue: any, Table: {[any]: any}): ()

			--Moveset Disabled, Cancel all moves
			if Table == self.Moves and Key == "Enabled" and not Value then
				for _, Move in pairs(self.Moves) do
					if typeof(Move) == "table" and Move.Toggle and (not Move.IgnoreAnchorWhenActive or not Move.Active) then --Add this if your move anchors the character
						Move.Toggle(self, false)
					end
				end

				--Move/Effect Disabled, Cancel it
			elseif (table.find(TableUtil.Values(self.Moves), Table) or table.find(TableUtil.Values(self.Effects), Table)) and Key == "Enabled" and not Value then
				Table.Toggle(self, false)
			end
		end
		self.StateMachineTrove:Add(self.StateChanged:Connect(MovesetChanged))
	end
end
