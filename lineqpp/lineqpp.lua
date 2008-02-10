-- Say something about error messages

-- message level

local level = 0

local function err(msg)
   error(msg, level)
end

-- Say something about verbose

local function display(s)
   return io.stderr:write(s)
end

-- Real numbers

local tol = 1.0e-6

local function is_zero(x)
   return math.abs(x) < tol
end

-- Replace numbers close to zero with zero.
local function zero(x)
   if is_zero(x) then
      return 0
   else
      return x
   end   
end

-- Complex numbers

local Complex = {}
Complex.__index = Complex

local function complex(x, y)
   return setmetatable({r = x, i = y or 0}, Complex)
end

-- A simple distance metric that is quick to compute
function Complex.mag(z)
   return math.max(math.abs(z.r), math.abs(z.i))
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
function Complex.__pow(z1, z2)
   err("exponention is broken")
end

-- To string method

function Complex.__tostring(z)
   local function imaginary_tostring(z)
      if is_zero(z.i - 1) then
	 return "i"
      else
	 return z.i..'*i'
      end
   end
   if is_zero(z.i) then
      return tostring(zero(z.r))
   elseif is_zero(z.r) then
      return imaginary_tostring(z)
   elseif is_zero(z.i + 1) then
      return z.r..' - i'
   else
      return z.r..' + '..imaginary_tostring(z)
   end
end

-- Is a sum required to print this number?
function Complex.is_sum(z)
   return not is_zero(z.r) and not is_zero(z.i)
end

-- Mathematical functions

-- The func table maps strings to functions that take a complex number
-- and produce one.

local func = {}

-- Translation table

local translation = {}

local function solved(v, z)
   translation[v.."#r"] = tostring(zero(z.r));
   translation[v.."#i"] = tostring(zero(z.i)));
end

function translate(s)
   return translation[s]
end

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

local function linear(c, ts)
   return setmetatable({c = c, ts = ts or {}}, Linear)
end

-- Delete linear terms with zero coefficients
function Linear.simplify(p)
   local a = {}			-- Collect terms to be deleted
   for v, c in pairs(p.ts) do
      if c:is_zero() then
	 a[#a + 1] = v
      end
   end
   for i in ipairs(a) do	-- Delete collected terms
      p.ts[a[i]] = nil
   end
end

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

function Linear.__add(p1, p2)
   local ts = {}
   for v1, c1 in pairs(p1.ts) do
      ts[v1] = c1
   end
   for v2, c2 in pairs(p2.ts) do
      local c1 = ts[v2]
      if c1 then
	 ts[v2] = c1 + c2
      else
	 ts[v2] = c2
      end
   end
   return linear(p1.c + p2.c, ts)
end
   
function Linear.__sub(p1, p2)
   local ts = {}
   for v1, c1 in pairs(p1.ts) do
      ts[v1] = c1
   end
   for v2, c2 in pairs(p2.ts) do
      local c1 = ts[v2]
      if c1 then
	 ts[v2] = c1 - c2
      else
	 ts[v2] = -c2
      end
   end
   return linear(p1.c - p2.c, ts)
end

function Linear.__umn(p)
   local ts = {}
   for v, c in pairs(p.ts) do
      ts[v] = -c
   end
   return linear(-p.c, ts)
end

function Linear.__mul(p1, p2)
   local c1 = p1:number()
   if not c1 then
      c1 = p2:number()
      if not c1 then
	 err("both in product not a number")
      else
	 p2 = p1
      end
   end
   local ts = {}
   for v2, c2 in pairs(p2.ts) do
      ts[v2] = c1 * c2
   end
   return linear(c1 * p2.c, ts)
end

function Linear.__div(p1, p2)
   local c2 = p2:number()
   if not c2 then
      err("dividend is not a number")
   end
   if is_zero(c2) then
      c2 = tol
   end
   return linear(complex(1) / c2) * p1
end

function Linear.__pow(p1, p2)
   local c1, c2 = p1:number(), p2:number()
   if not c1 then
      err("exponent base not a number") -- FIX ME
   elseif not c2 then
      err("exponent not a number")
   else
      return linear(c1 ^ c2)
   end
end

function Linear.subst(p1, v1, p2, v2)
   local c1 = p1.ts[v2]
   if not c1 then
      return p1
   else
      p1.ts[v2] = nil
      p1 = p1 + linear(c1) * p2
      p1:simplify()
      if verbose then
	 display(v1.." is "..tostring(p1).."\n")
      end
      c1 = p1:number()
      if c1 then
	 solved(v1, c1)
      end
      return p1
   end
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

local function solve(p)
   p:simplify()
   local c = p:number()
   if c then
      if c:is_zero() then
	 err("redundant equation")
      else
	 err("inconsistent equation")
      end
   end
   local m_max, v_max, c_max = 0
   for v, c in pairs(p.ts) do
      local m = c:mag()
      if m > m_max then
	 m_max, v_max, c_max = m, v, c
      end
   end
   p.ts[v_max] = nil
   c_max = complex(-1) / c_max
   p = linear(c_max) * p
   p:simplify()
   if verbose then
      display(v_max.." is "..tostring(p).."\n")
   end
   c = p:number()
   if c then
      solved(v_max, c)
   end
   for ve, pe in pairs(env) do
      env[ve] = pe:subst(ve, p, v_max)
   end
   env[v_max] = p
end   

function variable(var)
   local val = env[var]
   if val then
      return val
   else
      return linear(complex(0), {[var] = complex(1)})
   end
end

function number(x, y)
   return linear(complex(x, y))
end

env.i = number(0, 1)

function application(fun, arg)
   local var = fun:variable()
   local val = func[var]
   local num = arg:number()
   if not var then
      err("function not well formed")
   elseif not val then
      err("function "..var.." not defined")
   elseif not num then
      err("function "..var.." not applied to a number")
   else
      return linear(val(num))
   end
end

-- x [y, z] = y + t * (z - y)
function mediation(scale, left, right)
   return left + scale * (right - left)
end

function sum(left, right)
   return left + right
end

function difference(left, right)
   return left - right
end

function product(left, right)
   return left * right
end

function quotient(left, right)
   return left / right
end

function negation(arg)
   return -arg
end

function exponentiation(left, right)
   return left ^ right
end

function equation(left, right)
   if verbose then
      left:simplify()
      right:simplify()
      display(tostring(left).." = "..tostring(right).."\n")
   end
   solve(left - right)
   return right
end
