# Let's Imagine an Operating System

What could an operating system be if written from scratch and not worried about
being compatible with existing kernel modules and utilities? What kinds of
features would be compelling? What mistakes can be addressed? What new
developments could be achieved that existing design decisions preclude?
How much more usable and comprehensible and useful could we make it?

This document will consist of me throwing ideas at the wall about interesting
and useful things that might go in an operating system, including linguistic
features, GUI features, terminal features, low level system call features, and
anything else I feel like. It will more or less constitute an actual achievable
conceptualization of the OS, but actual full designs and specifications will
require getting more people to work through all the consequences and optimize 
it deeply and broadly.

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

Why not give an application finer grained control of its own
scheduling? In addition to having the standard scheduling capabilities, why not
allow a program to micromanage its scheduling if it really needs to, for
instance to implement backpressure on a complicated producer-consumer network
running on separate threads while also getting in a bit more microoptimization
of timing based on in-app knowledge. When I was working on a project, I found myself wishing that I could specify a thread to run for specified amount of processor time -- safely pausing upon exceeding the limit -- or until it yielded control back to the manager, while keeping track of the total processor time it used. I couldn't find a way to actually accomplish those
things reasonably and efficiently on existing linux systems. Basically, anything
stretching between cooperative and preemptive multitasking is painful.

## IORing and workstealing first architecture

Modern computers have increased how much memory locality matters, increased how much stuff the computer can do, and increased how much stuff the computer needs to do.
Some of the practical consequences of this for OS design are that sytem calls and context switches and IPC are proportionally more expensive, because not only do we need to pay for all the instructions changing the processor status registers and memory maps, but we also need to pay for spilling the L1 cache for both data and instructions. Computer architecture has also moved away from bitbanging IO; as the cost of interrupts and task switches increased and our IO performance needs increased, computer architecture moved towards using dedicated microcontrollers, FPGAs, and ASICs to handle a specific IO operation with DMA engines and the CPU's role being to asyncronously review records of incoming messages and stage buffers of outgoing messages at its convenience. Therefore, the microsecond latency counts the processor needs to fulfill haven't gone down and have in many cases they have increased, giving the processor more time to fulfill the obligations. As a consequence, we OS/Software developers can actually *decrease* the perceived latency by trading latency for throughput, and we have much better compiler infrastructure, library infrastructure, and build infrastructure than we used to. So, what would an OS designed for high performance and secure code in the context of modern computing look like? The linux setup for iouring has proven to be a mistake, where there is an entire separate API surface of dedicated system calls and then on top of that there is a hastily bolted on iouring subsystem, and no kind of verification or assurance that either functions as designed other than "hopefully we've found all the bugs by now" which is known to not be the case. Instead, a modern Operating System should build an ioring as the *first* and *primary* system interface, using a standardized interface definition schema that has explicit forward compatibility guarantees, and it should permit communication both with the kernel and with other processes. It should also explicitly be designed for programs that run on all cores. A singlethreaded, blocking IO API for a simple system can be implemented safely on top of a multithreaded, asyc API by just wrapping the more powerful API to provide the desired interface. However, there's no reason that an async multithreaded API can't be readily usable, it just requires not failing the fundamental design problem. Between fibril solving the multithreaded runtime problem, cilk's hyperobjects solving the shared data problem, and type theorists longstanding solutions for managing mutability and sharing being implemented by rust, and the increasing usability of async and promise based APIs, There is no excuse for future production compilers to not have implemented these decade-old solutions with enormous benefits.

A future OS should discard the thread abstraction as a component of the kernel interface and instead make every process operate on all cores at once. Current tech treats the thread which was designed as a unit of sequencing as the core primitive, bolted on core affinity, then demanded that individual programs build a per core compute pool in userspace, resulting in modern high performance programs needing to invent a worker pool and then invent a new "greenthreads" sequencing primitive/abstraction on that instead to provide higher performance; instead future OSes should provide the core-associated worker pool abstraction and async IO as the primitive operations, and allow programs to reinvent legacy style threads in userspace if they need them, or use a higher performance lighter weight abstraction. By integrating a Causal DAG into the ioring infrastructure and having promise pipelining, we can allow work to move and split smoothly between multiple cores, and to queue up significant batches of operations before yielding control to the kernel, which can then dispatch and route them in bulk before scheduling a process. Having work scheduled in bulk means that when a process recieving that work gets scheduled it can read and respond to all the work at once while its resources remain in cache, which amortizes the context switching and core sync costs across a larger number of requests, greatly increasing throughput and even allowing reduced latency.

To improve performance further, we can reduce the copying required to route and serve requests; by building the ioring on a collection of buffers and using a captable to designate requests (or ideally having some kind of cap-pointer-aware hardware to handle the cap delegation, but that's futher away), we can have a per core pool of fixed size buffers which can be claimed without locks or context switches in very few cycles, and forbid modification on the buffers once they are submitted to that core's queue. By having a small pool per core so that the buffers remain in cache from when they arrive in the processor's queue, so that the performance of assembling such a request is on par with assembling a struct on the stack for a system call, but without the large expense of actually performing the system call, and capable of specifying a much larger batch of work via promise pipelined request chains. With this architecture, when the kernel handles the sequence of IO requests for a program on a core, it can ignore the actual data buffers for the most part, read just the cap table and the specified reciever, rewrite the captable for the context of the reciever's process, and then update the memory mapping to remove the buffer from the origin process's address space and add it to the receiver process's address space and add it to the incoming queue on the same core, keeping it in cache. By ensuring that IPC messages are recieved on the same core in which they are sent in the usual fast path (with workstealing as usual to allow other cores to distribute the work when it's unbalanced without paying for sync when it's balanced) we dramatically reduce the cost and latency of IPC requests, and make it both more secure and easier to program against. When a process is finished with an incoming message and releases it, that buffer is cleared and becomes available to then immediately use for outgoing messages and remains in cache. If buffers become unbalanced, they can be surrendered to the OS or other cores in batches to amortize sync costs, and cache line aligned buffers ensures minimal cross-core cache contention however buffers end up wandering through the system.

## Univeral Typed Serialization

Very little of the data being processed by a computer is text; most of it is structured data. Even most data that's nominally text is actually structured data containing text or a serialized format of structured data, possibly both. This has both been loadbearing for much of computational history and caused many problems. Let's first focus on the strengths of this approach before we get into weaknesses and improvements. The usage of "plain text" representations means that someone familiar with the protocol can reliably inspect and author things directly in the protocol using ordinary keyboards and displays without needing additional custom tooling for every single protocol. Essentially, if specialist tools are broken or NYI it's possible to fall back onto generalist tools (as long as you still have the specialist knowledge). This is tremendously valuable when bootstrapping and debugging a protocol or an application using it. We are now at a place in computing where we can (mostly) assume the universal availability of program tools.

I have never in my life used a front panel switch to edit memory, or used a punch card to load a program. I vaguely know how to, because it's neat, but I've never actually been able to physically touch one, and I might not ever get the chance since the Living Computers Museum closed down. Instead, I have doom emacs and vscode on my desktop and laptop as my primary text editors, with vim and nano as backups. I have `bat` to read text files, and rg to search them in bulk. I have multiple minimal text editors on my phone because they're just so light as to be negligible and end up packaged with other stuff. I have diff tools and hex editors that are integrated into my IDEs and ones that stand alone. My editors have language server support providing rich format-specific assistance, autocomplete, and lots of navigation and editing features. Even `nano` has syntax highlighting by default. I have fully reproducible and rollbackable configuration applied universally to my computers, so that if I mess up a configuration, I can essentially always revert it instantly with no fuss, and if I can't I can straight-forwardly burn it down and replace it with an ISO built from another device in (theoretically) under an hour. The backup to my backup that gets invoked if I have somehow borked both of my primaries and my backup so badly that they're unusable simultaneously, is still a more powerful editor than people originally wrote some of the software I use in. Please take a moment to appreciate what a monumental achievement it is for me to be able to say: I will never be without an editor ever again. I will always have my tools. I will never have to read or edit data for a computer without using a computer ever again. When was the last time you didn't have a powerful text editor when you needed one? Has it ever happened to you? (And did you actually not *have* one or was it just over here but the file is over there and telling the system to use the editor here on the file there is hard?) Do you even know anyone it has happened to?

The usage of plain text and the development of the modern software ecosystem means that I can essentially always have a tool that knows how to read and write absolutely any piece of configuration, code, script, or communication going on in my system. Except for all the ones it can't, we'll get back to that. But still, it's absolutely wonderful to have that ability, and we must never give it up going forwards.

Storing and transmitting data as human readable text also helps making line noise and data corruption that breaks the parsing of the file stand out more and be easier to correct by hand. And can I just say how delighted I am to live in an era where that doesn't happen any more, where mysterious files with unprintable characters never just show up in whatever directory I'm working in because a stray noise from a falling book got into the modem and set some bits in a file name in my command. All of our networking equipment uses error correcting codes for every single codon sent down the wire and tests the checksum of every packet. We send most things through encrypted network channels that do their own separate integrity checks on top of the error correcting codes and integrity checks the networking equipment does. Package managers check the hash of every single file they download. Modern file systems compute and test content integrity hashes on *every single write and read*. Even the RAM is error correcting now! (in servers mainly, but it's getting more widespread every year) Bitsquatting/Raysquatting is a curiousity, not a serious existential threat to the integrity of the internet, a constantly spinning game of russian roulette that delivers viruses directly into the package managers and project source code and dependency libraries of every programmer.

More seriously, text is useful for being able to plumb tools together; various text formats are easy to pipe from one to the next (more or less). I've been able to write some really convenient scripts that gathers a list of things with one command, filters or gathers it somehow, and then applies an operation to every element with another, using things like xargs or for loops. And to link back to editor/viewer ubiquity, while developing such a pipeline I can always just run part of it and directly inspect what it has in the middle of its work. One of the things I really admire about the design of plan9 and forks is the extension of "everything is text" with "everything is a file", which means that we can, in principle, script absolutely any system facility with simple text and file manipulation commands. For example, plan9 provides a `ps` command very similar to linux's which provides nicely formatted legible output of what processes are running, however pretty formatting makes parsing harder. Instead, `/proc/*/status` provides similar information about the process directly from the kernel on request, in a simple columnar format for easy reading and parsing. I have an example output of these courtesy of [Avery Thorn](https://avery.garden/users/thorn). It looks like this:

> term% cat */status
> bootrc                      glenda                      Await                 0          30       72110          10          50           0         340          10          10
> mntgen                      glenda                      Pread                 0           0       72060           0           0           0         184          10          10
> mntgen                      glenda                      Pread                 0           0       72070           0           0           0         184          10          10
> mntgen                      glenda                      Pread                 0           0       72070           0           0           0         184          10          10
> factotum                    glenda                      Rendez               20           0       71680           0           0           0         364          10          10
> hjfs                        glenda                      Pread                 0          50       71600           0           0           0        7872          10          10
> hjfs                        glenda                      Rendez               40          30       71590           0           0           0        7872          10          10
> hjfs                        glenda                      Rendez               10           0       71580           0           0           0        7872          10          10
> hjfs                        glenda                      Pread                 0           0       71570           0           0           0        7872          10          10
> hjfs                        glenda                      Sleep                 0           0       71570           0           0           0        7872          10          10
> cs                          glenda                      Pread                 0           0       71410           0           0           0         204          10          10
> aoesweep                    glenda                      Wakeme                0           0       72070           0           0           0           0          13          13
> dns                         glenda                      Pread                10           0       71280           0           0           0         372          10          10
> timesync                    glenda                      Sleep                 0           0       68140           0           0           0         108          19          19
> pager                       glenda                      Idle                  0           0       72120           0           0           0           0          13          13
> rxmitproc                   glenda                      Wakeme                0           0       72080           0           0           0           0          13          13
> webcookies                  glenda                      Pread                 0           0       68050           0           0           0         208          10          10
> webfs                       glenda                      Pread                 0           0       68030           0           0           0         232          10          10
> plumber                     glenda                      Pread                 0          10       68010           0           0           0         328          10          10
> igmpproc                    glenda                      Wakeme                0           0       72080           0           0           0           0          13          13
> plumber                     glenda                      Rendez                0           0       68010           0           0           0         328          10          10
> rc                          glenda                      Pread                 0           0       66960           0          10           0         212          10          10
> etherread4                  glenda                      Wakeme                0         120       66870           0           0           0           0          13          13
> etherread6                  glenda                      Wakeme                0           0       66870           0           0           0           0          13          13
> recvarpproc                 glenda                      Wakeme                0           0       66870           0           0           0           0          13          13
> ipconfig                    glenda                      Sleep                 0           0       66860           0           0           0         208          10          10
> listen1                     glenda                      Open                  0          10       66830           0           0           0          48          10          10
> #I0tcpack                   glenda                      Wakeme                0          40       74980           0           0           0           0          13          13
> rc                          glenda                      Await                 0          40       72960           0           0           0         216          10          10
> factotum                    glenda                      Pread                40           0       72930           0           0           0         368          10          10
> #l0lproc                    glenda                      Wakeme                0           0       80270           0           0           0           0          13          13
> kbdfs                       glenda                      Pread                 0          10       57870           0           0           0         352          10          10
> kbdfs                       glenda                      Rendez                0           0       57870           0           0           0         352          10          10
> kbdfs                       glenda                      Pread                 0          80       57870           0           0           0         352          10          10
> kbdfs                       glenda                      Rendez                0           0       57870           0           0           0         352          10          10
> #l0rproc                    glenda                      Wakeme                0         100       80280           0           0           0           0          13          13
> kbdfs                       glenda                      Rendez                0           0       57880           0           0           0         352          10          10
> rc                          glenda                      Await                 0           0       57880           0           0           0         212          10          10
> webcookies                  glenda                      Pread                 0           0       57860           0           0           0         208          10          10
> webfs                       glenda                      Pread                 0           0       57860           0           0           0         232          10          10
> plumber                     glenda                      Pread                 0           0       57850           0           0           0         328          10          10
> plumber                     glenda                      Rendez                0           0       57860           0           0           0         328          10          10
> mouse                       glenda                      Wakeme                0           0       80330           0           0           0           0          13          13
> rio                         glenda                      Rendez               20          40       57860           0           0           0         628          10          10
> rio                         glenda                      Pread                 0         130       57840           0           0           0         628          10          10
> rio                         glenda                      Pread                10          30       57840           0           0           0         628          10          10
> rio                         glenda                      Rendez                0           0       57830           0           0           0         628          10          10
> rio                         glenda                      Pread                10           0       57840           0           0           0         628          10          10
> stats                       glenda                      Sleep                10          10       57830           0          10           0         240          10          10
> rc                          glenda                      Await                 0           0       57810           0           0           0         232          10          10
> stats                       glenda                      Pread                 0           0       57730           0           0           0         200          10          10
> stats                       glenda                      Pread                 0           0       57730           0           0           0         204          10          10
> stats                       glenda                      Pread                10          20       57730           0           0           0         244          10          10
> closeproc                   glenda                      Wakeme                0           0       23980           0           0           0           0          13          13
> kbdfs                       glenda                      Pread                 0           0       80260           0           0           0         380          16          16
> kbdfs                       glenda                      Rendez               10          30       80270           0           0           0         380          16          16
> alarm                       glenda                      Wakeme                0           0       80350           0           0           0           0          13          13
> kbdfs                       glenda                      Rendez                0           0       80270           0           0           0         380          16          16
> kbdfs                       glenda                      Pread                 0           0       80270           0           0           0         380          16          16
> kbdfs                       glenda                      Pread                 0           0       80270           0           0           0         380          16          16
> kbdfs                       glenda                      Rendez                0           0       80270           0           0           0         380          16          16
> paqfs                       glenda                      Pread               230          30       80340           0           0           0         780          10          10
> init                        glenda                      Await                 0          40       80180          60         190           0          88          10          10

Beyond simple single element lists like I discussed earlier, a tab separated value multi column data table like this one can be easily transformed to isolate just what is needed for input to another with a single easy to write command. Which command? Well, I don't quite remember off the top of my head... What do the columns mean and what is valid in them? Well, I'd need to check the docs... Actually, is it tab separated? Can you tell the difference between fixed width space padded fields and tab separated fields visually? So, as useful as having easy-to-parse text as a common interchange format is, "text" isn't actually a format. Text could be parsed many different ways, and the commonly used formats for scripting in linux and plan9 system interfaces are tabular, non-self-describing formats, which means they can't store anything more complex than an array of structs of simple data. This is fine for a lot of the simple data that has been used historically, because a lot of data is actually that shape, and it assumes that people will look up man pages for the meaning of every element because modern IDEs didn't exist and couldn't present autocomplete lists of fields and documentation on the fly between keystrokes, and that people could reliably either hand-roll a parser or use a C library for the format, which is no longer the case as languages safer than C with consequently more restricted ffis proliferate and more complicated data formats are required for more of our data (and as tools get better at presenting layouts that are more legible but more complicated to machine parse (which is one of the things that makes plan9 style "there's just a file that gives the most basic format always there and the friendly tools and scripts use that")). So, while this style/feature/philosophy has been good in it's time and is still used by myself and many others to great effect, we should be able to make something better by now by using our novel ability to expect powerful and rich libraries and language features as well as UI/UX both in TUIs and GUIs to be effectively omnipresent.

Before we move on to that, let's take note of the nice things this model provides:
- Authentication is a separated concern; no script that just wants to use some resource needs to know how to authenticate for it, the file's just there and the OS handles authenticating for it.
    - Acquiring/granting authentication to a service is just mapping/mounting a file or using a single "set permission primitive
- Transport agnostic: an app doesn't need a network stack and can't really know or care whether a file is provided by the kernel, another local service, a local program proxying an out-of-band remote service, or a remote file mount exposing a remote service
- Software can run anywhere it makes sense to: a script can be run on my machine with local UI and given access to a remote service, or run on a remote machine with local access to the service and a remote connection to my UI
- General purpose fallbacks/text is forever: if all else fails, I can manually inspect and invoke the protocol with simple omnipresent tools
- Liskov Substitution: Everything is hidden behind the interface (which is "simple" in some important way) so implementations can be swapped without breaking downstream software
And some problems
- Poor standardization: proliferation of fragile ad hoc parsers and serializers puts everyone in compatibility and special case hell
- Programs given the full authority of their invoker by default
    - Confused deputy
- Text is not a format: Stop making me write parsers every time I want a field, please let me use my language and write `foo.name` or whatever.
- Finding out what a piece of data means or how to use an interface can be hard
- Stringly typed

Json! Json has field names that explain what each of the columns means, and you can really easily use `jq` to manipulate json, extracting fields as easily as `.x`. More advanced usage of jq can use higher order functions to express powerful manipulations of nested data structures. I actually once got paid for writing a one line jq script that extracted some data from a proprietary json file and produced an ordinary text output. But then the output of that wasn't in json, so I'd need to do string parsing if I wanted to do another data manipulation operation in sequence. Actually, most of my tooling and files aren't in json, so we would need a large suite of converters to switch to json incrementally, and we'd also run into the issue of json not being self-describing enough: let's say you find a json object that looks like `{"x": 7, "y": 4}`; you can tell that it has fields x and y, but can you tell what those mean? What origin are the coordinates relative to? Are they integer grid coordinates in a digital grid, fractional millimeter coordinates on a 3d printer bed, meter coordinates for where to place a stack in a warehouse, or an entry denoting that the seventh person I'm no longer dating had the relationship end for the fourth reason in their respective tables? JSON-LD can come to our assistance, turning our object into `{"@context": {"Pos": "https://schema.org/GeoCoordinates", "x": "https://schema.org/latitude", "y": "https://schema.org/longitude"}, "@type": "Pos", "x": 7, "y": 4}` which unambiguously declares that it represents a lat-lon pair designating a position in a field just north of Ijebu Igbo in Nigeria... I think. Does longitude count east or west? At the time of writing, neither the linked schema nor the wikipedia page it links to actually states directly, but one of the worked examples suggests that a negative longitude corresponds to a western longitude. It has also made our json 10 times longer and thus cost 10 times as many cpu cycles and wire bytes to generate, transfer, and parse, which brings us to the second problem with "text" as a format, besides being underspecified, inconsistent, and difficult to work with; it's extremely high overhead: floating point number parsing is quite expensive, and the field names are usually just wasted space given a schema. Also JSON-LD is only available after retrieving data, not before, so we can't check an operation before running it, and can't provide convenience features for the input of the command because the direction of dataflow is wrong.

RDF-like formats are designed so that we can integrate facts from wherever we find them into a shared ontology and perform data-work on that knowledgebase, they aren't designed to model invoking tools or for caring about whether or not some party should know something, just for assembling all the knowledge available and being able to operate on it regardless of source; they're designed to be able to be bolted onto the side of arbitrary documents to enable machines to read info from them with minimal agreement ahead of time. This is quite useful, but not quite what we want for our ideal operating system, so we'll have to look elsewhere. But let's make note of the valuable properties that this does provide:
- shared ontologies of schemas for commonly interchanged objects constructed by Very Serious People so that two applications that have never heard of each other can still interoperate because there's a good schelling point
- every type and field has full pages of documentation and examples across multiple formats accessible without needing to pay for it (fuck the ISO by the way) which is linked directly from the data
- it's extensible so that if a single application needs more data than the ontology originally supported it can just add those as nonschematized fields and potentially mark them as schematized later if they later get standardized
- support for multiple authoritative bodies with separation of concerns
- Referencing other entities/files/data is meaningful and it is generally possible to actually follow references without problems
- Can be stuck onto other document or data formats to represent content in a machine readable form and mark what part of the document provides what data.
Let's also make explicit the shortcomings:
- too expensive for load bearing services to use, so there's a constant temptation to avoid it on big important core projects, requiring special treatment
- Assumes single point of authority for information about something and no authority required for reading
- declarative-only ontology; no interrogatives or imperatives
    - You can say "The latest version of this software is $foo" but not "please deploy version $foo of this software to $server"
        - it doesn't have subjunctives either so you also can't say "I think that $server should be running version $foo of this software"
        - If you decide to use an HTTP PUT verb to say "become this state instead", the format can't help you
            - Which HTTP authentication method does it use, and how does the script or application get access to the key?
            - Do you put the entire document at once, or can you use a subpath?
                - If you can use subpaths, how do you handle converting names from the json field names and schema relation ids containing non-url-safe characters to paths? Do you use the schema references or json field names?
                - If you use the whole document, how do you handle concurrent modifications? Which one wins?
                    - Do you have a full CRDT system entirely outside the scope of the protocol standard that needs to be coordinated and implemented in everything that talks to this server?
    - SPARQL does exist, but that is an entirely separate language
- Too many formats: in addition to JSON-LD, RDFa and microdata are also widely deployed ways to embed RDF data into hypertext documents, and there are some pages with all three storing different data. The Turtle format is also designed to be embeded in HTML, and there are a half dozen other formats also in use.

So, JSON-LD isn't suitable, what if we use a different JSON schema system? Like Swagger/OpenAPI?

Hmm, perhaps I should get to the point. Swagger/OpenAPI are bad at reusability and interoperability, but they are very nice for figuring out how to use an HTTP/REST application. Also JSON doesn't actually have semantics, just syntax, and that's a whole headache of its own.

What we need for an operating system is a single format that has all of the following properties:
- Fully schematized with rich doc comments
- Write the parser/parser generator once per language and reuse it everywhere
    - Absolutely no ad-hoc/bespoke parsers for the format
- Not tied to a single language or system (programming or human); acts as if native in all of them
    - Schema can be fully translated to another language, including field and type names if necessary, without compromising interoperability
        - ALL primary identifiers in the schema are internally represented as UIDs/GUIDs, and this detail is not intrusive to human use
        - Mechanically verify that a translation of a schema hasn't changed any machine-relevant details
    - Can be operated something resembling idiomatically with ordinary language features in shell, scripting, applications, and system languages
        - Very low syntactic noise for the library and/or generated code and/or operators
- Can be called and read with mostly existing tooling on existing systems, no "swap the whole world at once or it doesn't work"
- Moderately expressive type system
- Forward compatibility
    - It is easy to write a schema (and software using that schema) that will continue to work when things are added to the schema
        - It is mechanically checked if a particular change to the schema could break anything anywhere
    - Versioned interfaces to allow clean compatibility breaks with continued legacy support
- Shared schemas: A standardizing body can write and publish a schema and everything else can just reference that schema without needing to copy-paste.
    - Some understanding of regions of authority and separations of concern, that different authorities work on different things and can't unilaterally modify each other's schemas
- Extensibility: A shared schema can have extension points and the format provides a principled mechanism to attach extra data to it
    - The extra data is also schematized but may have a different authority than the originating mechanism
    - This must not require writing FQDN strings.
- Compact and efficient
    - Must be really really fast to read and write to avoid the temptation to make a bespoke binary format instead of using just using the common format
        - Avoiding separate stage and parse phases to be able to zero-copy work directly in a buffer would be ideal
    - Must compress well for transport
    - Simple and natural code to use it must be very fast
- Introspectable with OS support
    - If we find a message of data or a reference to an interface lying around, we should be able to retrieve the full backing schema (in our native language if available) and know exactly what type it is
        - Then we should be able to dynamically enumerate and read fields or methods or elements or whatever
        - There should be well maintained tools for this everywhere that are flexible and powerful and extensible and integrated with other tools as convenient
    - IT DOESN'T WORK IN ISOLATION
        - We don't need to do it without the OS
        - If you find a random most-of-a-message on a wiped/damaged hard drive in the trash, you shouldn't expect to be able to read it
        - If you intercept a random network packet mid-stream you shouldn't expect to be able to read it
            - Also most network streams should be encrypted well enough that others can't read them at all
- Interfaces and ocaps
    - secure references to objects
    - free creation of objects
    - no ambient authority
- Searchable directory of schemas so that people can find what people already made to facilitate their application
- Able to represent structured data well enough for ordinary purposes
    - Structs/records
    - Arrays
    - Maps of simple-to-any
    - All the ordinary primitives
    - Byte buffers
    - Text
- Promise pipelining so we can queue up many requests
    - Promise pipelining must work on primitives
- Transport agnostic: can access local or remote resources through whatever connection is convenient without forcing every script or app to care how it connects
- Essentially everything in the system accessible through the format, system call equivalents, every core service, UI systems, databases, etc.
- Can represent existing common data representations so that we can have a single common adapter layer that needs to care about a foreign representation and everything else can use the common data features
    - Can freely swap what adapter layer is used if it's interface compatible
    - Don't need to rewrite every protocol and parser in every language