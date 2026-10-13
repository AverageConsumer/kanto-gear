return function(T, display, game, theme)
  local E = display.Evolutions
  local options = { format=string.format, itemName=function(id) return "ITEM:"..tostring(id) end,
    knownSpecies=function() return true end }
  local function one(generation, evo)
    local rows = E.rows({evolutions={evo}},generation,options)
    T.eq(#rows,1,"one native evolution remains one destination")
    return rows[1]
  end
  local row=one(1,{method="LEVEL",level=16,species="IVYSAUR"})
  T.eq(row.species,"IVYSAUR","Gen1 string target is preserved")
  T.same(row.conditions,{"LEVEL UP: LV.16+"},"Gen1 level threshold is from the active data")
  row=one(1,{method="ITEM",level=1,item="THUNDER_STONE",species="RAICHU"})
  T.same(row.conditions,{"USE ITEM:THUNDER_STONE"},"Gen1 stone row's unused level byte is not a condition")
  row=one(1,{method="TRADE",level=1,species="ALAKAZAM"})
  T.same(row.conditions,{"TRADE"},"Gen1 trade row's unused level byte is not a condition")
  row=one(2,{method="EVOLVE_TRADE",item="METAL_COAT",into="STEELIX"})
  T.same(row.conditions,{"TRADE","HOLDING ITEM:METAL_COAT"},"Gen2 held trade item is required")
  row=one(2,{method="EVOLVE_ITEM",item="SUN_STONE",into="BELLOSSOM"})
  T.same(row.conditions,{"USE ITEM:SUN_STONE"},"Gen2 item evolution is exempt from Everstone")
  for _,time in ipairs({"ANYTIME","MORNDAY","NITE"}) do
    row=one(2,{method="EVOLVE_HAPPINESS",time=time,into="NEXT"})
    T.eq(row.conditions[1],"LEVEL UP: FRIENDSHIP 220+","friendship requires a level-up, not just reaching the value")
    if time=="MORNDAY" then T.eq(row.conditions[2],"MORNING / DAY","Gen2 includes morning")
    elseif time=="NITE" then T.eq(row.conditions[2],"NIGHT","Gen2 night is explicit") end
  end
  for _,comparison in ipairs({"ATK_GT_DEF","ATK_EQ_DEF","ATK_LT_DEF"}) do
    row=one(2,{method="EVOLVE_STAT",level=20,comparison=comparison,into="NEXT"})
    T.eq(row.conditions[1],"LEVEL UP: LV.20+","Rabauz uses the actual level")
    T.check(row.conditions[2]:find("ATTACK",1,true)~=nil,"Rabauz shows its stat comparison")
  end
  local expected={"LEVEL UP: FRIENDSHIP 220+","LEVEL UP: FRIENDSHIP 220+","LEVEL UP: FRIENDSHIP 220+",
    "LEVEL UP: LV.20+","TRADE","TRADE","USE ITEM:20","LEVEL UP: LV.20+","LEVEL UP: LV.20+",
    "LEVEL UP: LV.20+","LEVEL UP: LV.20+","LEVEL UP: LV.20+","LEVEL UP: LV.20+",
    "LEVEL UP: LV.20+","LEVEL UP: BEAUTY 20+"}
  for method=1,15 do
    row=one(3,{method=method,param=20,target=2})
    T.eq(row.species,2,"Gen3 internal target ID is retained")
    T.eq(row.conditions[1],expected[method],"Gen3 method describes its actual trigger: "..method)
  end
  row=one(3,{method=14,param=20,target=303})
  T.eq(row.conditions[2],"EXTRA POKEMON AFTER EVOLVING","Shedinja is additional, not a replacement")
  T.eq(row.conditions[3],"EMPTY PARTY SLOT REQUIRED","Shedinja needs party space")
  for _,method in ipairs({11,12}) do
    row=one(3,{method=method,param=7,target=2})
    T.eq(row.conditions[2],"FORM FIXED BY PERSONALITY","Wurmple does not reroll when it evolves")
  end
  options.noClock=true;options.nationalAllows=function() return false end
  row=one(3,{method=2,param=0,target=196})
  T.check(row.blocked,"FRLG clocks and National Dex gates cannot look immediately available")
  T.check(table.concat(row.conditions," "):find("NO DAY/NIGHT CLOCK",1,true),"FRLG explains the absent clock")
  T.eq(row.conditions[#row.conditions],"NATIONAL DEX REQUIRED","FRLG National Dex is separate from friendship")
  options.noClock=false;options.nationalAllows=function() return true end
  row=one(3,{2,0,196})
  T.eq(row.blocked,false,"Emerald time evolution has no FRLG-specific gate")
  T.eq(row.conditions[2],"GAME CLOCK: 12:00-23:59","Gen3 uses its noon-to-midnight rule")
  options.knownSpecies=function() return false end
  row=one(2,{method="EVOLVE_LEVEL",level=16,into="NEXT"})
  T.eq(row.revealed,false,"unknown evolution forms obey the shared disclosure boundary")
  row=one(2,{method="CUSTOM",into="NEXT"})
  T.same(row.conditions,{"CONDITION NOT AVAILABLE"},"unknown methods never invent vanilla requirements")
  local rows,available=E.rows({evolutions={}},1,options)
  T.check(available and #rows==0,"explicit empty data means no further evolution")
  rows,available=E.rows({},1,options)
  T.check(not available and #rows==0,"missing data is not misreported as a final form")

  if display.gen3 then
    local data=display.gen3.data
    options.knownSpecies=function() return true end
    options.nationalAllows=nil
    local count=0
    for _,def in pairs(data.pokemon) do
      local native=E.rows(def,3,options)
      T.eq(#native,#(def.evolutions or {}),"every real native branch survives projection")
      for i,evo in ipairs(def.evolutions or {}) do
        local actual=native[i]
        T.eq(actual.species,evo.target or evo[3],"real native target is unchanged")
        T.check(data.pokemon[actual.species]~=nil,"internal target resolves in the active edition")
        T.check(actual.conditions[1]~="CONDITION NOT AVAILABLE","every vanilla native evolution method is supported")
        count=count+1
      end
    end
    T.check(count>150,"native verification covers the whole evolution table, not just starters")
    local path=assert(os.getenv("KANTO_GEAR_MOD_PATH"))
    local I18N=assert(loadfile(path.."/i18n/init.lua"))()
    options.itemName=function(id) return (data.items[id] or {}).name or "UNKNOWN ITEM" end
    options.noClock=not (display.gen3.profile.clock and display.gen3.profile.clock.rtc)
    options.nationalAllows=function() return false end
    for _,language in ipairs({"en","de"}) do
      local i18n=I18N.new(function(code) return assert(loadfile(path.."/i18n/catalogs/"..code..".lua"))() end,
        function() return language end)
      options.format=function(key,...) return i18n:format(key,...) end
      for _,def in pairs(data.pokemon) do
        for _,entry in ipairs(E.rows(def,3,options)) do
          local lines=0
          for _,condition in ipairs(entry.conditions) do
            lines=lines+#theme:descriptionLines(condition,34,nil,210)
          end
          T.check(lines<=7,"every native condition remains inside the centered card in "..language)
        end
      end
    end
  end
end
