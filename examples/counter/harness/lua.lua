local seed = tonumber(arg[1]) or 0
local n = tonumber(arg[2]) or 100
local x = (seed * 2654435761 + 1) & 0xFFFFFFFF
local function rnd()
  x = x ~ ((x << 13) & 0xFFFFFFFF)
  x = x ~ (x >> 17)
  x = x ~ ((x << 5) & 0xFFFFFFFF)
  return x
end
local names = { [0] = "add", "sub", "reset" }
local s = 0
for _ = 1, n do
  local op = rnd() % 3
  local a = rnd() % 100
  if op == 0 then s = math.min(s + a, 100) elseif op == 1 then s = math.max(s - a, 0) else s = 0 end
  print(names[op] .. " " .. a .. " " .. s)
end
