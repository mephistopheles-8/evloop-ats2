
#include "./../HATS/project.hats"

staload "libats/libc/SATS/signal.sats"
staload "libats/libc/SATS/sys/socket.sats"
staload "./../SATS/socketfd.sats"

%{#
#include <sys/epoll.h>
%}

abst@ype epoll_behaviour
// File: /usr/include/bits/epoll.h
macdef EPOLL_CLOEXEC   = $extval(epoll_behaviour,"EPOLL_CLOEXEC")
macdef EP0             = $extval(epoll_behaviour, "0")

abst@ype epoll_event_kind
macdef EPOLLIN         = $extval(epoll_event_kind,"EPOLLIN")
macdef EPOLLPRI        = $extval(epoll_event_kind,"EPOLLPRI")
macdef EPOLLOUT        = $extval(epoll_event_kind,"EPOLLOUT")
macdef EPOLLRDNORM     = $extval(epoll_event_kind,"EPOLLRDNORM")
macdef EPOLLRDBAND     = $extval(epoll_event_kind,"EPOLLRDBAND")
macdef EPOLLWRNORM     = $extval(epoll_event_kind,"EPOLLWRNORM")
macdef EPOLLWRBAND     = $extval(epoll_event_kind,"EPOLLWRBAND")
macdef EPOLLMSG        = $extval(epoll_event_kind,"EPOLLMSG")
macdef EPOLLERR        = $extval(epoll_event_kind,"EPOLLERR")
macdef EPOLLHUP        = $extval(epoll_event_kind,"EPOLLHUP")
macdef EPOLLRDHUP      = $extval(epoll_event_kind,"EPOLLRDHUP")
macdef EPOLLEXCLUSIVE  = $extval(epoll_event_kind,"EPOLLEXCLUSIVE")
macdef EPOLLWAKEUP     = $extval(epoll_event_kind,"EPOLLWAKEUP")
macdef EPOLLONESHOT    = $extval(epoll_event_kind,"EPOLLONESHOT")
macdef EPOLLET         = $extval(epoll_event_kind,"EPOLLET")


abst@ype epoll_action
macdef EPOLL_CTL_ADD = $extval(epoll_action, "EPOLL_CTL_ADD")
macdef EPOLL_CTL_DEL = $extval(epoll_action, "EPOLL_CTL_DEL")
macdef EPOLL_CTL_MOD = $extval(epoll_action, "EPOLL_CTL_MOD")


absvt@ype epollfd(int) = int
vtypedef epollfd = [fd:int] epollfd(fd)

abst@ype epoll_data
 
typedef epoll_data_t = epoll_data

viewdef ptr_v_1 (a:t@ype, l:addr) = a @ l

typedef epoll_data = $extype_struct"union epoll_data" of {
  ptr = ptr (* cPtr0(void) *),
  fd = int,
  u32 = uint32,
  u64 = uint64
}
typedef epoll_event = $extype_struct"struct epoll_event" of {
  events = uint32,
  data = epoll_data_t
}
fun epoll_create: {n:pos} (int n) -> epollfd = "mac#epoll_create"
fun epoll_create1: (epoll_behaviour) -> epollfd = "mac#epoll_create1"
fun epoll_ctl:   ( !epollfd, epoll_action, !socketfd1(conn), &epoll_event ) -> int = "mac#epoll_ctl"
fun epoll_wait:  {n,m:nat | m <= n}( !epollfd, &(@[epoll_event][n]), int m, int) -> int = "mac#epoll_wait"
fun epoll_pwait: {n,m:nat | m <= n}(  !epollfd, &(@[epoll_event][n]), int m, int, &sigset_t) -> int = "mac#epoll_pwait"
