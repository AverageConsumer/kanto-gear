local root=os.getenv("KANTO_GEAR_MOD_PATH") or "mod/kanto_gear"
local I18N=assert(loadfile(root.."/i18n/init.lua"))()
local keys={"ACCEPT","DECLINE","GO BUSY","GO READY","INVITATION SENT","INVITATION CLOSED",
  "BATTLE INVITATION","TRADE INVITATION","ACCEPT TO OPEN LINK SETUP","FINISH YOUR CURRENT ACTION",
  "SET YOUR STATUS TO READY","PLAYER NOT READY","LINK SESSION OPEN","YOU CAN KEEP PLAYING",
  "TRADE COMPLETE","ONLINE PLAY UNAVAILABLE","RECOMP BLOCKS UI MODS","INVITES REQUIRE RECOMP SUPPORT."}
local checks=0
for _,code in ipairs({"de","es","fr","ja","it"}) do
  local i18n=I18N.new(function(lang) return assert(loadfile(root.."/i18n/catalogs/"..lang..".lua"))() end,
    function() return code end)
  local catalog=assert(loadfile(root.."/i18n/catalogs/"..code..".lua"))()
  for _,key in ipairs(keys) do
    assert(catalog[key]==false or type(catalog[key])=="string" and catalog[key]~="",
      "missing translation or explicit fallback in "..code..": "..key)
    assert(i18n:text(key)==(catalog[key] or key),"label resolves in "..code..": "..key)
    checks=checks+2
  end
end
print("Silph Connect localization: "..checks.." checks passed")
