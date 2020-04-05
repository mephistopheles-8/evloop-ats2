
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
#elifdef ASYNCNET_SELECT
staload "./SATS/select.sats"
#elifdef ASYNCNET_POLL
staload "./SATS/poll.sats"
#endif

staload "./SATS/evloop.sats"

#ifdef ASYNCNET_EPOLL
staload _ = "./DATS/evloop_epoll.dats"
#elifdef ASYNCNET_KQUEUE
staload _ = "./DATS/evloop_kqueue.dats"
#elifdef ASYNCNET_SELECT
staload _ = "./DATS/evloop_select.dats"
#elifdef ASYNCNET_POLL
staload _ = "./DATS/evloop_poll.dats"
#endif

#endif
