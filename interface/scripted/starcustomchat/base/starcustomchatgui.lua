require "/scripts/messageutil.lua"
require "/scripts/icctimer.lua"
require "/scripts/util.lua"
require "/scripts/rect.lua"
require "/interface/scripted/starcustomchat/base/chat_class.lua"
require "/interface/scripted/starcustomchat/base/starcustomchatutils.lua"
require "/interface/scripted/starcustomchat/chatbuilder.lua"
require("/scripts/starextensions/lib/chat_callback.lua")

local shared = getmetatable('').shared
if type(shared) ~= "table" then
  shared = {}
  getmetatable('').shared = shared
end

local handlerCutter = nil

ICChatTimer = TimerKeeper.new()
function init()
  shared.chatIsOpen = true
  self.canvasName = "cnvChatCanvas"
  self.highlightCanvasName = "cnvHighlightCanvas"
  self.commandPreviewCanvasName = "lytCommandPreview.cnvCommandsCanvas"
  self.chatWindowWidth = widget.getSize("backgroundImage")[1]

  self.availableCommands = root.assetJson("/interface/scripted/starcustomchat/base/commands.config")

  local chatConfig = root.assetJson("/interface/scripted/starcustomchat/base/chat.config")

  local plugins = {}
  self.localePluginConfig = {}

  -- Load plugins
  for i, pluginName in ipairs(config.getParameter("enabledPlugins", {})) do 
    local pluginConfig = root.assetJson(string.format("/interface/scripted/starcustomchat/plugins/%s/%s.json", pluginName, pluginName))

    if pluginConfig.script then
      require(pluginConfig.script)

      local classInstance = _ENV[pluginName]:new()
      table.insert(plugins, classInstance)
    end

    if pluginConfig.baseConfigValues then
      chatConfig = sb.jsonMerge(chatConfig, pluginConfig.baseConfigValues)
    end

    if pluginConfig.localeKeys then
      self.localePluginConfig = sb.jsonMerge(self.localePluginConfig, pluginConfig.localeKeys)
    end
  end

  self.runCallbackForPlugins = function(method, ...)
    -- The logic here is actually strange and might need some more customisation
    local result = nil
    for _, plugin in ipairs(plugins) do 
      result = plugin[method](plugin, ...)
    end
    return result
  end

  self.runCallbackForPlugins("init")
  localeChat(self.localePluginConfig)

  chatConfig.fontSize = root.getConfiguration("icc_font_size") or chatConfig.fontSize
  local expanded = config.getParameter("expanded")
  setSizes(expanded, chatConfig, config.getParameter("currentSizes"))

  createTotallyFakeWidgets(chatConfig.wrapWidthFullMode, chatConfig.wrapWidthCompactMode, chatConfig.fontSize)

  local storedMessages = root.getConfiguration("icc_last_messages", jarray())

  for btn, isChecked in pairs(config.getParameter("selectedModes") or {}) do
    widget.setChecked(btn, isChecked)
  end

  local maxCharactersAllowed = root.getConfiguration("icc_max_allowed_characters") or 0

  self.irdenChat = IrdenChat:create(self.canvasName, self.highlightCanvasName, self.commandPreviewCanvasName,
    chatConfig, player.id(), storedMessages, self.chatMode,
    expanded, config.getParameter("portraits"), config.getParameter("connectionToUuid"), config.getParameter("chatLineOffset"), maxCharactersAllowed, self.runCallbackForPlugins)

  self.lastCommand = root.getConfiguration("icc_last_command")
  self.contacts = {}
  self.tooltipFields = {}

  self.receivedMessageFromStagehand = false

  self.savedCommandSelection = 0

  self.selectedMessage = nil
  self.sentMessages = root.getConfiguration("icc_my_messages",{}) or {}
  self.sentMessagesLimit = 15
  self.currentSentMessage = nil

  widget.clearListItems("lytCharactersToDM.saPlayers.lytPlayers")

  self.DMTimer = 2
  self.ReplyTimer = 5
  self.ReplyTime = 0
  checkDMs()

  local lastText = config.getParameter("lastInputMessage")
  if lastText and lastText ~= "" then
    widget.setText("tbxInput", lastText)
    widget.focus("tbxInput")
  end

  local currentMessageMode = config.getParameter("currentMessageMode")
  if currentMessageMode then
    widget.setSelectedOption("rgChatMode", currentMessageMode)
    widget.setFontColor("rgChatMode." .. currentMessageMode, chatConfig.modeColors[widget.getData("rgChatMode." .. currentMessageMode).mode])
  else
    widget.setFontColor("rgChatMode.1", chatConfig.modeColors[widget.getData("rgChatMode.1").mode])
  end

  self.DMingTo = config.getParameter("DMingTo")

  if self.DMingTo and not widget.active("lytDMingTo") then
    widget.setPosition("lytCommandPreview", vec2.add(widget.getPosition("lytCommandPreview"), {0, widget.getSize("lytDMingTo")[2]}))
    widget.setPosition(self.canvasName, vec2.add(widget.getPosition(self.canvasName), {0, widget.getSize("lytDMingTo")[2]}))
    widget.setPosition(self.highlightCanvasName, vec2.add(widget.getPosition(self.highlightCanvasName), {0, widget.getSize("lytDMingTo")[2]}))

    widget.setVisible("lytDMingTo", true)
    widget.setText("lytDMingTo.lblRecepient", self.DMingTo)
  end

  self.chatFunctionCallback = function(message)
    self.irdenChat:addMessage(message)
  end

  registerCallbacks()

  requestPortraits()
  self.irdenChat:processQueue()

  ICChatTimer:add(0.5, registerCallbacks)
end


function registerCallbacks()

  message.setHandler("newChatMessage", function(_, sameClient, chatMessage)
    if sameClient then
      if self.irdenChat and self.irdenChat.addMessage then
        self.irdenChat:addMessage(chatMessage)
      end
    end
  end)
  -- handlerCutter = setChatMessageHandler(self.chatFunctionCallback)

  shared.setMessageHandler( "icc_request_player_portrait", simpleHandler(function()
    if player.id() and world.entityExists(player.id()) then
      return {
        portrait = world.entityPortrait(player.id(), "bust"),
        type = "UPDATE_PORTRAIT",
        entityId = player.id(),
        connection = player.id() // -65536,
        cropArea = player.getProperty("icc_portrait_frame") or self.irdenChat.config.portraitCropArea,
        uuid = player.uniqueId()
      }
    end
  end))

  shared.setMessageHandler("icc_sendToUser", simpleHandler(function(message)
    self.irdenChat:addMessage(message)
  end))

  shared.setMessageHandler("icc_is_chat_open", localHandler(function(message)
    return true
  end))

  shared.setMessageHandler("icc_close_chat", localHandler(function(message)
    uninit()
    pane.dismiss()
  end))

  shared.setMessageHandler("icc_send_player_portrait", simpleHandler(function(data)
    self.irdenChat:updatePortrait(data)
  end))

  shared.setMessageHandler( "icc_reset_settings", localHandler(function(data)
    createTotallyFakeWidgets(self.irdenChat.config.wrapWidthFullMode, self.irdenChat.config.wrapWidthCompactMode, root.getConfiguration("icc_font_size") or self.irdenChat.config.fontSize)
    self.runCallbackForPlugins("onSettingsUpdate", data)
    
    localeChat(self.localePluginConfig)
    self.irdenChat:resetChat()
  end))

  shared.setMessageHandler( "icc_clear_history", localHandler(function(data)
    self.irdenChat:clearHistory(message)
  end))

  shared.setMessageHandler( "icc_ping", simpleHandler(function(source)
    starcustomchat.utils.alert("chat.alerts.was_pinged", source)
    pane.playSound(self.irdenChat.config.notificationSound)
  end))

  return true
end

function requestPortraits()
  local messages = self.irdenChat:getMessages()
  local authors = {}

  -- First, gather the unique connetcions
  for _, msg in ipairs(messages) do
    local conn = msg.connection
    if conn and conn ~= 0 and not authors[conn] then
      authors[conn] = true
    end
  end

  for conn, _ in pairs(authors) do 
    self.irdenChat:requestPortrait(conn)
  end
end

function createTotallyFakeWidgets(wrapWidthFullMode, wrapWidthCompactMode, fontSize)
  pane.addWidget({
    type = "label",
    wrapWidth = wrapWidthFullMode,
    fontSize = fontSize,
    position = {-100, -100}
  }, "totallyFakeLabelFullMode")
  pane.addWidget({
    type = "label",
    wrapWidth = wrapWidthCompactMode,
    fontSize = fontSize,
    position = {-100, -100}
  }, "totallyFakeLabelCompactMode")
end

function findButtonByMode(mode)
  local buttons = config.getParameter("gui")["rgChatMode"]["buttons"]
  for i, button in ipairs(buttons) do
    if button.data.mode == mode then
      return i
    end
  end
  return -1
end

function localeChat(localePluginConfig)
  starcustomchat.utils.buildLocale(localePluginConfig)

  local savedText = widget.getText("tbxInput")
  local hasFocus = widget.hasFocus("tbxInput")
  self.chatMode = root.getConfiguration("iccMode") or "modern"
  if self.chatMode ~= "compact" then self.chatMode = "modern" end

  local buttons = config.getParameter("gui")["rgChatMode"]["buttons"]
  for i, button in ipairs(buttons) do
    widget.setText("rgChatMode." .. i, starcustomchat.utils.getTranslation("chat.modes." .. button.data.mode))
  end

  -- Unfortunately, to reset HINT we have to recreate the textbox
  local standardTbx = config.getParameter("gui")["tbxInput"]
  standardTbx.hint = starcustomchat.utils.getTranslation("chat.textbox.hint")

  pane.removeWidget("tbxInput")
  pane.addWidget(standardTbx, "tbxInput")
  widget.setText("tbxInput", savedText)

  widget.setText("lytDMingTo.lblHint", starcustomchat.utils.getTranslation("chat.dming.hint"))
  widget.setPosition("lytDMingTo.lblRecepient", vec2.add(widget.getPosition("lytDMingTo.lblHint"), {widget.getSize("lytDMingTo.lblHint")[1] + 3, 0}))

  if hasFocus then
    widget.focus("tbxInput")
  end
end

function update(dt)

  shared.chatIsOpen = true
  
  ICChatTimer:update(dt)
  promises:update()

  self.irdenChat:clearHighlights()
  widget.setVisible("lytContext", false)

  checkTyping()
  checkCommandsPreview()
  processButtonEvents(dt)

  if not player.id() or not world.entityExists(player.id()) then
    shared.chatIsOpen = false
    pane.dismiss()
  end

  self.ReplyTime = math.max(self.ReplyTime - dt, 0)
  self.runCallbackForPlugins("update", dt)
end

function cursorOverride(screenPosition)
  processEvents(screenPosition)
  processContextMenu(screenPosition)

  self.runCallbackForPlugins("onCursorOverride", screenPosition)
end

function processContextMenu(screenPosition)
  widget.setVisible("lytContext", not not self.selectedMessage)

  if widget.inMember(self.highlightCanvasName, screenPosition) then
    self.selectedMessage = self.irdenChat:selectMessage(widget.inMember("lytContext", screenPosition) and self.selectedMessage and {0, self.selectedMessage.offset + 1})
  else
    self.selectedMessage = nil
  end

  if widget.inMember("lytContext", screenPosition) then
    widget.setVisible("lytContext.btnMenu", false)
    widget.setVisible("lytContext.btnDM", true)
    widget.setVisible("lytContext.btnCopy", true)
    widget.setVisible("lytContext.btnPing", true)
    widget.setSize("lytContext", {60, 15})
  else
    widget.setVisible("lytContext.btnMenu", true)
    widget.setVisible("lytContext.btnDM", false)
    widget.setVisible("lytContext.btnCopy", false)
    widget.setVisible("lytContext.btnPing", false)
    widget.setSize("lytContext", {20, 15})
  end

  if self.selectedMessage then
    local allowCollapse = self.irdenChat.maxCharactersAllowed ~= 0 and self.selectedMessage.isLong
    widget.setVisible("lytContext.btnCollapse", widget.inMember("lytContext", screenPosition) and allowCollapse)

    if allowCollapse then
      widget.setButtonImages("lytContext.btnCollapse", {
        base = string.format("/interface/scripted/starcustomchat/base/contextmenu/%s.png:base", self.selectedMessage.collapsed and "uncollapse" or "collapse"),
        hover = string.format("/interface/scripted/starcustomchat/base/contextmenu/%s.png:hover", self.selectedMessage.collapsed and "uncollapse" or "collapse")
      })
      widget.setData("lytContext.btnCollapse", {
        displayText = string.format("chat.commands.%s", self.selectedMessage.collapsed and "uncollapse" or "collapse")
      })
    end
    
    local canvasPosition = widget.getPosition(self.highlightCanvasName)
    local xOffset = canvasPosition[1] + widget.getSize(self.highlightCanvasName)[1] - widget.getSize("lytContext")[1]
    local yOffset = self.selectedMessage.offset + self.selectedMessage.height + canvasPosition[2]
    local newOffset = vec2.add({xOffset, yOffset}, self.irdenChat.config.contextMenuOffset)

    -- And now we don't want the context menu to fly away somewhere else: we always want to draw it within the canvas
    newOffset[2] = math.min(newOffset[2], self.irdenChat.canvas:size()[2] + widget.getPosition(self.canvasName)[2] - widget.getSize("lytContext")[2])
    widget.setPosition("lytContext", newOffset)
  end
end

function checkCommandsPreview()
  local text = widget.getText("tbxInput")

  if utf8.len(text) > 2 and string.sub(text, 1, 1) == "/" then
    local availableCommands = starcustomchat.utils.getCommands(self.availableCommands, text)

    if #availableCommands > 0 then
      self.savedCommandSelection = math.max(self.savedCommandSelection % (#availableCommands + 1), 1)
      widget.setVisible("lytCommandPreview", true)
      widget.setText("lblCommandPreview", availableCommands[self.savedCommandSelection])
      widget.setData("lblCommandPreview", availableCommands[self.savedCommandSelection])
      self.irdenChat:previewCommands(availableCommands, self.savedCommandSelection)
    else
      widget.setVisible("lytCommandPreview", false)
      widget.setText("lblCommandPreview", "")
      widget.setData("lblCommandPreview", nil)
      self.savedCommandSelection = 0
    end
  else
    widget.setVisible("lytCommandPreview", false)
    widget.setText("lblCommandPreview", "")
    widget.setData("lblCommandPreview", nil)
    self.savedCommandSelection = 0
  end
end

function checkTyping()
  if widget.hasFocus("tbxInput") or widget.getText("tbxInput") ~= "" then
    status.addPersistentEffect("icchatdots", "icchatdots")
  else
    status.clearPersistentEffects("icchatdots")
    self.currentSentMessage = nil
  end
end

function checkDMs()
  if widget.active("lytCharactersToDM") then
    populateList()
  end
  ICChatTimer:add(self.DMTimer, checkDMs)
end

function populateList()
  local function drawCharacters(players, toRemovePlayers)
    local mode = #players > 7 and "letter" or "avatar"

    local idTable = {}  -- This table will store only the 'id' values

    for _, player in ipairs(players) do
      table.insert(idTable, player.id)

      if index(self.contacts, player.id) == 0 and player.data then
        local li = widget.addListItem("lytCharactersToDM.saPlayers.lytPlayers")
        if mode == "letter" or not player.data.portrait then
          drawIcon("lytCharactersToDM.saPlayers.lytPlayers." .. li .. ".contactAvatar", string.sub(player.name, 1, 2))
        elseif player.data.portrait then
          drawIcon("lytCharactersToDM.saPlayers.lytPlayers." .. li .. ".contactAvatar", player.data.portrait)
        end

        widget.setData("lytCharactersToDM.saPlayers.lytPlayers." .. li, {
          id = player.id,
          tooltipMode = player.name
        })
        self.tooltipFields["lytCharactersToDM.saPlayers.lytPlayers." .. li] = player.name
        table.insert(self.contacts, player.id)
      end
    end


    if toRemovePlayers then
      for i, id in ipairs(self.contacts) do
        if index(idTable, id) == 0 then
          widget.removeListItem("lytCharactersToDM.saPlayers.lytPlayers", i - 1)
          table.remove(self.contacts, i)
        end
      end
    end
  end

  local playersAround = {}

  if player.id() and world.entityPosition(player.id()) then
    for _, player in ipairs(world.playerQuery(world.entityPosition(player.id()), 40)) do
      table.insert(playersAround, {
        id = player,
        name = world.entityName(player) or "Unknown",
        data = {
          portrait = world.entityPortrait(player, "bust")
        }
      })
    end
  end

  drawCharacters(playersAround, not self.receivedMessageFromStagehand)


  --[[
  starcustomchat.utils.sendMessageToStagehand(self.stagehandName, "icc_getAllPlayers", _, function(players)
    self.receivedMessageFromStagehand = true
    drawCharacters(players, true)
  end)
  ]]
end

function selectPlayer()
  widget.focus("tbxInput")
end

function drawIcon(canvasName, args)
	local playerCanvas = widget.bindCanvas(canvasName)
  playerCanvas:clear()

  if type(args) == "number" then
    local playerPortrait = world.entityPortrait(args, "bust")
    for _, layer in ipairs(playerPortrait) do
      playerCanvas:drawImage(layer.image, {-14, -18})
    end
  elseif type(args) == "table" then
    for _, layer in ipairs(args) do
      playerCanvas:drawImage(layer.image, {-14, -18})
    end
  elseif type(args) == "string" and string.len(args) == 2 then
    playerCanvas:drawText(args, {
      position = {8, 3},
      horizontalAnchor = "mid", -- left, mid, right
      verticalAnchor = "bottom", -- top, mid, bottom
      wrapWidth = nil -- wrap width in pixels or nil
    }, self.irdenChat.config.fontSize + 1)
  elseif type(args) == "string" then
    playerCanvas:drawImage(args, {-1, 0})
  end
end

function getSizes(expanded, chatParameters)
  local canvasSize = widget.getSize(self.canvasName)
  local saPlayersSize = widget.getSize("lytCharactersToDM.saPlayers")

  local charactersListWidth = widget.getSize("lytCharactersToDM.background")[1]

  return {
    canvasSize = expanded and {canvasSize[1], chatParameters.expandedBodyHeight - chatParameters.spacings.messages - 4} or {canvasSize[1], chatParameters.bodyHeight - chatParameters.spacings.messages - 4},
    highligtCanvasSize = expanded and {canvasSize[1], chatParameters.expandedBodyHeight - chatParameters.spacings.messages - 4} or {canvasSize[1], chatParameters.bodyHeight - chatParameters.spacings.messages - 4},
    bgStretchImageSize = expanded and {canvasSize[1], chatParameters.expandedBodyHeight - chatParameters.spacings.messages} or {canvasSize[1], chatParameters.bodyHeight - chatParameters.spacings.messages},
    scrollAreaSize = expanded and {canvasSize[1], chatParameters.expandedBodyHeight} or {canvasSize[1], chatParameters.bodyHeight },
    playersSaSize = expanded and {saPlayersSize[1], chatParameters.expandedBodyHeight - 15} or {saPlayersSize[1], chatParameters.bodyHeight - 15},
    playersDMBackground = expanded and {charactersListWidth, chatParameters.expandedBodyHeight - 15} or {charactersListWidth, chatParameters.bodyHeight- 15}
  }
end

function setSizes(expanded, chatParameters, currentSizes)
  local defaultSizes = getSizes(expanded, chatParameters)
  widget.setSize(self.canvasName, currentSizes and currentSizes.canvasSize or defaultSizes.canvasSize)
  widget.setSize("saScrollArea", currentSizes and currentSizes.canvasSize or defaultSizes.canvasSize)
  widget.setSize(self.highlightCanvasName, currentSizes and currentSizes.highligtCanvasSize or defaultSizes.highligtCanvasSize)
  widget.setSize("lytCharactersToDM.background", currentSizes and currentSizes.playersDMBackground or defaultSizes.playersDMBackground)
  widget.setSize("backgroundImage", currentSizes and currentSizes.bgStretchImageSize or defaultSizes.bgStretchImageSize)
  widget.setSize("saFakeScrollArea", currentSizes and currentSizes.scrollAreaSize or defaultSizes.scrollAreaSize)
  widget.setSize("lytCharactersToDM.saPlayers", currentSizes and currentSizes.playersSaSize or defaultSizes.playersSaSize)
end

function canvasClickEvent(position, button, isButtonDown)
  if button == 0 and isButtonDown then
    self.irdenChat.expanded = not self.irdenChat.expanded

    local chatParameters = getSizes(self.irdenChat.expanded, self.irdenChat.config)
    saveEverythingDude()
    pane.dismiss()

    local chatConfig = buildChatInterface()
    chatConfig["gui"]["background"]["fileBody"] = string.format("/interface/scripted/starcustomchat/base/%s.png", self.irdenChat.expanded and "body" or "shortbody")
    chatConfig.expanded = self.irdenChat.expanded
    chatConfig.currentSizes = chatParameters
    chatConfig.lastInputMessage = widget.getText("tbxInput")
    chatConfig.portraits = self.irdenChat.savedPortraits
    chatConfig.connectionToUuid =  self.irdenChat.connectionToUuid
    chatConfig.currentMessageMode =  widget.getSelectedOption("rgChatMode")
    chatConfig.chatLineOffset = self.irdenChat.lineOffset
    chatConfig.reopened = true
    chatConfig.DMingTo = self.DMingTo
    chatConfig.selectedModes = {}
    for _, mode in ipairs(chatConfig["chatModes"]) do 
      if widget.active("btnCk" .. mode) then
        chatConfig.selectedModes["btnCk" .. mode] = widget.getChecked("btnCk" .. mode)
      end
    end

    self.reopening = true
    player.interact("ScriptPane", chatConfig)
  end

  -- Defocus from the canvases or we can never leave lol :D
  widget.blur(self.canvasName)
  widget.blur(self.highlightCanvasName)
end

function processEvents(screenPosition)
  for _, event in ipairs(input.events()) do
    if event.type == "MouseWheel" and widget.inMember("backgroundImage", screenPosition) then
      if input.key("LCtrl") then
        self.irdenChat.config.fontSize = math.min(math.max(self.irdenChat.config.fontSize + event.data.mouseWheel, 6), 10)
        root.setConfiguration("icc_font_size", self.irdenChat.config.fontSize)
        createTotallyFakeWidgets(self.irdenChat.config.wrapWidthFullMode, self.irdenChat.config.wrapWidthCompactMode, self.irdenChat.config.fontSize)
        self.irdenChat:processQueue()
      else
        self.irdenChat:offsetCanvas(event.data.mouseWheel * -1 * (input.key("LShift") and 2 or 1))
      end
    elseif event.type == "KeyDown" then
      if event.data.key == "PageUp" then
        self.irdenChat:offsetCanvas(self.irdenChat.expanded and - self.irdenChat.config.pageSkipExpanded or - self.irdenChat.config.pageSkip)
      elseif event.data.key == "PageDown" then
        self.irdenChat:offsetCanvas(self.irdenChat.expanded and self.irdenChat.config.pageSkipExpanded or self.irdenChat.config.pageSkip)
      end
    end
  end
end

function processButtonEvents(dt)
  if input.keyDown("Return") or input.keyDown("/") and not widget.hasFocus("tbxInput") then
    if input.keyDown("/") then
      widget.setText("tbxInput", "/")
    end
    widget.focus("tbxInput")
    chat.setInput("")
  end


  if widget.hasFocus("tbxInput") then
    for _, event in ipairs(input.events()) do
      if event.type == "KeyDown" then
        if event.data.key == "Tab" then
          self.savedCommandSelection = self.savedCommandSelection + 1
        elseif event.data.key == "Up" and event.data.mods and event.data.mods.LShift then
          if #self.sentMessages > 0 then
            self.currentSentMessage = self.currentSentMessage and math.max(self.currentSentMessage - 1, 1) or #self.sentMessages
            widget.setText("tbxInput", self.sentMessages[self.currentSentMessage])
          end
        elseif event.data.key == "Down" and event.data.mods and event.data.mods.LShift then
          if #self.sentMessages > 0 then
            self.currentSentMessage = self.currentSentMessage and math.min(self.currentSentMessage + 1, #self.sentMessages) or #self.sentMessages
            widget.setText("tbxInput", self.sentMessages[self.currentSentMessage])
          end
        end
      end
    end
  end


  if input.bindDown("starcustomchat", "repeatcommand") and self.lastCommand then
    self.irdenChat:processCommand(self.lastCommand)
  end
end

function resetDMLayout()
  if widget.active("lytDMingTo") then
    widget.setPosition("lytCommandPreview", vec2.sub(widget.getPosition("lytCommandPreview"), {0, widget.getSize("lytDMingTo")[2]}))
    widget.setPosition(self.canvasName, vec2.sub(widget.getPosition(self.canvasName), {0, widget.getSize("lytDMingTo")[2]}))
    widget.setPosition(self.highlightCanvasName, vec2.sub(widget.getPosition(self.highlightCanvasName), {0, widget.getSize("lytDMingTo")[2]}))
  end

  self.DMingTo = nil
  widget.setVisible("lytDMingTo", false)
end

function copyMessage()
  if self.selectedMessage then
    clipboard.setText(self.selectedMessage.text)
    starcustomchat.utils.alert("chat.alerts.copied_to_clipboard")
  end
end

function enableDM()
  if self.selectedMessage then
    if self.selectedMessage.connection == 0 then
      starcustomchat.utils.alert("chat.alerts.cannot_dm_server")
    elseif self.selectedMessage.mode == "CommandResult" then
      starcustomchat.utils.alert("chat.alerts.cannot_dm_command_result")
    elseif self.selectedMessage.connection and self.selectedMessage.nickname then
      if not widget.active("lytDMingTo") then
        widget.setPosition("lytCommandPreview", vec2.add(widget.getPosition("lytCommandPreview"), {0, widget.getSize("lytDMingTo")[2]}))
        widget.setPosition(self.canvasName, vec2.add(widget.getPosition(self.canvasName), {0, widget.getSize("lytDMingTo")[2]}))
        widget.setPosition(self.highlightCanvasName, vec2.add(widget.getPosition(self.highlightCanvasName), {0, widget.getSize("lytDMingTo")[2]}))
      end
      widget.setVisible("lytDMingTo", true)
      self.DMingTo = self.selectedMessage.recepient or self.selectedMessage.nickname
      widget.setText("lytDMingTo.lblRecepient", self.DMingTo)
      widget.focus("tbxInput")
    end
  end
end

function ping()
  if self.selectedMessage then
    local message = copy(self.selectedMessage)
    if message.connection == 0 then
      starcustomchat.utils.alert("chat.alerts.cannot_ping_server")
    elseif message.mode == "CommandResult" then
      starcustomchat.utils.alert("chat.alerts.cannot_ping_command")
    elseif message.connection and message.nickname then
      if self.ReplyTime > 0 then
        starcustomchat.utils.alert("chat.alerts.cannot_ping_time", math.ceil(self.ReplyTime))
      else
        
        local target = message.connection * -65536
        if target == player.id() then
          starcustomchat.utils.alert("chat.alerts.cannot_ping_yourself")
        else
          promises:add(world.sendEntityMessage(target, "icc_ping", player.name()), function()
            starcustomchat.utils.alert("chat.alerts.pinged", message.nickname)
          end, function()
            starcustomchat.utils.alert("chat.alerts.ping_failed", message.nickname)
          end)

          self.ReplyTime = self.ReplyTimer
        end
      end
    end
  end
end

function collapse()
  if self.selectedMessage then
    self.irdenChat:collapseMessage({0, self.selectedMessage.offset + 1})
  end
end

function escapeTextbox(widgetName)
  if not self.DMingTo then
    blurTextbox(widgetName)
  else
    resetDMLayout()
    widget.focus(widgetName)
  end
end

function blurTextbox(widgetName)
  widget.setText(widgetName, "")
  widget.blur(widgetName)
end

function textboxEnterKey(widgetName)
  local text = widget.getText(widgetName)

  if text == "" then
    blurTextbox(widgetName)
    return
  end

  local message = {
    text = text,
    mode = widget.getSelectedData("rgChatMode").mode
  }

  if string.sub(text, 1, 1) == "/" then
    if string.len(text) == 1 then
      blurTextbox(widgetName)
      return
    end

    if string.sub(text, 1, 2) == "//" then
      starcustomchat.utils.alert("chat.alerts.cannot_start_two_slashes")
      return
    end

    if widget.getData("lblCommandPreview") and widget.getData("lblCommandPreview") ~= "" then
      widget.setText(widgetName, widget.getData("lblCommandPreview") .. " ")
      return
    else
      processCommand(text)
      self.lastCommand = text
      starcustomchat.utils.saveMessage(text)
    end
  elseif message.mode == "Whisper" or self.DMingTo then
    local whisperName
    if self.DMingTo then
      whisperName = self.DMingTo
      resetDMLayout()
    else
      local li = widget.getListSelected("lytCharactersToDM.saPlayers.lytPlayers")
      if not li then starcustomchat.utils.alert("chat.alerts.dm_not_specified") return end

      local data = widget.getData("lytCharactersToDM.saPlayers.lytPlayers." .. li)
      if (not world.entityExists(data.id) and index(self.contacts, data.id) == 0) then starcustomchat.utils.alert("chat.alerts.dm_not_found") return end

      whisperName = widget.getData("lytCharactersToDM.saPlayers.lytPlayers." .. widget.getListSelected("lytCharactersToDM.saPlayers.lytPlayers")).tooltipMode
    end

    local whisper = string.find(whisperName, "%s") and "/w \"" .. whisperName .. "\" " .. text or "/w " .. whisperName .. " " .. text

    processCommand(whisper)
    self.irdenChat.lastWhisper = {
      recepient = whisperName,
      text = text
    }
    starcustomchat.utils.saveMessage(whisper)
  else
    starcustomchat.utils.saveMessage(message.text)
    message = self.runCallbackForPlugins("formatOutcomingMessage", message)
    sendMessage(message)
    
  end
  blurTextbox(widgetName)
end

function processCommand(command)
  self.irdenChat:processCommand(command)
end

function sendMessage(message)
  self.irdenChat:sendMessage(message.text, message.mode)
end

function setMode(id, data)
  local modeButtons = config.getParameter("gui")["rgChatMode"]["buttons"]
  for i, btn in ipairs(modeButtons) do
    widget.setFontColor("rgChatMode." .. i, self.irdenChat.config.unselectedModeColor)
  end
  widget.setFontColor("rgChatMode." .. id, self.irdenChat.config.modeColors[data.mode])

  self.runCallbackForPlugins("onModeChange", data.mode)
end

function redrawChat()
  self.irdenChat:processQueue()
end

function toBottom()
  self.irdenChat:resetOffset()
end

function openSettings()
  local chatConfigInterface = buildSettingsInterface()
  chatConfigInterface.chatMode = self.chatMode
  chatConfigInterface.enabledPlugins = config.getParameter("enabledPlugins", {})
  chatConfigInterface.backImage = self.irdenChat.config.icons.empty
  chatConfigInterface.frameImage = self.irdenChat.config.icons.frame
  chatConfigInterface.proximityRadius = self.irdenChat.proximityRadius
  chatConfigInterface.defaultCropArea = self.irdenChat.config.portraitCropArea
  chatConfigInterface.portraitFrame = player.getProperty("icc_portrait_frame") or self.irdenChat.config.portraitCropArea
  chatConfigInterface.fontSize = self.irdenChat.config.fontSize
  chatConfigInterface.maxCharactersAllowed = self.irdenChat.maxCharactersAllowed
  player.interact("ScriptPane", chatConfigInterface)
end

-- Utility function: return the index of a value in the given array
function index(tab, value)
  for k, v in ipairs(tab) do
    if v == value then return k end
  end
  return 0
end

function createTooltip(screenPosition)
  if self.tooltipFields then
    for widgetName, tooltip in pairs(self.tooltipFields) do
      if widget.inMember(widgetName, screenPosition) then
        return tooltip
      end
    end
  end

  if widget.getChildAt(screenPosition) then
    local w = widget.getChildAt(screenPosition)
    local wData = widget.getData(w:sub(2))
    if wData and type(wData) == "table" then
      if wData.tooltipMode then
        return wData.mode and starcustomchat.utils.getTranslation("chat.modes." .. wData.mode) or wData.tooltipMode
      elseif wData.displayText then
        return starcustomchat.utils.getTranslation(wData.displayText)
      end
    end
  end
end


function saveEverythingDude()
  -- Save messages and last command
  local messages = self.irdenChat:getMessages()
  root.setConfiguration("icc_last_messages", messages)
  root.setConfiguration("icc_last_command", self.lastCommand)
  root.setConfiguration("icc_my_messages", self.sentMessages)
end

function uninit()
  local text = widget.getText("tbxInput")
  if not self.reopening and text and text ~= "" then
    clipboard.setText(text)
  end

  saveEverythingDude()
  -- handlerCutter()
end
