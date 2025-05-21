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

Of course, for programs that are unable or unwilling to make that guarantee, 
running them in process isolation sandboxes just like current OSes do would
still work, with no more performance cost than current OSes accept as the cost
of doing business. Such a program could regard the verified code path as an 
enhanced version of eBPF capable of making more guarantees and/or providing more
features depending on what is desired, and optionally provide small modules with
it.

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
methods and implements them however desired. Or make it provide a full network
request inspector like a browser devtool does.

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

## IORing and workstealing first architecture

Modern computers have increased how much memory locality matters, increased how much stuff the computer can do, and increased how much stuff the computer needs to do.
Some of the practical consequences of this for OS design are that sytem calls and context switches and IPC are proportionally more expensive, because not only do we need to pay for all the instructions changing the processor status registers and memory maps, but we also need to pay for spilling the L1 cache for both data and instructions. Computer architecture has also moved away from bitbanging IO; as the cost of interrupts and task switches increased and our IO performance needs increased, computer architecture moved towards using dedicated microcontrollers, FPGAs, and ASICs to handle a specific IO operation with DMA engines and the CPU's role being to asyncronously review records of incoming messages and stage buffers of outgoing messages at its convenience. Therefore, the microsecond latency counts the processor needs to fulfill haven't gone down and have in many cases they have increased, giving the processor more time to fulfill the obligations. As a consequence, we OS/Software developers can actually *decrease* the perceived latency by trading latency for throughput, and we have much better compiler infrastructure, library infrastructure, and build infrastructure than we used to. So, what would an OS designed for high performance and secure code in the context of modern computing look like? The linux setup for iouring has proven to be a mistake, where there is an entire separate API surface of dedicated system calls and then on top of that there is a hastily bolted on iouring subsystem, and no kind of verification or assurance that either functions as designed other than "hopefully we've found all the bugs by now" which is known to not be the case. Instead, a modern Operating System should build an ioring as the *first* and *primary* system interface, using a standardized interface definition schema that has explicit forward compatibility guarantees, and it should permit communication both with the kernel and with other processes. It should also explicitly be designed for programs that run on all cores. A singlethreaded, blocking IO API for a simple system can be implemented safely on top of a multithreaded, asyc API by just wrapping the more powerful API to provide the desired interface. However, there's no reason that an async multithreaded API can't be readily usable, it just requires not failing the fundamental design problem. Between fibril solving the multithreaded runtime problem, cilk's hyperobjects solving the shared data problem, and type theorists longstanding solutions for managing mutability and sharing being implemented by rust, and the increasing usability of async and promise based APIs, There is no excuse for future production compilers to not have implemented these decade-old solutions with enormous benefits.

A future OS should discard the thread abstraction as a component of the kernel interface and instead make every process operate on all cores at once. Current tech treats the thread which was designed as a unit of sequencing as the core primitive, bolted on core affinity, then demanded that individual programs build a per core compute pool in userspace, resulting in modern high performance programs needing to invent a worker pool and then invent a new "greenthreads" sequencing primitive/abstraction on that instead to provide higher performance; instead future OSes should provide the core-associated worker pool abstraction and async IO as the primitive operations, and allow programs to reinvent legacy style threads in userspace if they need them, or use a higher performance lighter weight abstraction. By integrating a Causal DAG into the ioring infrastructure and having promise pipelining, we can allow work to move and split smoothly between multiple cores, and to queue up significant batches of operations before yielding control to the kernel, which can then dispatch and route them in bulk before scheduling a process. Having work scheduled in bulk means that when a process recieving that work gets scheduled it can read and respond to all the work at once while its resources remain in cache, which amortizes the context switching and core sync costs across a larger number of requests, greatly increasing throughput and even allowing reduced latency.

To improve performance further, we can reduce the copying required to route and serve requests; by building the ioring on a collection of buffers and using a captable to designate requests (or ideally having some kind of cap-pointer-aware hardware to handle the cap delegation, but that's futher away), we can have a per core pool of fixed size buffers which can be claimed without locks or context switches in very few cycles, and forbid modification on the buffers once they are submitted to that core's queue. By having a small pool per core so that the buffers remain in cache from when they arrive in the processor's queue, so that the performance of assembling such a request is on par with assembling a struct on the stack for a system call, but without the large expense of actually performing the system call, and capable of specifying a much larger batch of work via promise pipelined request chains. With this architecture, when the kernel handles the sequence of IO requests for a program on a core, it can ignore the actual data buffers for the most part, read just the cap table and the specified reciever, rewrite the captable for the context of the reciever's process, and then update the memory mapping to remove the buffer from the origin process's address space and add it to the receiver process's address space and add it to the incoming queue on the same core, keeping it in cache. By ensuring that IPC messages are recieved on the same core in which they are sent in the usual fast path (with workstealing as usual to allow other cores to distribute the work when it's unbalanced without paying for sync when it's balanced) we dramatically reduce the cost and latency of IPC requests, and make it both more secure and easier to program against. When a process is finished with an incoming message and releases it, that buffer is cleared and becomes available to then immediately use for outgoing messages and remains in cache. If buffers become unbalanced, they can be surrendered to the OS or other cores in batches to amortize sync costs, and cache line aligned buffers ensures minimal cross-core cache contention however buffers end up wandering through the system.

## Univeral Typed Serialization
