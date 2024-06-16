require "/interface/scripted/starcustomchat/chatbuilder.lua"

local shared = getmetatable('').shared
if type(shared) ~= "table" then
  shared = {}
  getmetatable('').shared = shared
end

shared.queuedChatMessages = shared.queuedChatMessages or jarray()
shared.startTyping = false
shared.startCommand = false

function init()
  local reasonToNotStart = checkSEAndControls()
  if reasonToNotStart then
    local sewarningConfig = root.assetJson("/interface/scripted/starcustomchat/sewarning/sewarning.json")
    sewarningConfig.reason = reasonToNotStart
    player.interact("ScriptPane", sewarningConfig)
  else
    shared.queuedChatMessages = storage.queuedChatMessages or shared.queuedChatMessages or {}
    storage.queuedChatMessages = nil
    self.interface = buildChatInterface()
    shared.setMessageHandler = message.setHandler
    message.setHandler("newChatMessage", function(_, sameClient, chatMessage)
      if sameClient then
        local chatShown = world.sendEntityMessage(player.id(), "xAdvChat.addMessage", chatMessage):succeeded()
        if chatShown then
          shared.queuedChatMessages = jarray()
        else
          table.insert(shared.queuedChatMessages, chatMessage)
        end
      end
    end)
    -- Also handle proximity messages here so they don't get "swallowed" when the chat pane is closed.
    message.setHandler("icc_sendToUser", function(_, _, chatMessage)
      local chatShown = world.sendEntityMessage(player.id(), "xAdvChat.addMessage", chatMessage):succeeded()
      if chatShown then
        shared.queuedChatMessages = jarray()
      else
        table.insert(shared.queuedChatMessages, chatMessage)
      end
    end)
  end
end

function checkSEAndControls()
  -- Now checks whether xSB-2 is loaded and has a minimum version number.
  if not _ENV["xsb"] or not root.assetData then
    return "se_not_found"
  else
    if not chat then
      return "se_version"
    end
    local bindings = root.getConfiguration("bindings")
    if #bindings["ChatBegin"] > 0 or #bindings["ChatBeginCommand"] > 0 or #bindings["InterfaceRepeatCommand"] > 0 then
      return "unbind_controls"
    end
  end
end

function update(dt)
  if not shared.chatIsOpen and self.interface and (input.keyDown("Return") or input.keyDown("/")) then
    local xAdvChatConfig = root.getConfiguration("xAdvancedChat") or jobject()
    self.interface.expanded = xAdvChatConfig.expanded
    player.interact("ScriptPane", self.interface)
    shared.chatIsOpen = true
    if input.keyDown("Return") then
      shared.startTyping = true
    else
      shared.startCommand = true
    end
  end
end

function uninit()
  storage.queuedChatMessages = shared.queuedChatMessages
  shared.queuedChatMessages = nil
end
