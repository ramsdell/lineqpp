local function display(s)
   if verbose then
      io.stderr:write(s)
   end
end

local Complex = {}

local function mk_complex(x, y)
   return setmetatable({x, y or 0}, Complex)
end

function Complex.__add(z1, z2)
   return mk_complex(z1[1] + z2[1], z1[2] + z2[2])
end

function Complex.__sub(z1, z2)
   return mk_complex(z1[1] - z2[1], z1[2] - z2[2])
end

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
