# Beating a dead Turing Tarpit (Part 1)

The language BrainFuck has been done many many times by now. So what can we still learn from it?

As it happens, BF is an excellent test case for a wide variety of things,
ranging from parsing, to exploring the performance of language runtimes, to
compilation techniques, and even surprisingly general insights to datatypes and
architecture. This series of posts will attempt to provide insights into as many
of these things as possible using the dubiously real-world overarching framing
of BF. The hope is that by using this common framework, it will be easier to see
how all these things tie together and understand each concept without
needing a specific contrived example of each.

In this post, we will be laying the groundwork of the series by making a simple
zero-dependencies implementation of BF in Lua. This implementation will use a
manual recursive descent parser from an input stream and compile it to a
closure in Lua with only one or two simple optimizations and no intermediate
representation.

BrainFuck is a Turing Tarpit, a type of esoteric language that aims to be
turing complete but inconvenient to program in or reason about. In
particular, BF is a tape machine where each character of the source code
corresponds to a single instruction, of which there are eight. It can increment
and decrement the current cell of the tape, move left and right on the tape,
read and write from stdio, and do conditional/loop branching. This is
technically turing complete, and there even exist compilers from C to BF. It's
just very inefficient on real hardware and very difficult to work
with.

This simplicity makes it possible to implement rather quickly and
makes the code small enough to read effectively, but
still has enough complexity to show off a lot of stuff. Without further ado, let's
begin!

## The input stream

Because this first implementation has zero dependencies, we only have an
extrememly minimal core library that's meant to run on a toaster. So we are
rolling our own input stream as the first step. The input stream will wrap a
string and permit taking characters one at a time from it. I will show the code,
and then provide an explanation of it.

```lua
-- Define the metatable for charstream objects
local charstream_mt = {__index = {}}

-- Implement the next method to consume a character from the stream
function charstream_mt.__index:next()
  local char = self.char
  --print("getting next", char)
  self.pos = self.pos + 1
  self.char = self.str:sub(self.pos, self.pos)
  return char
end
-- Implement the peek method to get the next character without consuming it
function charstream_mt.__index:peek()
  --print("peeking", self.char)
  return self.char
end

-- Implement a constructor that takes a backing string
local function charstream(str)
  return setmetatable({pos = 1, str = str, char = str:sub(1, 1)}, charstream_mt)
end
```

Lua supports object oriented programming, and this is a natural fit for a
stream. Thus, I am defining a constructor and a metatable for the class. Lua's
object system is much more flexible than the typical class systems in most
languages, so the core language chose not to enshrine the class construct in it,
and classes are effectively provided by a number of libraries. But this version
is zero-dependencies, so no class library here. This is rolling a class from
scratch using raw langauge mechanisms, and since I only need the one right now,
I'm not bothering to write an abstraction around it.

For people who are unfamiliar with Lua, I'll go over a bit about how this code
works. If you understand Lua's metatables, feel free to skip to the next
section. Lua provides operator overloading, finalizers, ephemerons, etc. via
metatables, which is just an ordinary table with some special keys that the runtime
knows to look for when the table is in the special metatable slot of any value. By default,
the metatable of any table is nil, but strings, for example, have a metatable
that gives them pattern matching methods and string operators.

The operator I'm using here is `__index` which is the metamethod for when code
tries to access a field or method that doesn't exist in the value (in the
ordinary way). I initialize it to an empty table, then fill in methods on it. In
Lua, the `foo:bar()` syntax indicates a method, where whatever value the method is
called on is passed into the function as `self` (methods are just ordinary
functions that accept `self` as their first parameter before their ordinary
arguments list). So here I use the method definition syntax to fill in our methods
to our index behavior, so that whenever code asks for them from any
charstream object it gets these definitions.

After implementing the two core methods of the charstream class, all that's left
is the constructor, which I'm making as just an ordinary function taking a
stream. Fancier class libraries have fancier ways to do this, but I'm doing a
simple self-rolled class. The constructor
creates a table that stores the initial state of the object, then calls
`setmetatable` to imbue it with charstream-ness and thus grant it the
methods.

## A couple utils

There are three utility functions I'm going to want defined before I continue
much further, so I might as well get to them now. First, functions to read and
write a single byte as a number for use in the BF tape, and second, a function
that consumes data from a stream as long as it's equal to a specific value.

```lua
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
```

These are straightforward implementations with no deep magic. To write a
byte, we turn the number into a string containing that character and write it to 
stdout. To read a byte, we read a one-byte long string from stdin and then get
the character code from it. To take from a stream, we peek and consume
characters for as long as they match, counting as we go.

## The tape

BF implementations need a tape of some form or another; some implementations
might initialize a fixed size buffer and make it loop if it goes past the end,
some implementations might make it fail if it goes off the end, or allocate and
initialize new blocks as needed to append to it, but may only support one
direction. I chose to make my implementation have a tape which is infinite in both
directions and can also be sparse if it isn't fully initialized by using Lua's
metatables.

```lua
local tape_mt = {__index = function(t, i) return 0 end} -- automatically extend with zeros
local function new_tape()
  return setmetatable({0}, tape_mt)
end
```

There, all done! Wasn't that easy? The index operator, which is only called when
the program requests a cell that has never been set, always returns
that the value of any unused cell is zero. Lua tables are associative
arrays, dictionaries, maps, whatever you want to call them, and so can store
associations from any value (except nil) to any value (where nil means absent);
it does do array optimization though, so the integer keys up to wherever the
array stops being half-full are stored in an array for performance, thus giving
this super simple implementation an excellent mix of performance in the typical
usage and flexibility for strange cases.

## The compiler

This part is a long one, but I'll go piece by piece.

First, a quick introduction to Brain Fuck.

Next we start defining our compiler

```lua
local function compile_bf(src, read, write)
  local stream = charstream(src)
  read = read or default_read
  write = write or default_write
```

The `compile_bf` function takes a `src` string and `read` and `write` functions.
It then immediately turns the source into a stream for parsing, and provides
default implementations for read and write if they weren't provided.

Next, we're going to start defining what to do with characters from the source
stream. The first instruction to define is `+`, used to increment the current
cell.

```lua
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
```

I forward-declare `parse` (more on that later), then start defining a table of
handlers that handle characters from the stream. The `+` symbol increments the
value on the current cell of the tape. As an optimization, I merge all adjacent
`+` symbols into a single increment operation. The operation that results is a
function taking the tape and the state, executing for effects, then returning
the tape and a new position; this type will be used for all the operations in
the compiled code.

Next up is `-`, the instruction to decrement the current cell, a direct mirror
of `+`.

```lua
    ["-"] = function()
      local count = takewhile(stream, "-")
      --print("-", count)
      return function(tape, pos)
        tape[pos] = tape[pos] - count
        return tape, pos
      end
    end,
```

The same thing just with `-` instead of `+`

Now we have the third and fourth instructions, `<` and `>`, moving
the position on the tape left and right instead of changing the value.

```lua
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
```

Almost the same as `+` and `-` but modifying the position instead of the tape
cell.

Next up, IO, which uses `.` for writing and `,` for reading from stdin.

```lua
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
```

This uses the read and write functions we got at the start of the compilation to
read stdin to the current cell or to write the current cell to stdout. Or some
other stream if specified.

Now for the branching instructions: `[` and `]`. A matched pair of brackets is
effectively a while loop; an open bracket branches forward to just before the
matching close bracket and a close bracket conditionally branches backward to
just after the matching open bracket when the content of the current cell is
nonzero.

```lua
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
```

For the `[` instruction, we consume the `[` character of the source code, and
then recursively parse out the body of the loop between a matched pair of square brackets.
(they must be matched for it to be valid BF) The operation that results from
this will implement the behavior of the pair of operations by using a while loop
and running the section of code between the brackets inside it.

Correspondingly, for the `]` instruction the parser consumes it and returns nil
as a sentinel for the end of the instruction sequence.

Now we just need to cap it off and provide the implementation of `parse` to tie
it all together.

```lua
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
```

The handler for the empty string causes the parse to terminate gracefully at the
end of the program.

Parse itself just iterates through the stream of characters building up a
sequence of the corresponding operations, then produces an operation that
performs each of the operations from the block in order. The entire source
stream is bundled up into a single operation, then wrapped into a completed
program that initializes the tape and starts at the beginning, which is then
returned.

Now we can test our compiler.

```lua
local hello = compile_bf "++++++++[>++++[>++>+++>+++>+<<<<-]>+>+>->>+[<]<-]>>.>---.+++++++..+++.>>.<-.<.+++.------.--------.>>+.>++."

hello()
```
