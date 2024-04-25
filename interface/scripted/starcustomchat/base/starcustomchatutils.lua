starcustomchat = {
  utils = {},
  locale = {},
  currentLocale = "en"
}

function starcustomchat.utils.cleanNickname(nick)
  return string.gsub(nick, "^.*<.*;(.*)%^reset;$",  "%1")
end

function starcustomchat.utils.getLocale()
  local xAdvChatConfig = root.getConfiguration("xAdvancedChat") or jobject()
  return xAdvChatConfig.locale or "en"
end

function starcustomchat.utils.buildLocale(localePluginConfig)
  local addLocaleKeys = copy(localePluginConfig or {})

  local xAdvChatConfig = root.getConfiguration("xAdvancedChat") or jobject()
  local locale = xAdvChatConfig.locale or "en"
  starcustomchat.currentLocale = locale
  
  for key, translates in pairs(addLocaleKeys) do 
    if type(translates) == "table" then 
      addLocaleKeys[key] = translates[locale]
    end
  end

  -- Get base locale
  starcustomchat.locale = root.assetJson(string.format("/interface/scripted/starcustomchat/languages/%s.json", locale))
  -- Merge the plugin locale on top of it
  starcustomchat.locale = sb.jsonMerge(starcustomchat.locale, addLocaleKeys)
end

function starcustomchat.utils.getTranslation(key)
  if not starcustomchat.locale[key] then
    sb.logError("Can't get transaction of key: %s", key)
    return "???"
  else
    return starcustomchat.locale[key]
  end
end

function starcustomchat.utils.alert(key, format)
  local text = starcustomchat.utils.getTranslation(key)
  interface.queueMessage(format and string.format(text, format) or text)
end

function starcustomchat.utils.saveMessage(message)
  table.insert(self.sentMessages, message)

  if #self.sentMessages > self.sentMessagesLimit then
    table.remove(self.sentMessages, 1)
  end
  self.currentSentMessage = #self.sentMessages
end

function starcustomchat.utils.getCommands(allCommands, substr)
  local availableCommands = {}

  for type, commlist in pairs(allCommands) do 
    for _, comm in ipairs(commlist) do
      if type ~= "admin" or (type == "admin" and player.isAdmin()) then
        local status, found = pcall(string.find, comm, substr)
        if status and found then
          table.insert(availableCommands, comm)
        end
      end
    end
  end

  table.sort(availableCommands, function(a, b) return a:upper() < b:upper() end)
  return availableCommands
end

-- Degranon: Update to proximity chat mode.
function starcustomchat.utils.sendMessageToStagehand(stagehandType, message, data, callback, errcallback)

  local ensureSending = function ()
    promises:add(world.sendEntityMessage(stagehandType, message, data), function (result)
      if callback then
        callback(result)
      end
    end, ensureSending)
  end

  local ensureSpawning = function()
    promises:add(world.findUniqueEntity(stagehandType), ensureSending, ensureSpawning)
  end

  promises:add(world.findUniqueEntity(stagehandType), ensureSending, function()
    world.spawnStagehand(world.entityPosition(player.id()), stagehandType)

    promises:add(world.findUniqueEntity(stagehandType), ensureSending, ensureSpawning)
  end)
end

-- FezzedOne: Needed to borrow this from StarCustomChat to prevent UTF-8 errors. Ugh.
function starcustomchat.utils.utf8Substring(inputString, startPos, endPos)
  -- Check if startPos is within the valid range
  startPos = math.min(startPos, endPos)

  endPos = math.min(endPos, utf8.len(inputString))

  -- Calculate the byte offsets for the start and end positions
  local byteStart = utf8.offset(inputString, startPos)
  local byteEnd = utf8.offset(inputString, endPos + 1) - 1

  -- Extract the substring
  local result = string.sub(inputString, byteStart, byteEnd)

  return result
end

function starcustomchat.utils.createStagehandWithData(stagehandType, data)
  world.spawnStagehand(world.entityPosition(player.id()), stagehandType, {data = data})
end