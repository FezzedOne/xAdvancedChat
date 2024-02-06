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
  ---@param s string
  ---@return string
  local function stripWhitespace(s)
    s = s:gsub("[%s]+", " ") -- Trim whitespace.
    s = s:gsub("^ ", "") -- Trim initial whitespace.
    s = s:gsub(" $", "") -- Trim trailing whitespace.
    return s
  end

  ---@param msg {text: string, mode: string}
  ---@return {text: string}
  ---@return {text: string}
  ---@return {text: string}
  local function splitMessage(msg)
    local firstMsg = {
      text = "",
      connection = msg.connection,
      portrait = msg.portrait,
      mode = msg.mode,
      nickname = msg.nickname
    }
    local secondMsg = {text = ""}
    local thirdMsg = {text = ""}
    ---@type string[]
    local secondParts, thirdParts = {}, {}
    local msgText = msg.text
    msgText = msgText:gsub("\\|", "¦") -- Handle escaped pipes.
    msgText = msgText:gsub("@%(%(%((.-)%)%)%)", function(globalOocPart) -- Handle "@(((message)))".
      globalOocPart = globalOocPart:gsub("¦", "|")
      table.insert(thirdParts, "(( " .. globalOocPart .. " ))")
      return " "
    end)
    msgText = msgText:gsub("@%[%[%[(.-)]]]", function(globalOocPart) -- Handle "@[[[message]]]".
      globalOocPart = globalOocPart:gsub("¦", "|")
      table.insert(thirdParts, "[[ " .. globalOocPart .. " ]]")
      return " "
    end)
    msgText = msgText:gsub("@<<<(.-)>>>", function(globalRollPart) -- Handle "@<<<message>>>".
      globalRollPart = globalRollPart:gsub("¦", "|")
      table.insert(thirdParts, "<< " .. globalRollPart .. " >>")
      return " "
    end)
    msgText = msgText:gsub("@|(.-)|", function(globalIcPart) -- Handle "@|message|".
      globalIcPart = globalIcPart:gsub("¦", "|")
      table.insert(thirdParts, globalIcPart)
      return " "
    end)
    msgText = msgText:gsub("%(%(%((.-)%)%)%)", function(localOocPart) -- Handle "(((message)))".
      localOocPart = localOocPart:gsub("¦", "|")
      table.insert(secondParts, "(( " .. localOocPart .. " ))")
      return " "
    end)
    msgText = msgText:gsub("%[%[%[(.-)]]]", function(localOocPart) -- Handle "[[[message]]]".
      localOocPart = localOocPart:gsub("¦", "|")
      table.insert(secondParts, "[[ " .. localOocPart .. " ]]")
      return " "
    end)
    msgText = msgText:gsub("<<<(.-)>>>", function(localRollPart) -- Handle "<<<message>>>".
      localRollPart = localRollPart:gsub("¦", "|")
      table.insert(secondParts, "<< " .. localRollPart .. " >>")
      return " "
    end)
    msgText = msgText:gsub("|(.-)|", function(localIcPart) -- Handle "|message|".
      localIcPart = localIcPart:gsub("¦", "|")
      table.insert(secondParts, localIcPart)
      return " "
    end)
    -- Compose the messages.
    msgText = stripWhitespace(msgText)
    firstMsg.text = msgText
    for _, part in ipairs(secondParts) do
      secondMsg.text = secondMsg.text .. " " .. part
    end
    secondMsg.text = stripWhitespace(secondMsg.text)
    for _, part in ipairs(thirdParts) do
      thirdMsg.text = thirdMsg.text .. " " .. part
    end
    thirdMsg.text = stripWhitespace(thirdMsg.text)
    return firstMsg, secondMsg, thirdMsg
  end

  ---@param msg table
  local function sendProximityMessage(msg)
    msg.time = printTime()
    msg.proximityRadius = self.proximityRadius

    -- Degranon: Update to allow a client to spawn a custom stagehand for proximity messages.
    if self.uniqueStagehandType and self.uniqueStagehandType ~= "" then
      starcustomchat.utils.sendMessageToStagehand(self.uniqueStagehandType, "icc_sendMessage", msg)
    elseif self.stagehandType and self.stagehandType ~= "" then
      starcustomchat.utils.createStagehandWithData(self.stagehandType, {message = "sendProxyMessage", data = msg})
    else
      
      local function sendMessageToPlayers()
        local position = player.id() and world.entityPosition(player.id())
        if position then
          local players = world.playerQuery(position, msg.proximityRadius)
          for _, pl in ipairs(players) do 
            world.sendEntityMessage(pl, "icc_sendToUser", msg)
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
  end

  if data.mode == "Proximity" then
    local chatBubbleText = stripWhitespace(data.text)
    if chatBubbleText ~= "" then
      player.say(chatBubbleText)
    end

    local proxMsg, localMsg, globalMsg = splitMessage(data)
    if proxMsg.text ~= "" then
      sendProximityMessage(proxMsg)
    end
    if localMsg.text ~= "" then
      chat.send(localMsg.text, "Local")
    end
    if globalMsg.text ~= "" then
      chat.send(globalMsg.text, "Broadcast")
    end
  else
  end
end

function proximitychat:formatIncomingMessage(message)
  if message.mode == "Proximity" then
    message.portrait = (message.portrait and message.portrait ~= "") and message.portrait or message.connection
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
      drawCircle(world.entityPosition(player.id()), self.proximityRadius, {255, 0, 0, 255}, clamp(math.floor(self.proximityRadius * 2.0), 10, 50))
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