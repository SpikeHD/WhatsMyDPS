local wmd = RegisterMod("Whats My Damage?", 1)

local screenSize
local totalDamage = 0
local frames = 0
local seconds = 0

function ToFixed(num, idp)
  return tonumber(string.format("%." .. (idp or 0) .. "f", num))
end

function wmd:Timer()
  if not Game():IsPaused() then
    -- The game runs at a locked 60fps, so we can calulate the time based on the number of frames that have passed
    frames = frames + 1

    -- Reset the timer every second
    if frames % 60 == 0 then
      seconds = seconds + 1
      frames = 0
    end
  end
end

function wmd:Reset()
  frames = 0
  seconds = 0
  totalDamage = 0
end

function wmd:OnDamageHit(target, amount, source, _dealer) 
  if source == 0 and -- If the player caused the damage
    target:IsActiveEnemy() and -- If the target entity is an enemy NPC
    not target:IsInvincible() then
    totalDamage = ToFixed(totalDamage + amount, 2)
  end
end

-- Get the number to subtract from the G and B values (255 max), base on damage passed in
function GetColorSubtraction(damage)
  -- Damage range is from 10 to 100, so we need to scale that to the 0 - 255 range
  local damageRange = 100 - 10
  local colorRange = 255
  local damageRatio = damage / damageRange
  local colorSubtraction = colorRange * damageRatio

  return colorSubtraction
end

-- Get actual DPS
function CalculateDPS()
  if seconds == 0 or totalDamage == 0 then
    return 0
  end

  return ToFixed(totalDamage / seconds, 2)
end

-- This function calculates the players "functional" DPS based on their Damage and Fire Rate stat. This does NOT account for things like poison, bomb damage, etc.
function FunctionalDPS()
  local firedelay = Isaac.GetPlayer(0).MaxFireDelay
  local damage = Isaac.GetPlayer(0).Damage

  return ToFixed(damage * (5 / firedelay), 2)
end

function wmd:Render()
  if screenSize == nil then
    screenSize = (Isaac.WorldToScreen(Vector(320, 280)) - Game():GetRoom():GetRenderScrollOffset() - Game().ScreenShakeOffset) * 2
  end

  local dps = CalculateDPS()
  local functionalDPS = FunctionalDPS()
  local dpsColorSub = GetColorSubtraction(dps)
  local fDPSColorSub = GetColorSubtraction(functionalDPS)

  -- Draw to the bottom left of the screen (based on screen size)
  Isaac.RenderText("Total Damage: " .. totalDamage, 10, screenSize.Y - 60, 255, 255, 255, 255)
  Isaac.RenderText("Functional DPS: " .. functionalDPS, 10, screenSize.Y - 40, 255, 255 - fDPSColorSub, 255 - fDPSColorSub, 255)
  Isaac.RenderText("DPS: " .. dps, 10, screenSize.Y - 20, 255, 255 - dpsColorSub, 255 - dpsColorSub, 255)

  -- Also (for debugging) print the DPS
  print("DPS: " .. dps)
  print("Functional DPS: " .. functionalDPS)
  print("Total Damage: " .. totalDamage)
end

wmd:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, wmd.OnDamageHit)
wmd:AddCallback(ModCallbacks.MC_POST_RENDER, wmd.Render)
wmd:AddCallback(ModCallbacks.MC_POST_RENDER, wmd.Timer)
wmd:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, wmd.Reset)
wmd:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, wmd.Reset)