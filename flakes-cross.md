# How to fix cross compilation in flakes

So, nix has a model of software platforms composed of build, host, target slots.
The build platform is the platform the build is being run on. The host is the
platform the built executable or library will run on. The target is the platform
that, if the executable the derivation builds is a compiler, it will compile
code for when run on the host. And a few other things?

It would be really convenient if we could just get rid of target altogether
because it doesn't do much, in most packages it isn't even used, and with clang
we can just compile for any target with a single build of the compiler. GCC
requires a specific target, with a different set of executables for every target
and different copies of the standard headers because GCC is dumb and old. A few
other packages baked in these assumptions as well. Also, the nix packaging of
clang forcibly overrides the system that lets clang generate code for any target
and forces it to only be able to generate code for one which is annoying. So we
can't easily get rid of it because of GCC being dumb and the entirety of open
source software requiring GCC and baking in the dumb assumptions.

Anyways, mkDerivation has different build inputs for different slots. Native
build inputs, propagated build inputs, etc. (See table here)
https://nixos.org/manual/nixpkgs/stable/#ssec-stdenv-dependencies

So if you have a platform you're building on and a platform you're going to run
on (which you always do when you're creating a derivation) nix is capable of
determining what the platforms of the other dependencies should be based on
which input section they are in. (The build platform of native inputs should be
the same as the current build platform so they can be recursed onto and built
from source if needed.)
- the target of native inputs must be the host platform of the current build
- The host of native inputs must be the build platform of the current build
- The host of build inputs should be the target platform of the current build

The nix architecture has baked this build host target concept in pretty deep,
and there is no practical way to eliminate it in the current ecosystem. Flakes
has no way to specify these different platforms, and makes the assumption that
host, build, and target are always the same; i.e. that cross compilation is
impossible. Nix flakes thus successfully makes cross compilation impossible
within the world of nix flakes. (It is still possible to cross compile by using
legacy packages from nixpkgs and hacking a bit as long as you don't need
anything else) You can't package a cross compiler in a flake sensibly. You can't
pull in a cross compiled version of a library from a flake. The only way to make
a package that runs on a different system than the one you're building on is to
use qemu to run the entire build in an emulator, and hope that your target is
one of the handful of systems that nixpkgs caches working natively-compiled
compiler binaries for, because not all systems nix supports as build targets
have precompiled compilers in the binary cache, and it is impossible to cross
compile a compiler binary within the confines of flakes, or even to use a cross
compiled compiler, or just refer to a cross compiler at all within the bounds of
flakes.

There is a fairly straightforward way to fix this, however. By changing the
order of the attributes in the flake package output and patching mkDerivation to
accept sets of derivations indexed by platform, choosing the correct platform
for the role in the derivation, we can make flakes handle cross compilation
gracefully.

Ok, so by making this change, the natural way to talk about a package in the
build inputs becomes `packages.foo` instead of `packages.x86_64-linux.foo` which
avoids baking in the architecture where it doesn't make sense to, since nix
already knows what architecture it's going to have to be. This allows the same
derivation to handle it in cases where the build and host are the same or
different by just picking different platforms for nativeBuildInputs and
buildInputs when cross compiling, thus making cross compilation work by default
on most packages in flakes. As an addendum, it is also possible to have things
like `packages.gcc.x86_64-linux.aarch64-linux` to specify both host and target
for a package where they need to be different, like a compiler for cross
compilation. The compiler can be automatically selected to have host and target
match the build and host platform of a cross compilation, thus simplifying the
cross compilation system even more than what nixpkgs currently offers with
pkgsCross.

To manually migrate flakes, delete the platform between packages.platform.foo in
all cases where it is referenced in an input so nix can figure that out on its
own, and transpose the order of the attrs on the packages output so the name
comes before the platform.
