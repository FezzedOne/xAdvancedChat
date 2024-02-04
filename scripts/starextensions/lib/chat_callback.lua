---@param newHandler func(Json): nil
---@return func(): nil
function setChatMessageHandler(newHandler)
  -- The returned function doesn't need to do anything since xSB-2 already 
  -- automatically "batches" messages while the world client is swapping worlds.
  return function() end
end
