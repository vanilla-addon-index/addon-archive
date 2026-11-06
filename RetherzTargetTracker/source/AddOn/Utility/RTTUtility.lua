function pack(...)
  return arg;
end

function RTT_StringSplit(str, delimiter)
  local t, temp= {}, "";
  for i = 1, string.len(str) do
    local strMsg = "";
    for i2 = 1, string.len(delimiter) do
      strMsg = strMsg .. string.sub(str, i + i2 - 1, i + i2 - 1);
    end
    if(strMsg == delimiter) then
      table.insert(t, temp);
      i = i + string.len(delimiter) - 1;
      temp = "";
    else
      temp = temp .. string.sub(str, i, i);
    end
  end
  if(temp ~= "") then
    table.insert(t, temp);
  end
  return unpack(t);
end

function RTT_Round(value)
	return math.floor(value + 0.5)
end

function RTT_TableClone(t)
  return {unpack(t)};
end

function RTT_UseAction()
  if(RetherzTargetTracker.UseAction ~= 0) then
    if not IsCurrentAction(RetherzTargetTracker.UseAction) then
      UseAction(RetherzTargetTracker.UseAction);
    end
  end
end
