# evloop

A thin ATS2 wrapper over system async APIs (`epoll`,`kevent`,`poll`),
modeled closely off of the [`libh2o`](https://github.com/h2o/h2o) event loop.

Works, but is in early stages.  This was intended to be a component
of a larger embedded server project.  Performance seems promising:

(`test02` HTTP/1.1 "Hello World," 4-cores @ 2.30GHz)
```
[mall0c@core-99 ~]$ wrk -t 3 -c 1000 http://localhost:8888/
Running 10s test @ http://localhost:8888/
  3 threads and 1000 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency     4.13ms    3.81ms  31.49ms   81.83%
    Req/Sec    78.82k    12.37k  115.36k    61.74%
  2351687 requests in 10.08s, 168.21MB read
Requests/sec: 233226.99
Transfer/sec:     16.68MB
```

## Backends

Asyncnet currently supports the following backends.  To use, compile
with the given flag:
- epoll (`-DATS ASYNCNET_EPOLL`)
- kqueue (`-DATS ASYNCNET_KQUEUE`)
- poll   (`-DATS ASYNCNET_POLL`)

This is known to work on Linux and OpenBSD, but has not been rigorously
tested.

LICENSE: MIT
