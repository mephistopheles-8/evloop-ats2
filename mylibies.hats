
#ifndef _ASYNCNET_LIB
#define _ASYNCNET_LIB

staload "libats/libc/SATS/sys/socket.sats"
staload "libats/libc/SATS/netinet/in.sats"

staload "libats/SATS/athread.sats"
staload _ = "libats/DATS/athread.dats"
staload _ = "libats/DATS/athread_posix.dats"


staload "./SATS/socketfd.sats"
staload "./SATS/bufptr.sats"
staload _ = "./DATS/socketfd.dats"

#ifdef ASYNCNET_EPOLL
staload "./SATS/epoll.sats"
staload _ = "./DATS/epoll.dats"
#elifdef ASYNCNET_KQUEUE
staload "./SATS/kqueue.sats"
staload _ = "./DATS/kqueue.dats"
#endif

staload "./SATS/async_tcp_pool.sats"

#ifdef ASYNCNET_EPOLL
staload _ = "./DATS/async_tcp_pool_epoll.dats"
#endif

#endif
