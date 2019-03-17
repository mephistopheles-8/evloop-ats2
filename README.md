# Asyncnet

Asyncnet is a work-in-progress, low-level async networking library implemented in ATS2.

Right now it's in the testing phases / under development. 

One can use the main prinitive, `async_tcp_pool`, or a direct interface to any of the
backends. Check the `TEST` directory for usage.  I aim to refine the primatives 
to better suit practical use scenarios over time. 

## Why?

ATS2 can be used to write highly performant, formally verified low-level code.  There
is a shortage of libraries, however.  Bindings exist for ZeroMQ and Libevent, but
I have yet to find something of the ilk implemented entirely in ATS2.

The semantics of system APIs can be confusing to the  uninitiated, and I wanted
to ensure my implementation was as correct as possible.  ATS2 helps make many of the
nuances explicit.

## Design

- I aimed to maintain decent interop with `atslib`, which may have made the code more verbose.
- In the testing phases, correctness is valued over other things.  Right now, exceptions are turned
  on, even for trivial things (like calling `close` on an invalid file descriptor).  I have yet
  to encounter any problems, though it may not be suitable for production.

## Backends

Asyncnet currently supports the following backends.  To use, compile
with the given flag:
- Epoll (`-DATS ASYNCNET_EPOLL`)
- Kqueue (`-DATS ASYNCNET_KQUEUE`)
- Select (`-DATS ASYNCNET_SELECT`)
- Poll   (`-DATS ASYNCNET_POLL`)

I have tested these on Linux and OpenBSD.

### License

This has been released under the MIT license.
