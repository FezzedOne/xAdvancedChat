require "/interface/scripted/starcustomchat/plugin.lua"

proximitychat = PluginClass:new(
  { name = "proximitychat" }
)

function proximitychat:init()
  self:_loadConfig()
  self.proximityRadius = root.getConfiguration("icc_proximity_radius") or self.proximityRadius
end

function planetTime()
  local n = world.timeOfDay()
  local t = n * 24 * 3600
  local hours = t / 3600
  local minutes = (t / 60) % 60
  return (hours + 6) % 24, minutes
end

function printTime()
  hour, minute = planetTime()
	hour = string.format("%02d", math.floor(hour))
	minute = string.format("%02d", math.floor(minute))
  
  return hour..":"..minute
end

function proximitychat:onSendMessage(data)
  if data.mode == "Proximity" then
    data.time = printTime()
    data.proximityRadius = self.proximityRadius
    
    if self.stagehandType and self.stagehandType ~= "" then
      starcustomchat.utils.sendMessageToStagehand(self.stagehandType, "icc_sendMessage", data)
    else
      
      local function sendMessageToPlayers()
        local position = player.id() and world.entityPosition(player.id())
        if position then
          local players = world.playerQuery(position, data.proximityRadius)
          for _, pl in ipairs(players) do 
            world.sendEntityMessage(pl, "icc_sendToUser", data)
          end
          return true
        end
      end

      local sendMessagePromise = {
        finished = sendMessageToPlayers,
        succeeded = function() return true end
      }

      promises:add(sendMessagePromise)
    end

    player.say(data.text)
  end
end

function proximitychat:formatIncomingMessage(message)
  if message.mode == "Proximity" then
    message.portrait = message.portrait and message.portrait ~= "" and message.portrait or message.connection
  end
  return message
end

function proximitychat:onReceiveMessage(message)
  if message.connection ~= 0 and message.mode == "Proximity" then
    sb.logInfo("Chat: <%s> %s", message.nickname, message.text)
  end
end

function proximitychat:onSettingsUpdate(data)
  self.proximityRadius = root.getConfiguration("icc_proximity_radius") or self.proximityRadius
end

function clamp(value, min, max)
  return math.max(math.min(value, max), min)
end

function proximitychat:onCursorOverride(screenPosition)
  local id = findButtonByMode("Proximity")
  if widget.inMember("rgChatMode." .. id, screenPosition) and player.id() and world.entityPosition(player.id()) then
    drawCircle(world.entityPosition(player.id()), self.proximityRadius, {255, 0, 0, 255}, clamp(math.floor(self.proximityRadius * 2.0), 10, 50))
  end
end

function worldToScreen(coord)
  local camera = vec2.mul(vec2.sub(coord, interface.cameraPosition()), 8.0 * interface.worldPixelRatio())
  local windowCentre = vec2.mul(interface.windowSize(), 0.5)
  local x, y = table.unpack(vec2.add(windowCentre, camera))
  return {math.floor(x + 0.5), math.floor(y + 0.5)}
end

function adjustCoords(coord1, coord2)
  local adjCoord1 = vec2.mul(coord1, 8.0 * interface.worldPixelRatio())
  local adjCoord2 = vec2.mul(coord2, 8.0 * interface.worldPixelRatio())
  return {adjCoord1, adjCoord2}
end

function drawCircle(center, radius, color, sections)
  sections = sections or 20
  for i = 1, sections do
    local startAngle = math.pi * 2 / sections * (i-1)
    local endAngle = math.pi * 2 / sections * i
    local startLine = vec2.add(center, {radius * math.cos(startAngle), radius * math.sin(startAngle)})
    local endLine = vec2.add(center, {radius * math.cos(endAngle), radius * math.sin(endAngle)})
    local lineCentre = {(startLine[1] + endLine[1]) * 0.5, (startLine[2] + endLine[2]) * 0.5}
    local adjStartLine, adjEndLine = vec2.sub(lineCentre, startLine), vec2.sub(lineCentre, endLine)
    interface.drawDrawable({
      line = adjustCoords(adjStartLine, adjEndLine),
      width = 1,
      color = color
    }, worldToScreen(lineCentre), 1)
  end
end


-- Settings
function proximitychat:settings_init(localeConfig)
  self:_loadConfig()
  self.proximityRadius = root.getConfiguration("icc_proximity_radius") or self.proximityRadius
  widget.setSliderRange("sldProxRadius", 0, 90, 1)
  widget.setSliderValue("sldProxRadius", self.proximityRadius - 10)
  widget.setText("lblProxRadiusValue", self.proximityRadius)
  widget.setText("lblProxRadiusHint", localeConfig["settings.prox_radius"])
end

function proximitychat:settings_onCursorOverride(screenPosition)
  if widget.inMember("sldProxRadius", screenPosition) 
    or widget.inMember("lblProxRadiusValue", screenPosition) 
    or widget.inMember("lblProxRadiusHint", screenPosition) then
    
    if player.id() and world.entityPosition(player.id()) then
      drawCircle(world.entityPosition(player.id()), self.proximityRadius, "green")
    end
  end
end

function updateProxRadius(widgetName)
  local newRadius = widget.getSliderValue(widgetName) + 10
  widget.setText("lblProxRadiusValue", newRadius)
  root.setConfiguration("icc_proximity_radius", newRadius)
  save()
end

function proximitychat:settings_onSave(localeConfig)
  widget.setText("lblProxRadiusHint", localeConfig["settings.prox_radius"])
  self.proximityRadius = root.getConfiguration("icc_proximity_radius") or 100
end