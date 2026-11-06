function toxictagger(S, x)
ScriptErrors:SetScript("OnShow", function(m) UIErrorsFrame:AddMessage("No target found",1,0,0) ScriptErrors:Hide() end)
		
		
			function TryTake()
			
			TargetNearestEnemy();
				for i=1,table.getn(x) do
			
					if (UnitHealth("target")==0 or UnitIsTapped("target") or not (string.find(UnitName("target"), x[i]))) then
							UIErrorsFrame:AddMessage("Looking for: "..x[i].." but didn't tag. Found: "..UnitName("target"),1,0,0); 
							
						
					else 
						if (string.find(UnitName("target"), x[i])) then 
							if (S=="Attack") then
								DEFAULT_CHAT_FRAME:AddMessage("Using ATTACK")
								 if not IsCurrentAction(12) then 
									CastSpellByName(S);
								end;
							else
								CastSpellByName(S);
							end
							UIErrorsFrame:AddMessage("Attempting "..S.." on: "..UnitName("target").." reason: "..x[i],1,0,0);
							break;
						end
					end
				end				
			end
		
        TryTake();
ScriptErrors:SetScript("OnShow", function(m) ScriptErrors:Show() end)
end
