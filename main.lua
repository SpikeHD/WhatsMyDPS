local wmd = RegisterMod("Whats My DPS?", 1)

local screenSize
local totalDamage = 0
local frames = 0
local seconds = 0

local settings = {
  showDPSAboveIsaac = true,
  showDPSInStats = true,
  showAdditionalStats = true,
  hudOpacity = 0.4
}

local function setupMenuSettings()
  if ModConfigMenu == nil then
    return
  end

  -- Config options:
  -- "Show DPS Above Isaac"
  -- "Show DPS in stats side area"
  -- "Show additional stats in bottom left"
  ModConfigMenu.AddSetting(
    "What's My DPS?",
    nil,
    {
      Type = ModConfigMenu.OptionType.BOOLEAN,
      CurrentSetting = function()
        return settings.showDPSAboveIsaac
      end,
      Display = function()
        return "Show DPS Above Isaac: " .. (settings.showDPSAboveIsaac and "on" or "off")
      end,
      OnChange = function(currentBool)
        settings.showDPSAboveIsaac = currentBool
        SaveSettings()
      end,
      Info = nil
    }
  )

  ModConfigMenu.AddSetting(
    "What's My DPS?",
    nil,
    {
      Type = ModConfigMenu.OptionType.BOOLEAN,
      CurrentSetting = function()
        return settings.showDPSInStats
      end,
      Display = function()
        return "Show DPS in stats side area: " .. (settings.showDPSInStats and "on" or "off")
      end,
      OnChange = function(currentBool)
        settings.showDPSInStats = currentBool
        SaveSettings()
      end,
      Info = nil
    }
  )

  ModConfigMenu.AddSetting(
    "What's My DPS?",
    nil,
    {
      Type = ModConfigMenu.OptionType.BOOLEAN,
      CurrentSetting = function()
        return settings.showAdditionalStats
      end,
      Display = function()
        return "Show additional stats in bottom left: " .. (settings.showAdditionalStats and "on" or "off")
      end,
      OnChange = function(currentBool)
        settings.showAdditionalStats = currentBool
        SaveSettings()
      end,
      Info = nil
    }
  )
end

function LoadSettings()
  local str = Isaac.LoadModData(wmd)

  if str == nil then
    str = "111" -- All on by default
  end

  settings.showDPSAboveIsaac = str:sub(1, 1) == "1"
  settings.showDPSInStats = str:sub(2, 2) == "1"
  settings.showAdditionalStats = str:sub(3, 3) == "1"
end

function SaveSettings()
  local str = ""

  str = str .. (settings.showDPSAboveIsaac and "1" or "0")
  str = str .. (settings.showDPSInStats and "1" or "0")
  str = str .. (settings.showAdditionalStats and "1" or "0")

  Isaac.SaveModData(wmd, str)
end

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
  if (
      source == 0 or
      -- This accounts for things like brimstone, which is... you guessed it, a laser
      -- This will also count other lasers that do not come from Isaac, but we will just have to live with it
      source == DamageFlag.DAMAGE_LASER
    ) and -- If the player caused the damage
    target:IsActiveEnemy() and -- If the target entity is an enemy NPC
    not target:IsInvincible() then
    totalDamage = ToFixed(totalDamage + amount, 2)
  end
end

-- Get the number to subtract from the G and B values (1 is the max, the range is 0 - 1)
function GetColorSubtraction(damage)
  -- Scale a damage range of 10 - 100 to a color range of 0 - 1
  local colorSub = (damage - 10) / 90

  -- If the damage is less than 10, just return 0
  if colorSub < 0 then
    return 0
  end

  return colorSub
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
  -- This is not the fire rate, but rather the delay in between each shot. The lower the number, the faster the fire rate
  local firedelay = 30 / (Isaac.GetPlayer(0).MaxFireDelay + 1)
  local damage = Isaac.GetPlayer(0).Damage

  return ToFixed(damage * firedelay, 2)
end

function wmd:Render()
  if screenSize == nil then
    screenSize = (Isaac.WorldToScreen(Vector(320, 280)) - Game():GetRoom():GetRenderScrollOffset() - Game().ScreenShakeOffset) * 2
  end

  local dps = CalculateDPS()
  local functionalDPS = FunctionalDPS()
  local dpsColorSub = GetColorSubtraction(dps)
  local fDPSColorSub = GetColorSubtraction(functionalDPS)

  -- Create smaller font
  local font = Font()
  font:Load("font/pftempestasevencondensed.fnt")

  -- Draw to the top left of the screen (based on screen size)
  if settings.showAdditionalStats then
    font:DrawStringScaled("Total Damage: " .. totalDamage, 26, screenSize.Y - 20, 0.8, 0.8, KColor(1, 1, 1, settings.hudOpacity))
    font:DrawStringScaled("Functional DPS: " .. functionalDPS, 26,  screenSize.Y - 30, 0.8, 0.8, KColor(1, 1 - fDPSColorSub, 1 - fDPSColorSub, settings.hudOpacity))
  end

  -- Draw the DPS on top of isaac's head
  local p = Isaac.GetPlayer(0).Position
  local room = Game():GetRoom()
  local px = room:WorldToScreenPosition(p).X
  local py = room:WorldToScreenPosition(p).Y

  if settings.showDPSAboveIsaac then
    -- px - 10 is stupid idk why I need to do that
    font:DrawString(tostring(dps), px - 10, py - 40, KColor(1, 1 - dpsColorSub, 1 - dpsColorSub, settings.hudOpacity), 20, true)
  end

  if settings.showDPSInStats then
    -- Draw the DPS in the stats side area
    local miniCoords = Vector(26, 214)
    font:DrawStringScaled("DPS: " .. tostring(dps), miniCoords.X, miniCoords.Y, 0.8, 0.8, KColor(1, 1 - dpsColorSub, 1 - dpsColorSub, settings.hudOpacity))
  end
end

wmd:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, wmd.OnDamageHit)
wmd:AddCallback(ModCallbacks.MC_POST_RENDER, wmd.Render)
wmd:AddCallback(ModCallbacks.MC_POST_RENDER, wmd.Timer)
wmd:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, wmd.Reset)
wmd:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, wmd.Reset)

LoadSettings()
setupMenuSettings()