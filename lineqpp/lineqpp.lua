--[[ 

Equation solver for the Linear Equation Preprocessor
Copyright (C) 2008 John D. Ramsdell
This software is covered by the MIT Open Source License

This file contains the linear equation solver used to derive
substitutions for variables found by the preprocessor.  The first
section implements complex numbers.  The second section implements
linear polynomials.  The third section contains the solver and the
functions used by the parser to construct linear polynomials.

The program maintains an association between each dependent variable
and the linear polynomial of independent variables that defines the
variable.  Usually, upon solving an equation from the input, a new
dependent variable and its linear polynomial is added, and occurrences
of the variable as an independent variable in other linear polynomials
is replaced by the new dependency.  Dependent variables defined by a
constant polynomial are candidates for substitution by the
preprocessor.

The linear equation solver was inspired by, and patterned after the
one in MetaPost, the main difference being that all numbers in this
sytem are complex numbers.

]]

-- Errors orginated by this code are normally printed using an error
-- level of zero.  Consider setting the level to one when debugging.

local level = 0

local function err(msg)
   error(msg, level)
end

-- When this code is loaded into the running C program, it sets the
-- global variable verbose to true when the program is running in
-- debugging mode.  In that mode, debugging information is sent to the
-- standard error stream.

local function display(s)
   return io.stderr:write(s)
end

-- Real numbers

-- Use a tolerance to determine if a number is close enough to zero to
-- be considered to be zero.

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

-- Reference: "Introduction to Complex Variables and Applications",
-- Ruel V. Churchill, McGraw-Hill Book Company, Inc, 1949.

local Complex = {}		-- The complex number metatable
Complex.__index = Complex

local function complex(x, y)	-- The complex number constructor
   return setmetatable({r = x, i = y or 0}, Complex)
end

-- A simple distance metric that is quick to compute
function Complex.mag(z)
   return math.max(math.abs(z.r), math.abs(z.i))
end

function Complex.is_zero(z)	-- Zero test using mag metric
   return is_zero(z.r) and is_zero(z.i)
end

function Complex.is_one(z)	-- One test using mag metric
   return is_zero(z.r - 1) and is_zero(z.i)
end

function Complex.zero(z)
   z.r = zero(z.r)		-- Replace numbers close
   z.i = zero(z.i)		-- to zero with zero
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
		  x1 * y2 + x2 * y1)
end

function Complex.__div(z1, z2)
   local x1, y1, x2, y2 = z1.r, z1.i, z2.r, z2.i
   local sq = x2 * x2 + y2 * y2
   return complex((x1 * x2 + y1 * y2) / sq,
		  (x2 * y1 - x1 * y2) / sq)
end

function Complex.__pow(z1, z2)
   if not is_zero(z2.i) then
      err("exponent must be real")
   else
      z2:zero()
      return (z1:log() * z2):exp()
   end
end

function Complex.conj(z)
   return complex(z.r, -z.i)
end

function Complex.abs(z)
   local x, y = z.r, z.i
   return complex(math.sqrt(x * x + y * y))
end

function Complex.exp(z)
   local x, y = z.r, z.i
   local r = math.exp(x)
   return complex(r * math.cos(y), r * math.sin(y))
end

function Complex.log(z)
   local x, y = z.r, z.i
   local r2 = x * x + y * y
   return complex(0.5 * math.log(r2), math.atan2(y, x))
end

function Complex.cos(z)
   local x, y = z.r, z.i
   return complex(math.cos(x) * math.cosh(y), 
		  -math.sin(x) * math.sinh(y))
end

function Complex.sin(z)
   local x, y = z.r, z.i
   return complex(math.sin(x) * math.cosh(y), 
		  math.cos(x) * math.sinh(y))
end

function Complex.rad(z)
   if not is_zero(z.i) then
      err("rad argument must be real")
   else
      return complex(math.rad(z.r))
   end
end

function Complex.deg(z)
   if not is_zero(z.i) then
      err("deg argument must be real")
   else
      return complex(math.deg(z.r))
   end
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

-- Translation table

-- When a variable has solved, its real and imaginary parts are placed
-- in the translation table for use by the preprocessor substitution
-- mechanism.

local translation = {}

local function solved(v, z)
   translation[v.."#r"] = tostring(zero(z.r))
   translation[v.."#i"] = tostring(zero(z.i))
end

-- This function is called when the preprocessor finds something to be
-- replaced.

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

local Linear = {}		-- Linear polynomial metatable
Linear.__index = Linear

local function linear(c, ts)	-- Linear polynomial constructor
   return setmetatable({c = c, ts = ts or {}}, Linear)
end

-- Delete linear terms with zero coefficients, and replace the
-- constant term with zero when it is close to zero.
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
   p.c:zero()
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

function Linear.__unm(p)
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
	 err("muliplier and multiplicand both not a number")
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
   return linear(complex(1) / c2) * p1
end

function Linear.__pow(p1, p2)
   local c1, c2 = p1:number(), p2:number()
   if not c1 then
      err("exponentiation base not a number")
   elseif not c2 then
      err("exponent not a number")
   else
      return linear(c1 ^ c2)
   end
end

-- v1 is a dependent variable defined by p1.  If p1 does not refer to
-- v2, this function returns p2 unchanged.  Otherwise it substitutes
-- p2 for v2 in p1, and reports the update if debugging.
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
      if c1 then		-- We found an answer!
	 solved(v1, c1)
      end
      return p1
   end
end

-- To string method

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

-- Mathematical functions--maps from complex values to complex values

-- Set up metatable so it reports attempts to use functions as variables.

local Map_missing = {}
function Map_missing.__index(table, key)
   err("function used as a variable")
end

local Map = setmetatable({}, Map_missing)
Map.__index = Map

local function map(name, func)	-- The math function constructor
   return setmetatable({name = name, func = func or Complex[name]}, Map)
end

function Map.subst(map)		-- Ensure substitutions do nothing
   return map			-- to a math function
end

function Map.__tostring(map)
   return map.name
end

-- The enviroment maps variables to linear polynomials or math
-- functions.  When a variable maps to a linear polynomial, it is a
-- dependent variable that is defined by a linear polynomial which
-- contains only independent variables.

local env = {}

-- Set up the initial environment

env.i = linear(complex(0, 1))
env.pi = linear(complex(math.pi))
env.abs = map("abs")
env.exp = map("exp")
env.log = map("log")
env.cos = map("cos")
env.sin = map("sin")
env.rad = map("rad")
env.deg = map("deg")

-- Linear equation solver

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
   -- Find the linear term with the coefficient of maximum magnitude.
   local m_max, v_max, c_max = 0
   for v, c in pairs(p.ts) do
      local m = c:mag()
      if m > m_max then
	 m_max, v_max, c_max = m, v, c
      end
   end
   -- Now v_max is the variable, and c_max is its coefficient.
   -- Solve the equation for v_max.
   p.ts[v_max] = nil
   c_max = complex(-1) / c_max
   p = linear(c_max) * p
   p:simplify()
   -- v_max is a dependent variable defined by p
   if verbose then
      display(v_max.." is "..tostring(p).."\n")
   end
   c = p:number()
   if c then			-- We found an answer!
      solved(v_max, c)
   end
   for ve, pe in pairs(env) do	-- Propagate the new dependency
      env[ve] = pe:subst(ve, p, v_max)
   end
   env[v_max] = p     -- Add new dependent variable to the environment
end   

-- Linear equation constructors accessed by the parser

function variable(var)
   local val = env[var]		-- If the variable is a dependent
   if val then			-- variable or names a function,
      return val		-- replace the variable with its value
   else
      return linear(complex(0), {[var] = complex(1)})
   end
end

-- Generate an anonymous variable

local whatever = 0
function anonymous_variable()
   local var = whatever.."z"
   whatever = whatever + 1
   return variable(var)
end

function number(x)
   return linear(complex(x))
end

function application(fun, arg)	-- Apply a function to an argument
   local val = fun.func		-- The argument must be a number
   local num = arg:number()
   if not val then
      err(fun:tostring().." not a function")
   elseif not num then
      err("function "..fun:tostring().." not applied to a number")
   else
      return linear(val(num))
   end
end

-- Donald Knuth's mediation notation is defined by:
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
   -- update right with new solutions
   local ans = linear(right.c)
   for v, c in pairs(right.ts)
   do
      ans = ans + variable(v) * linear(c)
   end
   return ans
end
