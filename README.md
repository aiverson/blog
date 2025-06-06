# blog

This repository contains a bit of my independent technical writing which hasn't been otherwise presented, wandering between aspirational technical specifications, blog posts, and tutorials/curricula.

Much of it is incomplete, but I have chosen to share it because shared but incomplete writing will inspire people better to make things that build on my ideas much better than explaining them in person one at a time.

Please let me know if you are inspired by something or want to see something get developed more.

## Index

### Completed

os-fictions is an exploration of speculative operating system architecture partially inspired by STEPS-2012 discussing how future operating systems might take advantage of modern and near-future technology, unifying a variety of my projects and research and ideas described in other writings into a coherent basis for an OS with features and security beyond any current software. It is too early to actually discuss standardizing many of these things, and it is an early work subject to refinement as my research and implementation and experimentation yields results. If the concepts here are appealing to you, please volunteer to help implement the stepping stones to building such a major project

### WIP

The tarpit folder contains teaching about compiler techniques and language internals through the lens of repeatedly writing and expanding code that runs a simple turing tarpit language. Currently it covers using Lua metatables to implement core datastructures and a simple closure generation compiler to produce JITable code. Planned next entries include exploring benchmarking and performance tuning JITted code, using metaprogramming to compile to native code conveniently, and other code generation techniques.

cpp-cube contains an exploration of advanced type system features through the lens of C++, exploring exactly what each feature brings to the language in terms of power, and where their limitations lie. Currently very incomplete due to the project they're associated with being delayed.

flakes-cross is a proposal for a minimal fix to nix cross compilation and flake schemas to allow effectively using cross compilation in flakes. It can be read as a complete standalone proposal. A future followup describing more widespread changes to the flakes architecture and tooling (or successors to them) to make it vastly more useful is upcoming.

social-technical-version-control is a response to complaints about version control systems (and coordination systems more generally) and speculation about possible future technology for them.

rpc-standard is a description of problems with current networking and IPC systems and technical solutions to make a better future standard; currently it focuses on capturing a high level view of the problems and my proposed fixes to hopefully prompt other developers and researchers to experiment and expand on them, so that my WIP actual specs and libraries can be reviewed and checked and tested by more people when I release them.
