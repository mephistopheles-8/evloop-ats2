
#include "./../HATS/project.hats"

(** libats imports **)
staload "libats/libc/SATS/sys/socket.sats"
staload "libats/libc/SATS/sys/socket_in.sats"
staload "libats/libc/SATS/netinet/in.sats"
staload "libats/libc/SATS/fcntl.sats"


absvt@ype socketfd(int,status) = int
vtypedef socketfd0 = [fd:int][st:status] socketfd(fd,st)
vtypedef socketfd1(st: status) = [fd:int] socketfd(fd,st)

(** ** ** ** ** ** **)

exception SocketfdCreateExn
exception SocketfdCloseExn of socketfd0

(** ** ** ** ** ** **)

castfn socketfd_encode
  {fd:int}{s:status}
  ( socket_v(fd, s) | int fd ) 
  : socketfd(fd, s)


castfn socketfd_decode
  {fd:int}{s:status}
  ( socketfd(fd, s) ) 
  : (socket_v(fd,s) | int fd)


castfn socketfd_fildes
  {fd:int}{s:status}
  ( socketfd(fd,s) ) 
  : [fd > 0] (socket_v(fd,s) | fildes(fd))


castfn fildes_socketfd
  {fd:int}{s:status}
  ( socket_v(fd,s) | fildes(fd) ) 
  : socketfd(fd,s)

absvt@ype sockopt(fd:int,st:status,b:bool) = int 
absvt@ype sockalt(fd:int,st1:status,st2:status,b:bool) = int 
vtypedef sockopt(st:status, b:bool) = [fd:int] sockopt(fd,st,b)


prfn sockopt_some{st:status}{fd:int}( &socketfd(fd,st) >> sockopt(fd,st,true)) 
  : void


prfn sockopt_none{st:status}{fd:int}( &socketfd0? >> sockopt(fd,st,false)) 
  : void


prfn sockopt_unsome{st:status}{fd:int}( &sockopt(fd,st,true) >> socketfd(fd,st))
  : void


prfn sockopt_unnone{st:status}{fd:int}( &sockopt(fd,st,false) >> socketfd(fd,st)? )
  : void


prfn sockopt_none_stat_univ{st1,st2:status}( &sockopt(st1,false) >> sockopt(st2,false) )
  : void


prfn sockalt_left{st1,st2:status}{fd:int}( &socketfd(fd,st1) >> sockalt(fd,st1,st2,true)) 
  : void


prfn sockalt_right{st1,st2:status}{fd:int}( &socketfd(fd,st2) >> sockalt(fd,st1,st2,false)) 
  : void


prfn sockalt_unleft{st1,st2:status}{fd:int}( &sockalt(fd,st1,st2,true) >> socketfd(fd,st1))
  : void


prfn sockalt_unright{st1,st2:status}{fd:int}( &sockalt(fd,st1,st2,false) >> socketfd(fd,st2))
  : void

fun socketfd_create
  ( sfd: &socketfd0? >> sockopt(init, b)
  , af: sa_family_t
  , st: socktype_t
  ) : #[b:bool] bool b

fun socketfd_set_nonblocking
  {fd:int}
  ( sfd: &socketfd(fd,init)
  ) : bool

fun socketfd_create_exn
  ( af: sa_family_t
  , st: socktype_t
  ) : [fd:int] socketfd(fd,init)

fun socketfd_create_opt
  ( af: sa_family_t
  , st: socktype_t
  ) : Option_vt(socketfd1(init))

fun socketfd_bind_in{fd:int}(
   sfd: !socketfd(fd,init) >> sockalt(fd,bind,init,b) 
 , sockaddr: &sockaddr_in
) : #[b:bool] bool b

fun socketfd_close_exn
  ( sfd: socketfd0
  ) : void

fun socketfd_close{fd:int}{st:status}
  ( sfd: &socketfd(fd,st) >> sockopt(fd,st,~b)
  ) : #[b:bool] bool b

typedef socketfd_create_bind_params = @{
    af= sa_family_t
  , st= socktype_t
  , nonblocking = bool
  , port= int
  , address = in_addr_nbo_t
}

fun socketfd_create_bind_port
  ( sfd: &socketfd0? >> sockopt(bind, b)
  , p : &socketfd_create_bind_params
  ) : #[b:bool] bool b

fun socketfd_listen{fd:int}
  ( sfd: &socketfd(fd,bind) >> sockalt(fd,listen,bind,b)
  , backlog : intGt(0)
  ): #[b:bool] bool b

fun socketfd_accept{fd:int}
  ( sfd: !socketfd(fd,listen)
  , cfd: &socketfd0? >> sockopt(conn,b)
  ): #[b:bool] bool b

typedef socketfd_setup_params = @{
    af = sa_family_t
  , st = socktype_t
  , nonblocking = bool
  , port = int
  , address = in_addr_nbo_t
  , backlog = intGt(0)
} 

prfn socketfd_params_intr{l:addr}
  ( pf : !socketfd_setup_params @ l 
  ): socketfd_create_bind_params @ l

prfn socketfd_params_elim{l:addr}
  ( pf1 : !socketfd_setup_params @ l
  , pf2 : socketfd_create_bind_params @ l
  ): void

fun socketfd_setup(
   sfd: &socketfd0? >> sockopt(listen,b)
 , params : &socketfd_setup_params
) : #[b:bool] bool b

fun socketfd_read
  {fd:int}{n,m:nat | m <= n}
  ( pf: !socketfd(fd,conn), buf: &bytes(n), sz: size_t m )
  : ssizeBtwe(~1,m) = "mac#read"

fun socketfd_write
  {fd:int}{n,m:nat | m <= n}
  ( pf: !socketfd(fd,conn), buf: &bytes(n), sz: size_t m )
  : ssizeBtwe(~1,m) = "mac#write"

fun socketfd_write_string
  {fd:int}{n,m:nat | m <= n}
  ( pf: !socketfd(fd,conn), str: string n, sz: size_t m )
  : ssizeBtwe(~1,m) = "mac#write"

fun socketfd_write_strnptr
  {fd:int}{n,m:nat | m <= n}
  ( pf: !socketfd(fd,conn), buf: !strnptr(n), sz: size_t m )
  : ssizeBtwe(~1,m) = "mac#write"

fun {env: vt@ype+} socketfd_accept_all$withfd( cfd: socketfd1(conn), &env >> _ )
  : void 

fun {env: vt@ype+} 
socketfd_accept_all{fd:int}( sfd: !socketfd(fd,listen), env: &env >> _ ) 
  : void
