-- Real Windows/POSIX OS entropy and independently decodable QR payloads.
local root = os.getenv("KANTO_GEAR_MOD_PATH") or "mod/kanto_gear"
local function read(file) local f = assert(io.open(root .. "/" .. file, "rb")); local s=f:read("*a");f:close();return s end
local worker = assert(loadstring(read("phone/pairing_worker.lua")))
local output, requests = {}, { "http://192.168.1.35:8765", "http://192.168.1.35:8765", false }
worker({ demand = function() return table.remove(requests,1) end },
  { push = function(_,result) output[#output+1]=result end }, read("vendor/qrencode.lua"))
assert(#output==2 and not output[1].error and not output[2].error)
assert(output[1].secret ~= output[2].secret and #output[1].secret==32)
assert(output[1].pin:match("^%d%d%d%d%d%d%d%d$") and output[1].pin ~= output[2].pin)
assert(output[1].url == "http://192.168.1.35:8765", "worker results identify the address encoded in their QR")
local q=output[1];local f=assert(io.open("diagnostics/pairing-qr.pgm","wb"))
local scale, width=8,(q.size+8)*8
f:write("P5\n"..width.." "..width.."\n255\n")
local pixels={};for i=1,width*width do pixels[i]="\255" end
for _,run in ipairs(q.runs) do for y=(run[2]+4)*scale,(run[2]+5)*scale-1 do
  for x=(run[1]+4)*scale,(run[1]+4+run[3])*scale-1 do pixels[y*width+x+1]="\0" end
end end
f:write(table.concat(pixels));f:close()
f=assert(io.open("diagnostics/pairing-qr.txt","w"));f:write("http://192.168.1.35:8765/#pair="..q.secret);f:close()
local denied
local fail = assert(loadstring(read("phone/pairing_worker.lua")))
setfenv(fail,setmetatable({ require=function() error("FFI unavailable") end }, {__index=_G}))
fail({}, { push=function(_,value) denied=value end }, read("vendor/qrencode.lua"))
assert(denied and denied.error and not denied.secret, "missing OS entropy fails closed")
local channels={}
local Pairing=assert(loadstring(read("phone/pairing.lua")))()
local pairing=Pairing.new({read=function() return "worker source" end},{thread={
  newThread=function() return {start=function() end,getError=function() end} end,
  newChannel=function()
    local channel={values={}}
    function channel:push(value) self.values[#self.values+1]=value end
    function channel:clear() self.values={} end
    function channel:pop() return table.remove(self.values,1) end
    channels[#channels+1]=channel;return channel
  end,
}})
pairing:request("old address");channels[2]:push(output[1]);pairing:request("new address")
assert(#channels[1].values==1 and channels[1].values[1]=="new address" and #channels[2].values==0,
  "network changes retain only the newest queued pairing request and discard completed stale results")
pairing:stop()
print("PASS OS entropy, independent credentials and cached QR geometry")
