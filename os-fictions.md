# Let's Imagine an Operating System

What could an operating system be if written from scratch and not worried about
being compatible with existing kernel modules and utilities? What kinds of
features would be compelling? What mistakes can be addressed? What new
developments could be stolen that existing design decisions preclude?

This document will consist of me throwing ideas at the wall about interesting
and useful things that might go in an operating system, including linguistic
features, GUI features, terminal features, low level system call features, and
anything else I feel like.

## Memory Security and Capability Security

If it is possible to guarantee that a program can never "forge" a pointer, then
it becomes possible to do a bunch of useful operating system things. One way to
do this is to have a low level type checker that a piece of executable code
must pass before it can be put somewhere it might actually get called. A
typechecker like this that guarantees that no int can ever be cast as a pointer and
no pointer arithmetic is allowed except array indices that are provably in
bounds and struct field accesses that are provably safe.

Given this, multiple pieces of code can be run in the same address space safely,
and neither of them can gain access to anything that isn't explicitly passed to
them. (not counting things like rowhammer or some new variant of spectre.)

Additionally, access to operating system facilities, rather than being system
calls that are just ambient things accessible by compiling in a special
instruction, would be methods or functions called from objects passed in to a
program when it is run, or module when it is loaded, or whatever. Creating a
restricted set of capabilities is just a matter of passing in a different object
with the same interface. Running a program with a single directory appearing as
root is just a matter of making an object that exposes the filesystem interface
and wraps around the filesystem interface it was provided. This is arbitrarily
nestable.

Creating an interface for a strange implementation is also possible. For
example, replacing a program's entire networking stack with something that
instead of sending things to the actual internet, logs all packets to disk and
sends everything to another program that is mocking a network service locally
for testing purposes is easy. Just create an object that exposes the networking
methods and implements them however desired.

This can also be used to implement entirely new types of capabilities. A program
or service may create and make available entirely new capabilities and
interfaces to another program or library just by defining the type and then
passing around an object encapsulating the capability. For example, a program
executed inside a gui might get access to a capability for listening to mouse
input, checking the window size, and rendering things to the framebuffer. This
capability is secured just like all fundamental kernel capabilities, and the
kernel doesn't need to know anything about it before it is compiled and
installed, or even before it starts running.

## Scheduling

Sometimes, it is useful to impose a time limit upon a task or restrict
timeslices. Modern linux and windows have a variety of useful scheduling modes
and parameters, but they don't always fit the job. For example, it isn't
possible to reclaim resources from a dead thread that failed to destruct them
itself before the end of the containing process. The existence of the threads in
the same address space as opposed to processes in different address spaces has
major performance implications due to the overhead of switching between address
spaces for paging. However, if all resources are allocated through
capability-secure objects, then passing a proxy that separately records the
thread's resources allows easily going through and closing them all after the
termination of the thread or to create resource limits on a per-thread basis
with no performance cost when not used and very little cost when used.

However, why not give an application finer grained control of its own
scheduling? In addition to having the standard scheduling capabilities, why not
allow a program to micromanage its scheduling if it really needs to, for
instance to implement backpressure on a complicated producer-consumer network
running on separate threads while also getting in a bit more microoptimization
of timing based on in-app knowledge. A thing that I was wishing that I could do
in some software I was writing was to specify to run a thread for at most so
much processor time or until it yielded control back to the manager, but to
safely pause it immediately when it exceeded the time limit (subject to the
limitations of clock resolution/scheduling timer) and to keep track of how much
processor time it used. I couldn't find a way to actually accomplish those
things reasonably and efficiently on existing linux systems. Basically, anything
stretching between cooperative and preemptive multitasking is painful.

