RTT_BarData = {};
for i = 1, 8 do
  RTT_BarData[i] = {
    debuffs = {};
    };
  for i2 = 1, 4 do
    RTT_BarData[i].debuffs[i2] = {
      name = "";
      active = false;
      timestamp = 0;
      stacks = 0;
    };
  end

end
