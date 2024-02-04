require "/interface/scripted/starcustomchat/chatbuilder.lua"

local shared = getmetatable('').shared
if type(shared) ~= "table" then
  shared = {}
  getmetatable('').shared = shared
end

function init()
  local reasonToNotStart = checkSEAndControls()
  if reasonToNotStart then
    local sewarningConfig = root.assetJson("/interface/scripted/starcustomchat/sewarning/sewarning.json")
    sewarningConfig.reason = reasonToNotStart
    player.interact("ScriptPane", sewarningConfig)
  else
    self.interface = buildChatInterface()
    shared.setMessageHandler = message.setHandler
  end
end

function checkSEAndControls()
  local v = require "/scripts/semver.lua"
  -- Now checks whether xSB-2 is loaded and has a minimum version number.
  if not _ENV["xsb"] or not root.assetData then
    return "se_not_found"
  else
    local v = load(root.assetData("/scripts/semver.lua"))()
    if v(xsb.version()) < v"2.3.7" then
      return "se_version"
    end
    local bindings = root.getConfiguration("bindings")
    if #bindings["ChatBegin"] > 0 or #bindings["ChatBeginCommand"] > 0 or #bindings["InterfaceRepeatCommand"] > 0 then
      return "unbind_controls"
    end
  end
end

function update(dt)
  if not shared.chatIsOpen and self.interface then
    player.interact("ScriptPane", self.interface)
    shared.chatIsOpen = true
  end
end

function uninit()
end
