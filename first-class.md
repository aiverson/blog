# First Class Language Manifesto

What does a language look like when every feature is first class and ergonomic? We should find out!

## Background: First Class Functions

First class functions are perhaps the oldest of first class features that can sensibly be distinguished.

Back in the bad old days, functions weren't like any other type; you couldn't ever store a function somewhere, only a pointer to one. Unlike every other kind of value in the language, functions could only be created by writing them out by name in the source file. Functions couldn't ordinarily have state and couldn't be created after startup except through special hard workarounds. This made operating on functions difficult and unlike every other task in the language, and so people generally just didn't do it and didn't think of doing it as a solution to problems.

At some point, production-ready languages with first class functions that captured the environment automatically were released, and that set off a cascade of innovation. People invented new kinds of abstraction built around generating dynamic function callbacks for events, built light weight visitor systems, designed type systems that could capture all the new techniques and offer suggestions, and generally found ways to use the new tools to make code simpler, clearer, and easier. And, of course, ways to use it to make code more complicated, more confusing, and difficult in new and interesting ways.

The concept and basic theory of first class functions actually predates digital computing. Alonzo Church developed the Lambda Calculus in 1936, predating Claude Shannon's 1937 work "A Symbolic Analysis of Relay and Switching Circuits". But for a long time that theoretical knowledge didn't transfer to practical implementation in tools and languages that could actually be run in reality instead of merely in theory, and until there was something real to play with the theory of how to use them practically and ergonomically was very difficult and slow to develop.

First class functions underwent a long journey to get from first invention to modern practice, diverting through many toy languages and research languages and weakly typed interpreted languages, through many attempts at type systems with various strengths, compilers with garbage collectors, arguments about how they shouldn't exist because they couldn't be made performant or safe or not-confusing. Now first class functions are so fundamental that basically every modern language has added them or been designed for them from the start. They form the building blocks of the highest performance programming systems ever designed: rayon, futhark, etc. The representations and practice in using them have become refined and improved to the point where first class functions make languages faster, safer, and clearer than code could ever be before their adoption.

First class functions also synergize with very many things. Rust's first class function mechanisms are just the same mechanisms as it's general purpose polymorphism mechanisms: Trait-bounded generics and dyn objects. Python and Lua build their entire object systems on top of first class functions. Iterators work with first class functions to make chaining data transformations extremely ergonomic and performant by making the structure of the code more obvious by breaking it down into simple steps and exposing sequence fusion optimization automatically. Iterators are of course another first class feature that originally wasn't but has become foundational.

## Active First Class Features

First class types have been researched theoretically in may proof assistants but recently reached more mainstream attention in zig, being used to make easy to read tools for building specifically crafted types for delicate designs and memory optimizations.

First class module systems have been used practically in Lua and similar dynamic languages for many years, using a single "table" or "object" value former for both records/structs and modules. The theoretical basis for making them strongly typed was set out in "The next 700 Module Systems" but well typed first class module systems have yet to reach any kind of widespread practical usage.

Well typed first class effects are also gradually spreading, with robust theoretical work about them, Unison having them in a current production release, and Rust occasionally discussing adding them to better manage its unsafety.

## Features that aren't actively being made first class

Type formers - Almost entirely unresearched as a first class object despite being extensively described as a second class object
Syntax - lots of prior research on homoiconicity and representations of syntax trees exists, but very little progress appears to be happening.
Keywords - some prior research on this exists, but it appears to be largely stalled, possibly for lack of synergies making it useful
Macros - some prior research on this exists, but it appears to be largely stalled, possibly for lack of synergies making it useful
Semantics - Recently developed as a restricted second class feature but not yet investigated as first class
Compiler targets - Extensively described as second class but only few sporadic examples reaching towards first class.
Traits - One aspect seems well researched in proof assistants, another seems almost entirely unexplored.
Coeffects - Implemented as a second class feature in many cases, theory for modular second class semantics that could easily be extended for first class, but not implemented first class yet.
Runtime safety/precondition/invariant checks - Well developed in the paper "Dynamically Typed Dependent Types", then seemingly abandoned before reaching wider usage.

## The Thesis

Every first class feature has great potential for improved productivity, ergonomics, and legibility.
Every first class feature synergizes extremely well with almost all other first class features.
This synergy can both make languages easier to build and make every feature more powerful.
Each feature gets much easier once someone does it.
These features will unlock significant power immediately but may take many years to reach their full potential.

Therefore, someone should tackle the difficult task of trying to make a language making every feature first class and making it practically usable as soon as possible, because it is very likely that this task is a limiting factor on entire generations of technological development and will have enormous payoff.









# Digressions that I might need to reincorporate or cull

Is it meaningful to call integers first class? What would them not being first class look like?

SoftFP second class floats? Not really, just ordinary types.

"Intentionally not first class" Where is the boundary between intentionally second class and not realizing that first class is possible.

Discussion of the special mechanisms to dynamically load functions, synthesize functions at runtime, or fake state by generating similar functions with static state variables.