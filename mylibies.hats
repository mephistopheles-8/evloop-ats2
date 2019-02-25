
staload "libats/libc/SATS/sys/socket.sats"
staload "libats/libc/SATS/netinet/in.sats"

staload "./SATS/socketfd.sats"
staload _ = "./DATS/socketfd.dats"

#ifdef ASYNCNET_EPOLL
staload "./SATS/epoll.sats"
staload _ = "./DATS/epoll.dats"
#endif
