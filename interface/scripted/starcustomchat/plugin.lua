-- base.lua

PluginClass = {
  name = ""
}

function PluginClass:new(obj)
    local obj = obj or {}
    setmetatable(obj, self)
    self.__index = self
    return obj
end

function PluginClass:_loadConfig()
  local parms = root.assetJson(string.format("/interface/scripted/starcustomchat/plugins/%s/%s.json", self.name, self.name)).parameters
  if parms then
    for name, value in pairs(parms) do 
      self[name] = value
    end
  end
end

function PluginClass:update(dt)

end

function PluginClass:onSendMessage(data)

end

function PluginClass:onReceiveMessage(message)

end

function PluginClass:onModeChange(mode)

end

function PluginClass:formatIncomingMessage(message)
  return message
end

function PluginClass:formatOutcomingMessage(message)
  return message
end

function PluginClass:onSettingsUpdate(data)

end

function PluginClass:onCursorOverride(screenPosition)
  
end


-- Settings callbacks
function PluginClass:settings_init(localeConfig)
  
end

function PluginClass:settings_update(dt)
  
end

function PluginClass:settings_onCursorOverride(screenPosition)
  
end

function PluginClass:settings_onSave(localeConfig)

end