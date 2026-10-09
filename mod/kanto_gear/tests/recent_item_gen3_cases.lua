return function(T,run,display,raw)
  local ItemUse=require("src.core.game3.item_use")
  local Runtime=require("src.core.game3.runtime")
  local nativeGame=Runtime._game;Runtime._game=raw
  local Bag=require("src.core.game3.bag")
  local Items=require("src.core.game3.items_data")
  local Menu=require("src.ui.game3.bag_menu")
  local Party=require("src.ui.game3.party_menu")
  local Stack=require("src.ui.game3.stack")
  local Message=require("src.ui.game3.message")
  local originalInput=raw.input
  raw.input={pressQueue={},sourcePress=function(self,key) self.pressQueue[#self.pressQueue+1]=key end,sourceRelease=function() end}
  local session=raw.session
  local potion,restore=Items.toNumericId("POTION"),Items.toNumericId("FULL_RESTORE")
  local mon=session.party[1]
  local hp=mon.hp
  Bag.add(session.bag,potion,3);Bag.add(session.bag,restore,2)
  display.gen3:refresh();display.recentItem:bind(display.gen3.save)
  mon.hp=1
  local ok,kind=ItemUse.useField(session,session.bag,potion,1)
  T.check(ok,"native Gen3 potion succeeds through the registered hook")
  T.eq(display.lastBagItem() and display.lastBagItem().id,potion,
    "native Gen3 numeric item IDs produce a usable shortcut")
  mon.hp=mon.maxHp
  local left=display.gen3.save.inventory[restore]
  ok=ItemUse.useField(session,session.bag,restore,1)
  T.eq(ok,false,"native Gen3 full-HP medicine refuses without side effects")
  T.eq(display.gen3.save.inventory[restore],left,"a refused use preserves inventory")
  T.eq(display.lastBagItem().id,potion,"refused Gen3 use preserves successful history")
  Party.close();Menu.close();Stack.clear();Message.reset()
  Menu.show(session.bag,{session=session,pocket="POKE_BALLS"});Menu.settle()
  display.gen3.syncScreens()
  local view=display.startMenu()
  T.check(view and view.recentBag,"native bag list offers the last item across pockets")
  T.check(display.selectRecentBagItem(view),"quick access selects an item in another native pocket")
  T.eq(#raw.input.pressQueue,1,"one explicit shortcut tap queues one native confirmation")
  T.eq(Menu.currentPocket(),"ITEMS","shortcut changes to the correct native pocket")
  T.eq(Items.toNumericId(Menu.list()[Menu.cursor].id),potion,"shortcut targets the exact native item")
  display.gen3.syncScreens();view=display.startMenu()
  local model=display.StartMenu.model(view)
  T.eq(model.entries[1].y,70,"native item rows leave room for quick access")
  T.eq(display.StartMenu.hit(view,20,78),model.first,"native item draw and hit geometry agree")
  T.check(pcall(display.drawContents),"native bag with recent item renders")
  local short={screenId="StartMenu",startCloses=true,update=function() end,index=1,
    recentBag=view.recentBag,items={}}
  for i=1,5 do short.items[i]={label="ITEM "..i} end
  local shortModel=display.StartMenu.model(short)
  T.eq(#shortModel.entries,4,"five-row bags reserve one row for quick access")
  T.eq(display.StartMenu.hit(short,200,200),"next","the fifth item stays reachable")
  local theme
  for i=1,100 do
    local name,value=debug.getupvalue(display.drawContents,i)
    if not name then break end
    if name=="THEME" then theme=value.hgss break end
  end
  assert(theme)
  local pager=theme.menuPager;local drawn=false
  theme.menuPager=function() drawn=true end
  theme:startMenu(shortModel);theme.menuPager=pager
  T.check(drawn,"five-row bags visibly offer the next-page control")
  display.recentItem.pending=nil
  display.observeBagInput()
  T.eq(display.recentItem.pending and display.recentItem.pending.id,potion,
    "native bag observation normalizes item IDs for battle consumption")
  local input={wasPressed=function(_,key) return key=="a" end,isDown=function() return false end}
  Menu.handleInput(input)
  T.eq(Menu.mode,"action","shortcut confirmation opens the native item actions")
  T.eq(Menu.ACTIONS[Menu.actionCursor],"USE","shortcut retains native use and target selection")
  Menu.mode="list";Menu._location="itempc";display.gen3.syncScreens()
  T.eq(display.startMenu().recentBag,nil,"deposit lists never offer the use shortcut")
  display.observeBagInput()
  T.eq(display.recentItem.pending,nil,"deposit input cannot be mistaken for item use")
  Menu._location="shop";display.observeBagInput()
  T.eq(display.recentItem.pending,nil,"selling input cannot be mistaken for item use")
  Menu._location=nil
  local output={run.loader.hooks:call("item.use",function() return false,"sentinel",nil,4,nil,6 end,raw,nil,potion)}
  T.eq(output[2],"sentinel","observer preserves native item result kind")
  T.eq(output[4],4,"observer preserves return values beyond the normal item API")
  T.eq(output[6],6,"observer preserves holes and trailing return values")
  -- A cancelled/failed attempt followed by TOSS must not be recorded.
  display.recentItem:watch(display.gen3.save,restore)
  Menu.mode,Menu.ACTIONS,Menu.actionCursor="action",{"USE","TOSS"},2
  display.observeBagInput()
  Bag.remove(session.bag,restore,1);display.gen3:refresh()
  display.recentItem:poll(display.gen3.save)
  T.eq(display.lastBagItem().id,potion,"discarding an item never overwrites last use")
  Party.close();Menu.close();Stack.clear();Message.reset();mon.hp=hp
  assert(loadfile(os.getenv("KANTO_GEAR_MOD_PATH") .. "/tests/bag_actions_gen3_cases.lua"))()(T,run,display,raw)
  assert(loadfile(os.getenv("KANTO_GEAR_MOD_PATH") .. "/tests/shop_gen3_cases.lua"))()(T,display,raw)
  assert(loadfile(os.getenv("KANTO_GEAR_MOD_PATH") .. "/tests/pc_items_gen3_cases.lua"))()(T,display,raw)
  Runtime._game=nativeGame;raw.input=originalInput
end
