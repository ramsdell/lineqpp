-- Complex numbers

-- Copyright (C) 2008 John D. Ramsdell
-- This software is covered by the MIT License

-- Reference: "Introduction to Complex Variables and Applications",
-- Ruel V. Churchill, McGraw-Hill Book Company, Inc, 1949.

module("complex", package.seeall)

local Complex = {}		-- The complex number metatable
Complex.__index = Complex

function complex(x, y)		-- The complex number constructor
   return setmetatable({x = x, y = y or 0}, Complex)
end

function Complex.__eq(z1, z2)
   return z1.x == z2.x and z1.y == z2.y
end

function Complex.__add(z1, z2)
   return complex(z1.x + z2.x, z1.y + z2.y)
end

function Complex.__sub(z1, z2)
   return complex(z1.x - z2.x, z1.y - z2.y)
end

function Complex.__unm(z)
   return complex(-z.x, -z.y)
end

function Complex.__mul(z1, z2)
   local x1, y1, x2, y2 = z1.x, z1.y, z2.x, z2.y
   return complex(x1 * x2 - y1 * y2,
		  x1 * y2 + x2 * y1)
end

function Complex.__div(z1, z2)
   local x1, y1, x2, y2 = z1.x, z1.y, z2.x, z2.y
   local sq = x2 * x2 + y2 * y2
   return complex((x1 * x2 + y1 * y2) / sq,
		  (x2 * y1 - x1 * y2) / sq)
end

function Complex.__pow(z1, z2)
   if not z2.y == 0 then
      error("exponent must be real", 0)
   else
      return (z1:log() * z2):exp()
   end
end

function Complex.conj(z)
   return complex(z.x, -z.y)
end

function Complex.abs(z)
   local x, y = z.x, z.y
   return complex(math.sqrt(x * x + y * y))
end

function Complex.exp(z)
   local x, y = z.x, z.y
   local r = math.exp(x)
   return complex(r * math.cos(y), r * math.sin(y))
end

function Complex.log(z)
   local x, y = z.x, z.y
   local r2 = x * x + y * y
   return complex(0.5 * math.log(r2), math.atan2(y, x))
end

function Complex.cos(z)
   local x, y = z.x, z.y
   return complex(math.cos(x) * math.cosh(y), 
		  -math.sin(x) * math.sinh(y))
end

function Complex.sin(z)
   local x, y = z.x, z.y
   return complex(math.sin(x) * math.cosh(y), 
		  math.cos(x) * math.sinh(y))
end

-- To string method

function Complex.__tostring(z)
   local function imaginary_tostring(z)
      if z.y == 1 then
	 return "i"
      else
	 return z.y..'*i'
      end
   end
   if z.y == 0 then
      return tostring(z.x)
   elseif z.x == 0 then
      return imaginary_tostring(z)
   elseif z.y == -1 then
      return z.x..' - i'
   else
      return z.x..' + '..imaginary_tostring(z)
   end
end

-- Is a sum required to print this number?
function Complex.is_sum(z)
   return not z.x == 0 and not z.y == 0
end

--[[
The MIT License

Copyright (C) 2008 John D. Ramsdell

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
]]
