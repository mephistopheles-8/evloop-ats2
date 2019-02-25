
#include "./../HATS/project.hats"

staload "libats/libc/SATS/signal.sats"
staload "libats/libc/SATS/sys/socket.sats"
staload "./../SATS/socketfd.sats"

%{#
#include <sys/epoll.h>
%}

abst@ype epoll_behaviour = int
// File: /usr/include/bits/epoll.h
macdef EPOLL_CLOEXEC   = $extval(epoll_behaviour,"EPOLL_CLOEXEC")
macdef EP0             = $extval(epoll_behaviour, "0")

abst@ype epoll_event_kind = uint32
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

fn epoll_event_kind_lor ( epoll_event_kind, epoll_event_kind ) 
  :<> epoll_event_kind

overload lor with epoll_event_kind_lor

castfn epoll_event_kind_uint32 ( epoll_event_kind ) 
  :<> uint32

symintr eek2ui
overload eek2ui with epoll_event_kind_uint32

abst@ype epoll_action = int
macdef EPOLL_CTL_ADD = $extval(epoll_action, "EPOLL_CTL_ADD")
macdef EPOLL_CTL_DEL = $extval(epoll_action, "EPOLL_CTL_DEL")
macdef EPOLL_CTL_MOD = $extval(epoll_action, "EPOLL_CTL_MOD")

absview epoll_v(int)

absvt@ype epollfd(int) = int

castfn 
epollfd_encode{fd:int}( epoll_v(fd) | int fd ) 
  : epollfd(fd)

castfn 
epollfd_decode{fd:int}( epollfd(fd) ) 
  : (epoll_v(fd) | int fd)

vtypedef epollfd = [fd:int] epollfd(fd)

viewdef ptr_v_1 (a:t@ype, l:addr) = a @ l

typedef epoll_data = $extype_struct"union epoll_data" of {
  ptr = ptr (* cPtr0(void) *),
  fd = int,
  u32 = uint32,
  u64 = uint64
}

typedef epoll_data_t = epoll_data

typedef epoll_event = $extype_struct"struct epoll_event" of {
  events = epoll_event_kind,
  data = epoll_data_t
}



castfn
epoll_data_fd( int ) : epoll_data_t 

castfn
epoll_data_socketfd( !socketfd0 ) : epoll_data_t 

castfn
epoll_data_ptr( ptr ) : epoll_data_t 

castfn
epoll_data_uint32( uint32 ) : epoll_data_t 

castfn
epoll_data_uint64( uint64 ) : epoll_data_t 


fun epollfd_close{fd:int}( epoll_v(fd) | int fd  )  
  : [err: int | err >= ~1; err <= 0] 
    ( option_v(epoll_v(fd), err == ~1) | int err ) = "mac#close"

fun epoll_create: {n:pos} (int n) -> [fd:int] (option_v(epoll_v(fd), fd > 0) | int fd) = "mac#epoll_create"
fun epoll_create1: (epoll_behaviour) -> [fd:int] (option_v(epoll_v(fd), fd > 0) | int fd) = "mac#epoll_create1"
fun epoll_ctl:   ( !epollfd, epoll_action, !socketfd0, &epoll_event ) -> intBtwe(~1,0) = "mac#epoll_ctl"
fun epoll_wait:  {n,m:nat | m <= n}( !epollfd, &(@[epoll_event][n]), int m, int) -> intBtwe(~1,m) = "mac#epoll_wait"
fun epoll_pwait: {n,m:nat | m <= n}(  !epollfd, &(@[epoll_event][n]), int m, int, &sigset_t) -> intBtwe(~1,m) = "mac#epoll_pwait"

fn epollfd_add0( efd: !epollfd, sfd: !socketfd0 ) 
  : intBtwe(~1,0) = "ext#%"

(** If we add an sfd to epoll, we are likely managing the connection
    via another process.  socketfd can be "free'd" without beeing closed. 
  
    These processes are the same as epollfd_add0 except they provide
    a proof, which lets us defer management of the sfd to another process
**)
absprop epoll_add_v(fd:int, st:status)

fn epollfd_add1{efd,fd:int}{st:status}( efd: !epollfd(efd), sfd: !socketfd(fd,st) ) 
  : [err: int | err >= ~1; err <= 0]
    (option_v(epoll_add_v(fd,st), err == 0) | int err )
  = "mac#%epollfd_add0"

prfn epoll_add_elim{fd:int}{st:status}( epoll_add_v(fd,st) ) : void

prfn epoll_add_sfd_elim{fd:int}{st:status}( epoll_add_v(fd,st), socketfd(fd,st) ) : void

absprop epoll_wait_v(l:addr, n:int)

fun epoll_wait1:  
  {n,m:nat | m <= n}{l:addr}{efd:int}
  ( !(@[epoll_event][n] @ l) | !epollfd(efd), ptr l, int m, int) 
  -> [o:int | o >= ~1 && o <= m]
     (option_v(epoll_wait_v(l,o), o > ~1) | int o ) = "mac#epoll_wait"


fun {env: vt@ype+}
  epoll_events_foreach$fwork{fd:int}{st:status}
  ( epoll_add_v(fd,st) | epoll_event_kind, socketfd(fd,st), &env >> _ )
  : void 

fun {env: vt@ype+}
  epoll_events_foreach{n,o:nat | o <= n}{l:addr}
  ( epoll_wait_v(l,o), !(@[epoll_event][n] @ l) | ptr l, int o, &env >> _ )
  : void


fn epollfd_create_exn () : epollfd

 
fn epollfd_close_exn{fd:int}(efd: epollfd(fd)) 
  : void

fn epoll_event_empty () : epoll_event

fn eq_socketfd_int {fd,n:int}{st:status}( sfd : !socketfd(fd,st), n: int n) 
  :<> [b:bool | b == (fd == n)] bool b 

fn eq_socketfd_socketfd {fd,fd1:int}{st,st1:status}( sfd : !socketfd(fd,st), sfd1 : !socketfd(fd1,st1)) 
  :<> [b:bool | b == (fd == fd1)] bool b 

overload = with eq_socketfd_int
overload = with eq_socketfd_socketfd

fn eek_has( e1: epoll_event_kind, e2: epoll_event_kind ) 
  :<> bool
