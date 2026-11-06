local Addon = ForgedPetHappiness or {}
ForgedPetHappiness = Addon

local PET_FAMILY_DIET_FALLBACK = {
    ["Bat"] = "Fruit, Fungus",
    ["Bear"] = "Bread, Cheese, Fish, Fruit, Fungus, Meat",
    ["Boar"] = "Bread, Fruit, Fungus",
    ["Carrion Bird"] = "Meat",
    ["Cat"] = "Fish, Meat",
    ["Core Hound"] = "Meat",
    ["Crab"] = "Fish",
    ["Crocolisk"] = "Fish, Meat",
    ["Gorilla"] = "Fruit, Fungus",
    ["Hyena"] = "Meat",
    ["Owl"] = "Meat",
    ["Raptor"] = "Meat",
    ["Scorpid"] = "Meat",
    ["Spider"] = "Meat",
    ["Tallstrider"] = "Fruit, Fungus",
    ["Turtle"] = "Fish, Fruit",
    ["Wind Serpent"] = "Bread, Cheese, Fish",
    ["Wolf"] = "Meat",
}

function Addon.GetPetDietTooltipText()
    if not UnitExists("pet") then
        return "No active pet"
    end

    if not GetPetFoodTypes then
        local family = UnitCreatureFamily and UnitCreatureFamily("pet") or nil
        return (family and PET_FAMILY_DIET_FALLBACK[family]) or "Unknown"
    end

    local result = { GetPetFoodTypes() }
    local foodTypes = nil

    if table.getn(result) == 1 and type(result[1]) == "table" then
        foodTypes = result[1]
    else
        foodTypes = result
    end

    if type(foodTypes) ~= "table" or table.getn(foodTypes) == 0 then
        local family = UnitCreatureFamily and UnitCreatureFamily("pet") or nil
        return (family and PET_FAMILY_DIET_FALLBACK[family]) or "Unknown"
    end

    local foods = ""
    for i = 1, table.getn(foodTypes) do
        local food = foodTypes[i]
        if type(food) == "string" and food ~= "" then
            if foods == "" then
                foods = food
            else
                foods = foods .. ", " .. food
            end
        end
    end

    if foods == "" then
        local family = UnitCreatureFamily and UnitCreatureFamily("pet") or nil
        return (family and PET_FAMILY_DIET_FALLBACK[family]) or "Unknown"
    end

    return foods
end