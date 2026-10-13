return function(T, path)
  local Recent = assert(loadfile(path .. "/core/recent_item.lua"))()
  local bucket, writes = {}, 0
  local store = { get=function(_,k) return bucket[k] end,
    set=function(_,k,v) bucket[k]=v;writes=writes+1 end }
  for _, id in ipairs({ "POTION", 13 }) do
    local save = { inventory = { [id]=3, OTHER=4 } }
    local r = Recent.new(store);r:bind(save)
    T.eq(r:available(save),nil,"a new playthrough starts without a shortcut")
    r:watch(save,id);r:poll(save)
    T.eq(r:available(save),nil,"selecting/cancelling or refusing an item is not successful use")
    save.inventory.OTHER=3;r:poll(save)
    T.eq(r:available(save),nil,"another stack changing does not count as using this item")
    save.inventory[id]=2
    T.check(r:poll(save),"confirmed native consumption records string and numeric item IDs")
    T.eq(r:available(save),id,"shortcut offers the confirmed item")
    local before=writes;r:poll(save)
    T.eq(writes,before,"unchanged inventory performs no save writes")
    r:watch(save,id);save.inventory[id]=1;r:poll(save)
    T.eq(writes,before,"repeating the same item does not rewrite history")
    save.inventory[id]=nil
    T.eq(r:available(save),nil,"a used-up or deposited stack disappears immediately")
    save.inventory[id]=1
    T.eq(r:available(save),id,"a restocked last item becomes available again")
    local reloaded=Recent.new(store);reloaded:bind(save)
    T.eq(reloaded:available(save),id,"the last item survives reloading the same save")
    r:watch(save,id)
    local other={inventory={[id]=1}}
    T.eq(r:poll(other),false,"save changes never look like consumption")
    T.eq(r:available(other),nil,"a previous save's shortcut never leaks into another")
    r:watch(save,id);save.inventory={ [id]=0 }
    T.eq(r:poll(save),false,"replacing the entire inventory is not consumption")
    bucket={}
  end
end
