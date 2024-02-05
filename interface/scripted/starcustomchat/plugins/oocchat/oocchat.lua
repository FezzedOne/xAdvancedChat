require "/interface/scripted/starcustomchat/plugin.lua"

oocchat = PluginClass:new(
  { name = "oocchat" }
)

function oocchat:init()
  self:_loadConfig()
end

function oocchat:formatIncomingMessage(message)
  -- Strip colour codes out of the message.
  local strippedMessage = message.text:gsub("%^;", "^x;")
  strippedMessage = strippedMessage:gsub("%^[^%^][^ ]-;", "")

  -- Check for double parentheses.
  if strippedMessage:find("^%(%(.*%)%)$") then
    if message.mode == "Broadcast" or message.mode == "Local" then
      message.mode = "OOC"
    end
  end

  -- FezzedOne: Check for double square brackets.
  if strippedMessage:find("^%[%[.*]]$") then
    if message.mode == "Broadcast" or message.mode == "Local" then
      message.mode = "OOC"
    end
  end

  -- FezzedOne: Check for double angled brackets.
  if strippedMessage:find("^<<.*>>$") then
    if message.mode == "Broadcast" or message.mode == "Local" or message.mode == "CommandResult" then
      message.mode = "Dice"
    end
  end

  -- Reformat incoming OOC and dice roll messages appropriately.
  if message.text:find("%(%(") then
    if message.mode ~= "Broadcast" and message.mode ~= "Local" then
      message.text = string.gsub(message.text, "%(%b()%)", "^gray,set;%1^white,set;")
      message.text = string.gsub(message.text, "%(%((.*)$", "^gray,set;((%1^white,set;")
    end
  end

  if message.text:find("%[%[") then
    if message.mode ~= "Broadcast" and message.mode ~= "Local" then
      message.text = string.gsub(message.text, "%[%b()]", "^gray,set;%1^white,set;")
      message.text = string.gsub(message.text, "%[%[(.*)$", "^gray,set;[[%1^white,set;")
    end
  end

  if message.text:find("<<") then
    if message.mode ~= "Broadcast" and message.mode ~= "Local" then
      message.text = string.gsub(message.text, "<%b()>", "^#ffd499,set;%1^white,set;")
      message.text = string.gsub(message.text, "<<(.*)$", "^#ffd499,set;<<%1^white,set;")
    end
  end
  return message
end

function oocchat:formatOutcomingMessage(message)
  if message.mode == "OOC" then
    message.text = string.format("(( %s ))", message.text)
    message.mode = "Broadcast"
  end

  if message.mode == "Dice" then
    message.text = string.format("<< %s >>", message.text)
    message.mode = "Local"
  end
  return message
end