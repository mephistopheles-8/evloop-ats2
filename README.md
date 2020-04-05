# Asyncnet

A thin ATS2 wrapper over system async APIs (epoll,kevent,poll)

## Backends

Asyncnet currently supports the following backends.  To use, compile
with the given flag:
- epoll (`-DATS ASYNCNET_EPOLL`)
- kqueue (`-DATS ASYNCNET_KQUEUE`)
- poll   (`-DATS ASYNCNET_POLL`)

I have tested these on Linux and OpenBSD.

LICENSE: MIT
