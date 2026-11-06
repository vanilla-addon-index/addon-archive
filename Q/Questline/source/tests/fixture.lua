pfDB["units"]["data"] = {
  [1] = { ["name"] = "L\'épreuve" },
  [2] = { ["name"] = "removed" },
  [3] = "_",
}
do
  local ids = { 2 }
  for _, id in pairs(ids) do
    if pfDB["units"]["data"][id] then pfDB["units"]["data"][id] = nil end
  end
end
