

local charstream_mt = {__index = {}}
function charstream_mt.__index:next()
  local char = self.char
  --print("getting next", char)
  self.pos = self.pos + 1
  self.char = self.str:sub(self.pos, self.pos)
  return char
end
function charstream_mt.__index:peek()
  --print("peeking", self.char)
  return self.char
end
local function charstream(str)
  return setmetatable({pos = 1, str = str, char = str:sub(1, 1)}, charstream_mt)
end

local function default_write(n)
  io.write(string.char(n))
end
local function default_read()
  return string.byte(io.read(1))
end

local function takewhile(stream, val)
  local count = 0
  while stream:peek() == val do
    count = count + 1
    stream:next()
  end
  return count
end

local tape_mt = {__index = function() return 0 end} -- automatically extend with zeros
local function new_tape()
  return setmetatable({0}, tape_mt)
end

local function compile_bf(src, read, write)
  local stream = charstream(src)
  read = read or default_read
  write = write or default_write

  local parse

  local handlers = {
    ["+"] = function()
      local count = takewhile(stream, "+")
      --print("+", count)
      return function(tape, pos)
        --print("adding ", count, "to", tape[pos], "at", pos)
        tape[pos] = tape[pos] + count
        return tape, pos
      end
    end,
    ["-"] = function()
      local count = takewhile(stream, "-")
      --print("-", count)
      return function(tape, pos)
        tape[pos] = tape[pos] - count
        return tape, pos
      end
    end,
    ["<"] = function()
      local count = takewhile(stream, "<")
      return function(tape, pos)
        return tape, pos - count
      end
    end,
    [">"] = function()
      local count = takewhile(stream, ">")
      return function(tape, pos)
        return tape, pos + count
      end
    end,
    ["."] = function()
      stream:next()
      return function(tape, pos)
        write(tape[pos])
        return tape, pos
      end
    end,
    [","] = function()
      stream:next()
      return function(tape, pos)
        tape[pos] = read()
        return tape, pos
      end
    end,
    ["["] = function()
      stream:next()
      local body = parse()
      --print("body complete")
      return function(tape, pos)
        --print("checking while condition", tape[pos], "at", pos)
        while tape[pos] ~= 0 do
          tape, pos = body(tape, pos)
          --print("checking while condition", tape[pos], "at", pos)
        end
        return tape, pos
      end
    end,
    ["]"] = function()
      stream:next()
      return nil
    end,
    [""] = function()
      return nil
    end
  }

  function parse()
    local segment = {}
    --print("handling", stream:peek())
    local fn = handlers[stream:peek()]()
    while fn do
      segment[#segment+1] = fn
      --print("handling", stream:peek())
      fn = handlers[stream:peek()]()
    end
    local function build(idx)
      if idx > #segment then
        return function(tape, pos) return tape, pos end
      end
      local op, cont = segment[idx], build(idx + 1)
      return function(tape, pos) return cont(op(tape, pos)) end
    end
    --[[local function built(tape, pos)
      for i = 1, #segment do
        tape, pos = segment[i](tape, pos)
      end
      return tape, pos
      end]]
    return build(1)
  end

  local program = parse()
  return function()
    program(new_tape(), 1)
  end
end


local hello = compile_bf "++++++++[>++++[>++>+++>+++>+<<<<-]>+>+>->>+[<]<-]>>.>---.+++++++..+++.>>.<-.<.+++.------.--------.>>+.>++."

hello()
