
#include "./../HATS/project.hats"

staload "libats/libc/SATS/signal.sats"

%{#
#include <sys/epoll.h>
%}

absvt@ype epoll_event_kind
// File: /usr/include/bits/epoll.h
macdef EPOLL_CLOEXEC   = $extval(epoll_event_kind,"EPOLL_CLOEXEC")
// File: /usr/include/sys/epoll.h
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


absvt@ype epoll_ctl_action
macdef EPOLL_CTL_ADD = $extval(epoll_ctl_action, "EPOLL_CTL_ADD")
macdef EPOLL_CTL_DEL = $extval(epoll_ctl_action, "EPOLL_CTL_DEL")
macdef EPOLL_CTL_MOD = $extval(epoll_ctl_action, "EPOLL_CTL_MOD")

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
fun epoll_create: (int) -> int = "mac#epoll_create"
fun epoll_create1: (int) -> int = "mac#epoll_create1"
fun epoll_ctl: {l1:addr} (!ptr_v_1(epoll_event, l1) | int, int, int, ptr l1) -> int = "mac#epoll_ctl"
fun epoll_wait: {l1:addr} (!ptr_v_1(epoll_event, l1) | int, ptr l1, int, int) -> int = "mac#epoll_wait"
fun epoll_pwait: {l1,l2:addr} (!ptr_v_1(epoll_event, l1), !ptr_v_1(sigset_t, l2) | int, ptr l1, int, int, ptr l2) -> int = "mac#epoll_pwait"
