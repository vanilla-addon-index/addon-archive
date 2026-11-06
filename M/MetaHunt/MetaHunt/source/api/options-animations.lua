-- MetaHunt: "Animations" options panel.
-- Global enable/disable plus a per-animation checkbox for each effect, grouped
-- into sections (Pet, Book, ...). The animation registry lives in fx-celebrate.lua
-- (MTH_FX_ANIM_SECTIONS / MTH_FX_ANIM_DEFS) so both the effects and this panel
-- stay in sync.

local MTH_ANIM_READY = MTH_OptionsRequire and MTH_OptionsRequire("options-animations", {
	"MTH_GetFrame",
	"MTH_ClearContainer",
	"MTH_CreateCheckbox",
})

local MTH_ANIM_LINK = "https://codeberg.org/Pizzahawaii/PizzaSauce"
local MTH_ANIM_CTRL = {}

local function MTH_ANIM_L(key, default)
	if MTH and MTH.GetLocalization then
		return MTH:GetLocalization(key, default)
	end
	return default or key
end

local function MTH_ANIM_InsertLink(url)
	local link = tostring(url or "")
	if link == "" then return end
	if type(MTH_InsertLinkToChat) == "function" and MTH_InsertLinkToChat(link) then
		if MTH and MTH.Print then
			MTH:Print(MTH_ANIM_L("ANIM_LINK_INSERTED", "Link inserted in chat: ") .. link)
		end
		return
	end
	if MTH and MTH.Print then
		MTH:Print(MTH_ANIM_L("ANIM_LINK_FALLBACK", "Link: ") .. link)
	end
end

local function MTH_ANIM_UpdateChildStates()
	local master = MTH_FX_AnimationsEnabled()
	local i = 1
	while i <= table.getn(MTH_ANIM_CTRL) do
		local cb = MTH_ANIM_CTRL[i]
		if cb then
			cb:SetChecked(MTH_FX_GetFlag(cb.mthKey))
			if master then
				cb:Enable()
			else
				cb:Disable()
			end
		end
		i = i + 1
	end
end

function MTH_SetupAnimationsOptions()
	if not MTH_ANIM_READY then
		return
	end
	if type(MTH_FX_AnimationsEnabled) ~= "function" then
		return
	end

	local container = MTH_GetFrame("MetaHuntOptionsAnimations")
	if not container then
		return
	end

	local panel = MTH_Layout.Panel(container)
	panel:Title(MTH_ANIM_L("ANIM_TITLE", "Animations"))
	panel:Note(MTH_ANIM_L("ANIM_CREDIT",
		"Animations are powered by PizzaSauce, a WoW 1.12 animation library kindly made and shared by Pizzahawaii. Thank you!"),
		{ color = MTH_Layout.Theme.colText, lines = 2 })
	panel:Link("MetaHuntOptionsAnimLink", MTH_ANIM_LINK, function() MTH_ANIM_InsertLink(MTH_ANIM_LINK) end)

	MTH_ANIM_CTRL = {}

	-- Global master toggle (full width, above the columns).
	panel:TopCheckbox("MetaHuntOptionsAnimMaster",
		MTH_ANIM_L("ANIM_ENABLE_ALL", "Enable animations"), {
		checked = MTH_FX_AnimationsEnabled,
		onClick = function()
			local cb = getglobal("MetaHuntOptionsAnimMaster")
			MTH_FX_SetAnimationsEnabled(cb:GetChecked())
			MTH_ANIM_UpdateChildStates()
		end,
	})

	-- Keep the two columns balanced at standard Options-window sizes. The
	-- Interface section is intentionally paired with Pet instead of stacked
	-- below Leveling and Combat, where it would run below the window.
	local s = 1
	while MTH_FX_ANIM_SECTIONS and s <= table.getn(MTH_FX_ANIM_SECTIONS) do
		local sec = MTH_FX_ANIM_SECTIONS[s]

		-- Collect this section's defs in order.
		local secDefs = {}
		local d = 1
		while MTH_FX_ANIM_DEFS and d <= table.getn(MTH_FX_ANIM_DEFS) do
			local def = MTH_FX_ANIM_DEFS[d]
			if def.section == sec.id then
				table.insert(secDefs, def)
			end
			d = d + 1
		end
		local count = table.getn(secDefs)

		if count > 0 then
			local side = (sec.id == "pet" or sec.id == "ui") and "left" or "right"
			local box = panel:Box(side,
				"MetaHuntOptionsAnimBox_" .. tostring(sec.id),
				MTH_ANIM_L(sec.titleKey, sec.title))

			local di = 1
			while di <= count do
				local def = secDefs[di]
				local cbName = "MetaHuntOptionsAnim_" .. string.gsub(def.key, "%.", "_")
				local cb = box:Checkbox(cbName, MTH_ANIM_L(def.labelKey, def.label), {
					checked = function() return MTH_FX_GetFlag(def.key) end,
					tooltip = (def.tooltip and def.tooltip ~= "") and MTH_ANIM_L(def.tooltipKey, def.tooltip) or nil,
				})
				if cb then
					cb.mthKey = def.key
					cb:SetScript("OnClick", function()
						MTH_FX_SetFlag(cb.mthKey, cb:GetChecked())
					end)
					table.insert(MTH_ANIM_CTRL, cb)
				end
				di = di + 1
			end
		end
		s = s + 1
	end

	panel:Finish()
	MTH_ANIM_UpdateChildStates()
end
