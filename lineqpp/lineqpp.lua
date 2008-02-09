

local function display(s)
   if verbose then
      return io.stderr:write(s)
   end
end

local function show(t)
   if type(t) == "table" and not getmetatable(t) then
      if #t == 0 then
	 return display("()")
      end
      display("(")
      for i = 1, #t - 1 do
	 show(t[i])
	 display(" ")
      end
      show(t[#t])
      return display(")")
   else 
      return display(tostring(t))
   end
end

-- Real numbers

local function is_zero(x)
   local tol = 1.0e-6
   if x < 0 then
      return x > -tol
   else
      return x < tol
   end
end

-- Complex numbers

local Complex = {}
Complex.__index = Complex

local function complex(x, y)
   return setmetatable({r = x, i = y or 0}, Complex)
end

function Complex.is_zero(z)
   return is_zero(z.r) and is_zero(z.i)
end

function Complex.is_one(z)
   return is_zero(z.r - 1) and is_zero(z.i)
end

function Complex.__eq(z1, z2)
   return is_zero(z1.r - z2.r) and is_zero(z1.i - z2.i)
end

function Complex.__add(z1, z2)
   return complex(z1.r + z2.r, z1.i + z2.i)
end

function Complex.__sub(z1, z2)
   return complex(z1.r - z2.r, z1.i - z2.i)
end

function Complex.__unm(z)
   return complex(-z.r, -z.i)
end

function Complex.__mul(z1, z2)
   local x1, y1, x2, y2 = z1.r, z1.i, z2.r, z2.i
   return complex(x1 * x2 - y1 * y2,
		  y1 * x2 + x1 * y2)
end

function Complex.__div(z1, z2)
   local x1, y1, x2, y2 = z1.r, z1.i, z2.r, z2.i
   local sq = x2 * x2 + y2 * y2
   return complex((x1 * x2 + y1 * y2) / sq,
		  (y1 * x2 + x1 * y2) / sq)
end

-- __pow should at least support squaring.

-- Printing

function Complex.imaginary_tostring(z)
   if is_zero(z.i - 1) then
      return "i"
   else
      return z.i..'*i'
   end
end

function Complex.__tostring(z)
   if is_zero(z.i) then
      return tostring(z.r)
   elseif is_zero(z.r) then
      return z:imaginary_tostring()
   elseif is_zero(z.i + 1) then
      return z.r..' - i'
   else
      return z.r..' + '..z:imaginary_tostring()
   end
end

function Complex.is_sum(z)
   return not is_zero(z.r) and not is_zero(z.i)
end

-- Mathematical functions

-- The func table maps strings to functions that take a complex number
-- and produce one.

local func = {}

-- Linear polynomials (polynomials with degree one or zero)

-- The linear polynomial data structure has two fields.  The c field
-- contains the constant term.  The ts field contains the linear terms
-- represented as a table that maps each variable to its coefficient.
-- Thus
--
--     x + 2*y + 3   --->   {c = 3, ts = {x = 1, y = 2}}
--
-- Though real numbers are shown above, complex numbers are used.

local Linear = {}
Linear.__index = Linear

-- Compute the number of entries in a table
local function size(t)
   local n = 0
   for k in pairs(t) do
      n = n + 1
   end
   return n
end

-- If p is a constant, return the number, otherwise return false.
function Linear.number(p)
   return size(p.ts) == 0 and p.c
end

-- If p is a variable, return the variable, otherwise return false.
function Linear.variable(p)
   if p.c:is_zero() and size(p.ts) == 1 then
      for v, c in pairs(p.ts) do
	 if c:is_one() then
	    return v
	 end
      end
   end
   return false
end

-- Sorted pairs iterator from PIL 2nd Ed, pg. 173.
local function sorted_pairs(t)
   local a = {}			-- array of keys
   for k in pairs(t) do a[#a + 1] = k end
   table.sort(a)
   local i = 0			-- iterator variable
   return function()		-- iterator function
	     i = i + 1
	     return a[i], t[a[i]]
	  end
end

function Linear.__tostring(p)
   local buf = ""
   if not p.c:is_zero() then
      buf = " + "..tostring(p.c)
   end
   for v, c in sorted_pairs(p.ts) do
      if c:is_one() then
	 buf = buf.." + "..v
      elseif not c:is_zero() then
	 if c:is_sum() then
	    buf = buf.." + ("..tostring(c)..')*'..v
	 else
	    buf = buf.." + "..tostring(c)..'*'..v
	 end
      end
   end
   if buf:len() > 3 then
      return buf:sub(4)		-- Dump leading " + "
   else
      return "0"
   end
end

-- The enviroment maps variables to linear polynomials

local env = {}

function variable(var)
   local val = env[var]
   if val then
      return val
   else
      local p = {c = complex(0), ts = {[var] = complex(1)}}
      return setmetatable(p, Linear)
   end
end

function number(x, y)
   local p = {c = complex(x, y), ts = {}}
   return setmetatable(p, Linear)
end

env.i = number(0, 1)

function application(fun, arg)
   local var = fun:variable()
   local val = func[var]
   local num = arg:number()
   if not var then
      error("function not well formed")
   elseif not val then
      error("function "..var.." not defined")
   elseif not num then
      error("function "..var.." not applied to a number")
   else
      local ans = val(num)
      return number(ans.r, ans.i)
   end
end

-- x [y, z] = y + t * (z - y)
function mediation(scale, left, right)
   return {"med", scale, left, right}
end

function sum(left, right)
   return {"plus", left, right}
end

function difference(left, right)
   return {"sub", left, right}
end

function product(left, right)
   return {"mul", left, right}
end

function quotient(left, right)
   return {"div", left, right}
end

function negation(arg)
   return {"neg", arg}
end

function exponentiation(left, right)
   return {"exp", left, right}
end

function equation(left, right)
   show(left)
   display("\n")
   show(right)
   display("\n\n")
   return right
end

function translate(s)
   return nil
end

-- Debuging hacks

cpx = complex
var = variable
num = number

