require "/interface/scripted/starcustomchat/plugin.lua"

mainchat = PluginClass:new(
  { name = "mainchat" }
)

function mainchat:init()
  self:_loadConfig()
  -- self.baseInterfaceConfig = root.assetJson("/interface/scripted/starcustomchat/base/chat.config")
end

function mainchat:update()
  local id = findButtonByMode("Party")
  if #player.teamMembers() == 0 then
    widget.setButtonEnabled("rgChatMode." .. id, false)
    -- widget.setFontColor("rgChatMode." .. id, self.baseInterfaceConfig.disabledModeColor)
    if widget.getSelectedData("rgChatMode").mode == "Party" then
      widget.setSelectedOption("rgChatMode", 1)
    end
  else
    widget.setButtonEnabled("rgChatMode." .. id, true)
    -- widget.setFontColor("rgChatMode." .. id, self.baseInterfaceConfig.unselectedModeColor)
  end
end

function mainchat:formatIncomingMessage(message)
  if message.mode == "CommandResult" then
    message.portrait = self.modeIcons.console
    message.nickname = "Console"    
  elseif message.mode == "RadioMessage" then
    message.portrait = message.portrait or self.modeIcons.server
    message.nickname = message.nickname or "Server"
  elseif message.mode == "Whisper" or message.mode == "Local" or message.mode == "Broadcast" or message.mode == "Party" or message.mode == "World" then
    if message.connection == 0 then
      message.portrait = message.portrait or self.modeIcons.server
      message.nickname = message.nickname or "Server"
    else
      message.portrait = message.portrait and message.portrait ~= "" and message.portrait or message.connection
      message.nickname = message.nickname or ""
    end
  end

  return message
end

function mainchat:onSendMessage(data)
  if data.mode == "Broadcast" or data.mode == "Local" or data.mode == "Party" then
    chat.send(data.text, data.mode)
  end
end

function mainchat:onModeChange(mode)
  widget.setVisible("lytCharactersToDM", mode == "Whisper")
end