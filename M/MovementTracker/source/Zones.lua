ZONE_SIZES = {}

---@param zone string The name of the zone to get the size for
---@param in_dungeon boolean?
---@return number? width The width of the zone, or nil if not found
---@return number? height The height of the zone, or nil if not found
---@nodiscard
function ZONE_SIZES:get_size( zone, in_dungeon )
  local order = in_dungeon and { "dungeons", "zones", "entrances" } or { "zones", "entrances", "dungeons" }

  if self.data[ zone ] then
    return self.data[ zone ].width, self.data[ zone ].height
  end

  for _, continent_data in pairs( self.data ) do
    for _, type in order do
      if continent_data[ type ][ zone ] then
        local size = continent_data[ type ][ zone ]
        return size.width, size.height
      end
    end
  end

  return nil
end

---@return number? width The width of the current zone, or nil if not found
---@return number? height The height of the current zone, or nil if not found
---@nodiscard
function ZONE_SIZES:get_current_zone_size()
  _, _, self.current_zone = string.find( GetRealZoneText(), "^%s*(.-)%s*$" )
  self.current_continent = GetCurrentMapContinent() == 1 and "Kalimdor" or "Eastern Kingdoms"

  local width, height = self:get_size( self.current_zone, GetCurrentMapZone() == 1 )

  if not width then
    width, height = self:get_size( self.current_continent )
  end

  return width, height
end

ZONE_SIZES.data = {
  [ "Kalimdor" ] = {
    height = 24533.2,
    width = 36799.8,
    zones = {
      [ "Ashenvale" ] = {
        height = 3843.749877929687,
        width = 5766.66638183594,
      },
      [ "Azshara" ] = {
        height = 3381.2498779296902,
        width = 5070.8327636718695,
      },
      [ "The Barrens" ] = {
        height = 6756.24987792969,
        width = 10133.3330078125,
      },
      [ "Blackstone Island" ] = {
        height = 1665,
        width = 2472
      },
      [ "Caverns of Time" ] = {
        height = 888.09,
        width = 1348.24,
      },
      [ "Darkshore" ] = {
        height = 4366.66650390625,
        width = 6549.9997558593805,
      },
      [ "Darnassus" ] = {
        height = 705.7294921875,
        width = 1058.33325195312,
      },
      [ "Desolace" ] = {
        height = 2997.916564941411,
        width = 4495.8330078125,
      },
      [ "Durotar" ] = {
        height = 3524.9998779296902,
        width = 5287.49963378906,
      },
      [ "Dustwallow Marsh" ] = {
        height = 3499.99975585937,
        width = 5250.000061035156,
      },
      [ "Felwood" ] = {
        height = 3833.33325195312,
        width = 5749.99963378906,
      },
      [ "Feralas" ] = {
        height = 4633.3330078125,
        width = 6949.9997558593805,
      },
      [ "Hyjal" ] = {
        height = 2142,
        width = 3206,
      },
      [ "Moonglade" ] = {
        height = 1539.5830078125,
        width = 2308.33325195313,
      },
      [ "Mulgore" ] = {
        height = 3424.999847412109,
        width = 5137.49987792969,
      },
      [ "Orgrimmar" ] = {
        height = 935.41662597657,
        width = 1402.6044921875,
      },
      [ "Silithus" ] = {
        height = 2322.916015625,
        width = 3483.333984375,
      },
      [ "Stonetalon Mountains" ] = {
        height = 3256.2498168945312,
        width = 4883.33312988282,
      },
      [ "Tanaris" ] = {
        height = 4600.0,
        width = 6899.999526977539,
      },
      [ "Tel'Abim" ] = {
        height = 2187,
        width = 3227,
      },
      [ "Teldrassil" ] = {
        height = 3393.75,
        width = 5091.66650390626,
      },
      [ "Thousand Needles" ] = {
        height = 2933.3330078125,
        width = 4399.999694824219,
      },
      [ "Thunder Bluff" ] = {
        height = 695.833312988286,
        width = 1043.749938964844,
      },
      [ "Un'Goro Crater" ] = {
        height = 2466.66650390625,
        width = 3699.9998168945312,
      },
      [ "Winterspring" ] = {
        height = 4733.3332519531195,
        width = 7099.999847412109,
      },
    },
    dungeons = {
      [ "Dire Maul" ] = {
        height = 850,
        width = 1275,
      },
      [ "Emerald Sanctum" ] = {
        height = 853.72,
        width = 1273.1,
      },
      [ "Naxxramas" ] = {
        height = 1318.42,
        width = 1991.69,
      },
      [ "Maraudon" ] = {
        height = 1410.89,
        width = 2112.09,
      },
      [ "Onyxia's Lair" ] = {
        height = 322.08,
        width = 483.11,
      },
      [ "Razorfen Downs" ] = {
        height = 472.7,
        width = 709.05,
      },
      [ "Razorfen Kraul" ] = {
        height = 490.96,
        width = 736.45,
      },
      [ "The Black Morass" ] = {
        height = 845.48,
        width = 1271.99,
      },
      [ "Wailing Caverns" ] = {
        height = 785,
        width = 1170,
      },
    },
    entrances = {
      [ "Dire Maul" ] = {
        -- Uses continent size
      },
      [ "Maraudon" ] = {
        height = 550,
        width = 824,
      },
      [ "Razorfen Downs" ] = {
        -- Uses continent size
      },
      [ "Wailing Caverns" ] = {
        height = 381.85,
        width = 572.78,
      },
    },
  },
  [ "Eastern Kingdoms" ] = {
    height = 23466.6,
    width = 35199.9,
    zones = {
      [ "Alah'Thalas" ] = {
        height = 976,
        width = 1468,
      },
      [ "Alterac Valley" ] = {
        height = 1866.666656494141,
        width = 2799.999938964841,
      },
      [ "Arathi Highlands" ] = {
        height = 2399.99992370606,
        width = 3599.999877929687,
      },
      [ "Badlands" ] = {
        height = 1658.33349609375,
        width = 2487.5,
      },
      [ "Balor" ] = {
        height = 2068,
        width = 3098,
      },
      [ "Blackrock Mountain" ] = {
        height = 470,
        width = 710,
      },
      [ "Blasted Lands" ] = {
        height = 2233.333984375,
        width = 3349.9998779296902,
      },
      [ "Burning Steppes" ] = {
        height = 1952.08349609375,
        width = 2929.166595458989,
      },
      [ "Deadwind Pass" ] = {
        height = 1666.6669921875,
        width = 2499.999938964849,
      },
      [ "Deeprun Tram" ] = {
        height = 208,
        width = 312,
      },
      [ "Dun Morogh" ] = {
        height = 3283.33325195312,
        width = 4924.9997558593805,
      },
      [ "Duskwood" ] = {
        height = 1800.0,
        width = 2699.999938964841,
      },
      [ "Eastern Plaguelands" ] = {
        height = 2581.24975585938,
        width = 3870.83349609375,
      },
      [ "Elwynn Forest" ] = {
        height = 2314.5830078125,
        width = 3470.83325195312,
      },
      [ "Gillijim's Isle" ] = {
        height = 2047,
        width = 3092.1,
      },
      [ "Gilneas" ] = {
        height = 2442,
        width = 3666,
      },
      [ "Grim Reaches" ] = {
        height = 3584,
        width = 5387,
      },
      [ "Hilsbrad Foothills" ] = {
        height = 2133.33325195313,
        width = 3199.9998779296902,
      },
      [ "The Hinterlands" ] = {
        height = 2566.6666259765598,
        width = 3850.0,
      },
      [ "Ironforge" ] = {
        height = 527.6044921875,
        width = 790.625061035154,
      },
      [ "Lapidis Isle" ] = {
        height = 1915.9,
        width = 2901.45,
      },
      [ "Loch Modan" ] = {
        height = 1839.5830078125,
        width = 2758.3331298828098,
      },
      [ "Northwind" ] = {
        height = 2157,
        width = 3241,
      },
      [ "Redridge Mountains" ] = {
        height = 1447.916015625,
        width = 2170.83325195312,
      },
      [ "Scarlet Enclave" ] = {
        height = 2108,
        width = 3159,
      },
      [ "Searing Gorge" ] = {
        height = 1487.49951171875,
        width = 2231.249847412109,
      },
      [ "Silverpine Forest" ] = {
        height = 2799.9998779296902,
        width = 4199.9997558593805,
      },
      [ "Stormwind City" ] = {
        height = 1158.34,
        width = 1737.5,
      },
      [ "Stranglethorn Vale" ] = {
        height = 4254.166015625,
        width = 6381.2497558593805,
      },
      [ "Swamp of Sorrows" ] = {
        height = 1529.1669921875,
        width = 2293.75,
      },
      [ "Thalassian Highlands" ] = {
        height = 2061,
        width = 3082,
      },
      [ "Tirisfal Glades" ] = {
        height = 3012.499816894536,
        width = 4518.74987792969,
      },
      [ "Undercity" ] = {
        height = 640.10412597656,
        width = 959.3750305175781,
      },
      [ "Western Plaguelands" ] = {
        height = 2866.666534423828,
        width = 4299.999908447271,
      },
      [ "Westfall" ] = {
        height = 2333.3330078125,
        width = 3499.9998168945312,
      },
      [ "Wetlands" ] = {
        height = 2756.25,
        width = 4135.416687011719,
      },
    },
    dungeons = {
      [ "Blackrock Depths" ] = {
        height = 938.04,
        width = 1407.06,
      },
      [ "Blackrock Spire" ] = {
        height = 595,
        width = 885,
      },
      [ "Blackwing Lair" ] = {
        height = 332.95,
        width = 499.43,
      },
      [ "Dragonmaw Retreat" ] = {
        height = 1073,
        width = 1634,
      },
      [ "Gnomeregan" ] = {
        height = 513.11,
        width = 769.67,
      },
      [ "Molten Core" ] = {
        height = 843.2,
        width = 1264.8,
      },
      [ "Scarlet Monastery" ] = {
        height = 408.46,
        width = 612.69,
      },
      [ "Scarlet Monastery Cathedral" ] = {
        height = 468.87,
        width = 703.3,
      },
      [ "Scarlet Monastery Graveyard" ] = {
        height = 413.32,
        width = 619.98,
      },
      [ "Scarlet Monastery Library" ] = {
        height = 213.46,
        width = 320.19,
      },
      [ "Stormwrought Ruins" ] = {
        height = 1350,
        width = 1980,
      },
      [ "Stratholme" ] = {
        height = 789.86,
        width = 1185.35,
      },
      [ "The Deadmines" ] = {
        height = 434.97,
        width = 656.59,
      },
    },
    entrances = {
      [ "Gnomeregan" ] = {
        height = 379.4,
        width = 571.19,
      },
      [ "Scarlet Monastery" ] = {
        height = 135.04,
        width = 203.66,
      },
      [ "The Deadmines" ] = {
        height = 300,
        width = 449.89,
      }
    }
  },
}

return ZONE_SIZES
