
#ifndef _ASYNCNET_LIB
#define _ASYNCNET_LIB

staload "libats/libc/SATS/sys/socket.sats"
staload "libats/libc/SATS/netinet/in.sats"

staload "./SATS/socketfd.sats"
staload "./SATS/bufptr.sats"
staload _ = "./DATS/socketfd.dats"

#ifdef ASYNCNET_EPOLL
staload "./SATS/epoll.sats"
staload _ = "./DATS/epoll.dats"
#endif

staload "./SATS/async_tcp_pool.sats"

#ifdef ASYNCNET_EPOLL
staload _ = "./DATS/async_tcp_pool_epoll.dats"
#endif

#endif
