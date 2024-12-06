# Technical problems and social solutions in version control

A phrase that's been making the rounds through my friend group is "don't try to solve a social problem with a technical solution." This means things like if the problem is that people don't want to talk to each other between teams that need to coordinate, deploying a highly configurable and sophisticated integrated email, ticketing, and project tracking system to make it easier for them to talk will not make them want to talk, and will just give them more complicated ways to not try to talk. If people want to spread misinformation, giving powerful tools for spreading information results in spreading more misinformation faster. And if people don't trust you, no amount of signature verification or DRM will ever make them trust you; you need to use a social solution and put your cards on the table and show people reasons to trust you, and to talk to each other, and to put in the effort to stop lying all the time.

And of course, there's a corrolary; "don't try to solve a technical problem with a social solution." Making people want to work together and feeling like they can genuinely trust and connect with each other is great, but if they don't have a way to build a communal knowledge base or actually get in contact with each other and share information, or if every single message might have been faked by a malicious third party, trying more social solutions won't help and could even hurt. You need to actually build a bridge before the cart can travel.

Recently, a friend said "git merge resolution is trying to solve a social problem (two people editing the same file) with a technical solution (a fucked up merge resolution process that make everyone scared so they just git reset --HARD and copy paste in the correct files).". This is very wrong, and in this post I intend to take it apart and explore why.

# Two people editing the same file is actually a technical problem

Why would two people ever edit the same file? One possible reason is that the file contains things which touch multiple concerns, and multiple people are trying to update those multiple concerns in different directions, thus producing conflicts for the file. But why are multiple concerns in a file?

Trying to solve that technical problem with a social solution is not only doomed to failure, but has failed repeatedly in practice
Disentangling the social problems from the technical ones.
How git solves the core technical problem.
Problems with git.
Well known solutions to additional problems in the git ecosystem.
New solutions to other problems in the git ecosystem.
Speculative future solutions and alternatives to git
