--[[ 

Equation solver for the Linear Equation Preprocessor
Copyright (C) 2008 John D. Ramsdell
This software is covered by the MIT Open Source License

This file contains the linear equation solver used to derive
substitutions for variables found by the preprocessor.  The first
section implements linear polynomials and a solver.  The second
section implements complex functions.  The third section provides
complex linear polynomials and the functions used by the parser to
construct linear polynomials.

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
local function zap(x)
   if is_zero(x) then
      return 0
   else
      return x
   end   
end

-- Convert a number to a string for display.
local function s(x)
   return string.format("%.4f", x)
end

-- Translation table

-- When a variable has solved, its placed in the translation table for
-- use by the preprocessor substitution mechanism.

local translation = {}

local function solved(v, x)
   translation[v] = s(zap(x))
end

-- This function is called when the preprocessor finds something to be
-- replaced.

function translate(s)
   return translation[s]
end

-- Linear polynomials (polynomials with degree one or zero)

-- The linear polynomial data structure has two fields.  The c field
-- contains the constant term.  The ls field contains the linear terms
-- represented as a table that maps each variable to its coefficient.
-- Thus
--
--     x + 2*y + 3   --->   {c = 3, ls = {x = 1, y = 2}}
--

local Linear = {}		-- Linear polynomial metatable
Linear.__index = Linear

local function linear(c, ls)	-- Linear polynomial constructor
   return setmetatable({c = c, ls = ls or {}}, Linear)
end

-- Delete linear terms with zero coefficients, and replace the
-- constant term with zero when it is close to zero.  This method
-- modifies its object rather then returning a fresh zapped object.
function Linear.zap(p)
   local a = {}			-- Collect terms to be deleted
   for v, c in pairs(p.ls) do
      if is_zero(c) then
	 a[#a + 1] = v
      end
   end
   for i in ipairs(a) do	-- Delete collected terms
      p.ls[a[i]] = nil
   end
   p.c = zap(p.c)
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
   return size(p.ls) == 0 and p.c
end

-- If p is a variable, return the variable, otherwise return false.
function Linear.variable(p)
   if is_zero(p.c) and size(p.ls) == 1 then
      for v, c in pairs(p.ls) do
	 if is_zero(c - 1) then
	    return v
	 end
      end
   end
   return false
end

function Linear.__add(p1, p2)
   local ls = {}
   for v1, c1 in pairs(p1.ls) do
      ls[v1] = c1
   end
   for v2, c2 in pairs(p2.ls) do
      local c1 = ls[v2]
      if c1 then
	 ls[v2] = c1 + c2
      else
	 ls[v2] = c2
      end
   end
   return linear(p1.c + p2.c, ls)
end
   
function Linear.__sub(p1, p2)
   local ls = {}
   for v1, c1 in pairs(p1.ls) do
      ls[v1] = c1
   end
   for v2, c2 in pairs(p2.ls) do
      local c1 = ls[v2]
      if c1 then
	 ls[v2] = c1 - c2
      else
	 ls[v2] = -c2
      end
   end
   return linear(p1.c - p2.c, ls)
end

function Linear.__unm(p)
   local ls = {}
   for v, c in pairs(p.ls) do
      ls[v] = -c
   end
   return linear(-p.c, ls)
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
   local ls = {}
   for v2, c2 in pairs(p2.ls) do
      ls[v2] = c1 * c2
   end
   return linear(c1 * p2.c, ls)
end

function Linear.__div(p1, p2)
   local c2 = p2:number()
   if not c2 then
      err("divisor is not a number")
   end
   return linear(1 / c2) * p1
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
   local c1 = p1.ls[v2]
   if not c1 then
      return p1
   else
      p1.ls[v2] = nil
      p1 = p1 + linear(c1) * p2
      p1:zap()
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
   if not is_zero(p.c) then
      buf = " + "..s(p.c)
   end
   for v, c in sorted_pairs(p.ls) do
      if is_zero(c - 1) then
	 buf = buf.." + "..v
      elseif not is_zero(c) then
	 buf = buf.." + "..s(c)..'*'..v
      end
   end
   if buf:len() > 3 then
      return buf:sub(4)		-- Dump leading " + "
   else
      return "0"
   end
end

-- The enviroment maps variables to linear polynomials or math
-- functions.  When a variable maps to a linear polynomial, it is a
-- dependent variable that is defined by a linear polynomial which
-- contains only independent variables.

local env = {}

-- Linear equation solver

local function solve(p)
   p:zap()
   local c = p:number()
   if c then
      if is_zero(c) then
	 err("redundant equation")
      else
	 err("inconsistent equation")
      end
   end
   -- Find the linear term with the coefficient of maximum absolute
   -- value.
   local a_max, v_max, c_max = 0
   for v, c in pairs(p.ls) do
      local a = math.abs(c)
      if a > a_max then
	 a_max, v_max, c_max = a, v, c
      end
   end
   -- Now v_max is the variable, and c_max is its coefficient.
   -- Solve the equation for v_max.
   p.ls[v_max] = nil
   p = linear(-1 / c_max) * p
   p:zap()
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

-- Mathematical functions--maps from complex values to complex values

-- Reference: "Introduction to Complex Variables and Applications",
-- Ruel V. Churchill, McGraw-Hill Book Company, Inc, 1949.

local function conj(x, y)
   return x, -y
end

local function abs(x, y)
   return math.sqrt(x * x + y * y), 0
end

local function exp(x, y)
   local r = math.exp(x)
   return r * math.cos(y), r * math.sin(y)
end

local function log(x, y)
   local r2 = x * x + y * y
   return 0.5 * math.log(r2), math.atan2(y, x)
end

local function cos(x, y)
   return math.cos(x) * math.cosh(y), -math.sin(x) * math.sinh(y)
end

local function sin(x, y)
   return math.sin(x) * math.cosh(y), math.cos(x) * math.sinh(y)
end

local function rad(x, y)
   if not is_zero(y) then
      err("rad argument must be real")
   else
      return math.rad(x), 0
   end
end

local function deg(x, y)
   if not is_zero(y) then
      err("deg argument must be real")
   else
      return math.deg(z.r), 0
   end
end

-- Set up metatable so it reports attempts to use functions as variables.

local Map_missing = {}
function Map_missing.__index(table, key)
   err("function used as a variable")
end

local Map = setmetatable({}, Map_missing)
Map.__index = Map

local function map(name, func)	-- The math function constructor
   return setmetatable({name = name, func = func}, Map)
end

function Map.subst(map)		-- Ensure substitutions do nothing
   return map			-- to a math function
end

function Map.__tostring(map)
   return map.name
end

-- Set up the initial environment

env["i#x"] = linear(0)
env["i#y"] = linear(1)
env["pi#x"] = linear(math.pi)
env["pi#y"] = linear(0)

env.abs = map("abs", abs)
env.exp = map("exp", exp)
env.log = map("log", log)
env.cos = map("cos", cos)
env.sin = map("sin", sin)
env.rad = map("rad", rad)
env.deg = map("deg", deg)

-- Complex Linear Polynomials

local Complex = {}		-- The complex polynomial metatable
Complex.__index = Complex

local function complex(x, y)	-- The complex polynomial constructor
   return setmetatable({x = x, y = y or linear(0)}, Complex)
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
   local x2, y2 = z2.x, z2.y
   local x, y = x2:number(), y2:number()
   if not x or not y then
      err("divisor is not a number")
   end
   local sq = linear(1 / (x * x + y * y))
   local x1, y1 = z1.x, z1.y
   return complex((x1 * x2 + y1 * y2) * sq,
		  (x2 * y1 - x1 * y2) * sq)
end

function Complex.__pow(z1, z2)
   local x2, y2 = z2.x:number(), z2.y:number()
   if not x2 or not y2 then
      err("exponent not a number")
   elseif not is_zero(y2) then
      err("exponent must be real")
   end
   local x1, y1 = z1.x:number(), z1.y:number()
   if not x1 or not y1 then
      err("exponentiation base not a number")
   end
   x1, y1 = log(x1, y1)
   x1, y1 = exp(x1 * x2, x2 * y1)
   return complex(linear(x1), linear(x2))
end

-- Linear equation constructors accessed by the parser

local function variable_part(var)
   local val = env[var]		-- If the variable is a dependent
   if val then			-- variable or names a function,
      return val		-- replace the variable with its value
   else
      return linear(0, {[var] = 1})
   end
end

function variable(var)
   return complex(variable_part(var.."#x"), variable_part(var.."#y"))
end

-- Generate an anonymous variable

local whatever = 0
function anonymous_variable()
   local var = whatever.."z"
   whatever = whatever + 1
   return variable(var)
end

function number(x)
   return complex(linear(x))
end

function application(fun, arg)	-- Apply a function to an argument
   local f = fun.func		-- The argument must be a number
   local x, y = arg.x:number(), arg.y:number()
   if not f then
      err(fun:tostring().." not a function")
   elseif not x or not y then
      err("function "..fun:tostring().." not applied to a number")
   else
      local fx, fy = f(x, y)
      return complex(linear(fx), linear(fy))
   end
end

-- Donald Knuth's mediation notation is defined by:
-- t [x, y] = x + t * (y - x)
-- In our case, t can be complex, so we define it by:
-- t [x, y] = x + xpart t * (y - x)
function mediation(scale, left, right)
   return left + complex(scale.x, linear(0)) * (right - left)
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

-- Update p with the latest solutions.
local function reduce(p)
   local ans = linear(p.c)
   for v, c in pairs(p.ls)
   do
      ans = ans + variable_part(v) * linear(c)
   end
   return ans
end

local function equation_part(left, right)
   if verbose then
      left:zap()
      right:zap()
      display(tostring(left).." = "..tostring(right).."\n")
   end
   solve(left - right)
end

function equation(left, right)
   equation_part(left.x, right.x)
   equation_part(reduce(left.y), reduce(right.y))
   return complex(reduce(right.x), reduce(right.y))
end
