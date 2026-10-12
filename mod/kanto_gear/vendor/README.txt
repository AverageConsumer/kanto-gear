luaqrcode by Patrick Gundlach and contributors
Source: https://github.com/speedata/luaqrcode
Pinned commit: 5a9c34bc04d5113048df8528af72ef31d25b7300
File: qrencode.lua, BSD-3-Clause license retained in its header.
Local change: replace the portable XOR lookup table with LuaJIT bit.bxor.
No network access occurs during QR generation.
