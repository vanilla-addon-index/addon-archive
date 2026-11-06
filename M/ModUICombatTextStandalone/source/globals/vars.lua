

    local f = CreateFrame('Frame', 'ct_vars', UIParent)

    -- usage:         _G['ct_vars'].db['name']

    local default = {

        ['ctSCTDMG']             = 0,
        ['ctSCTHEAL']            = 0
    }

    -- this function copies values from one table into another:
    local initDB = function(db, defaults)
		if type(db) ~= 'table' then db = {} end
		if type(defaults) ~= 'table' then return db end
		for k, v in pairs(defaults) do
			if type(v) == 'table' then
				db[k] = initDB(db[k], v)
			elseif type(v) ~= type(db[k]) then
				db[k] = v
			end
		end
		return db
	end

    f:RegisterEvent'PLAYER_LOGIN'
    f:SetScript('OnEvent', function()
        CT_VARS = initDB(CT_VARS, default)
    	f.db = CT_VARS
    end)

    --
