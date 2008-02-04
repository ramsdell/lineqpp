

local function display(s)
   if verbose then
      io.stderr:write(s)
   end
end

local function show(t)
   if type(t) == "table" then
      display("(")
      for i = 1, #t - 1 do
	 show(t[i])
	 display(" ")
      end
      show(t[#t])
      display(")")
   elseif type(t) == "string" or type(t) == "number" then
      display(t)
   else
      display("?")
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

local function mk_complex(x, y)
   return setmetatable({r = x, i = y or 0}, Complex)
end

function Complex.is_zero(z)
   return is_zero(z.r) and is_zero(z.i)
end

function Complex.__eq(z1, z2)
   return is_zero(z1.r - z2.r) and is_zero(z1.i - z2.i)
end

function Complex.__add(z1, z2)
   return mk_complex(z1.r + z2.r, z1.i + z2.i)
end

function Complex.__sub(z1, z2)
   return mk_complex(z1.r - z2.r, z1.i - z2.i)
end

function Complex.__unm(z)
   return mk_complex(-z.r, -z.i)
end

function Complex.__mul(z1, z2)
   local x1, y1, x2, y2 = z1.r, z1.i, z2.r, z2.i
   return mk_complex(x1 * x2 - y1 * y2,
		     y1 * x2 + x1 * y2)
end

function Complex.__div(z1, z2)
   local x1, y1, x2, y2 = z1.r, z1.i, z2.r, z2.i
   local sq = x2 * x2 + y2 * y2
   return mk_complex((x1 * x2 + y1 * y2) / sq,
		     (y1 * x2 + x1 * y2) / sq)
end

-- __pow should at least support squaring.

function Complex.__tostring(z)
  return z.r..' + '..z.i..'i'
end

-- Independent variables

-- The object used to store an independent variable is called an
-- unknown.  It stores the dependent variables that are defined with a
-- reference to the independent variable.  The independent variable is
-- stored in the i field, and the set of dependent variables are
-- stored in the d field.

local Unknown = {}

local function mk_unknown(var)
   return setmetatable({i = var, d = {}}, Unknown)
end

function Unknown:add(var)
   self.d[var] = true
end

function Unknown:del(var)
   self.d[var] = nil
end

function Unknown:__tostring()
  return self.i
end

-- Linear polynomials (polynomials with degree one)

-- The linear polynomial data structure has two fields.  The c field
-- contains the constant term.  The v field contains a table that maps
-- each variable to its coefficient.  Thus
--
--     x + 2*y + 3   --->   {c = 3, t = {x = 1, y = 2}}
--
-- Though real numbers are shown above, complex numbers are used.

local Linear = {}

-- Variables may be bound to a complex number, a linear polynomial, a
-- function, or an unknown.

local env = {}

function mk_var(var)
   return {"var", var}
end

function mk_num(num)
   return {"num", num}
end

function mk_fun(fun, arg)
   return {"fun", fun, arg}
end

function mk_plus(left, right)
   return {"plus", left, right}
end

function mk_sub(left, right)
   return {"sub", left, right}
end

function mk_mul(left, right)
   return {"mul", left, right}
end

function mk_div(left, right)
   return {"div", left, right}
end

function mk_neg(arg)
   return {"neg", arg}
end

function mk_exp(left, right)
   return {"exp", left, right}
end

function mk_eq(left, right)
   show(left)
   display("\n")
   show(right)
   display("\n\n")
   return right
end

function translate(s)
   return nil
end
