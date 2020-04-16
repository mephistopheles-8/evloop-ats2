
#include "./../HATS/project.hats"

(** libats imports **)
staload "libats/libc/SATS/sys/socket.sats"
staload "libats/libc/SATS/sys/socket_in.sats"
staload "libats/libc/SATS/netinet/in.sats"
staload "libats/libc/SATS/fcntl.sats"
%{#
/** Missing from libats **/
#define socket_AF_type(af,tp) socket(af,tp,0)
%}

absvt@ype sockfd(int,status) = int
absvt@ype sockfdout(int,status) = int
vtypedef sockfd0 = [fd:int][st:status] sockfd(fd,st)
vtypedef sockfd1(st: status) = [fd:int] sockfd(fd,st)
vtypedef sockfd(fd:int) = [st:status] sockfd(fd,st)
(** ** ** ** ** ** **)

exception SocketfdCreateExn
exception SocketfdCloseExn of sockfd0

(** ** ** ** ** ** **)

castfn sockfd_encode
  {fd:int}{s:status}
  ( socket_v(fd, s) | int fd ) 
  : sockfd(fd, s)


castfn sockfd_decode
  {fd:int}{s:status}
  ( sockfd(fd, s) ) 
  : (socket_v(fd,s) | int fd)

castfn sockfd_value
  {fd:int}{s:status}
  ( !sockfd(fd, s) ) 
  :<> int fd


castfn sockfd_fildes
  {fd:int}{s:status}
  ( sockfd(fd,s) ) 
  : [fd > 0] (socket_v(fd,s) | fildes(fd))

castfn sockfd_fildes1
  {fd:int}{s:status}
  ( !sockfd(fd,s) >> sockfdout(fd,s) ) 
  : [fd > 0] (fildes(fd))

castfn fildes_sockfd
  {fd:int}{s:status}
  ( socket_v(fd,s) | fildes(fd) ) 
  : sockfd(fd,s)

praxi fildes_sockfd1
  {fd:int}{s:status}
  ( !sockfdout(fd,s) >> sockfd(fd,s), fildes(fd)  ) 
  : void


absvt@ype sockopt(fd:int,st:status,b:bool) = int 
absvt@ype sockalt(fd:int,st1:status,st2:status,b:bool) = int 
vtypedef sockopt(st:status, b:bool) = [fd:int] sockopt(fd,st,b)


prfn sockopt_some{st:status}{fd:int}( &sockfd(fd,st) >> sockopt(fd,st,true)) 
  : void


prfn sockopt_none{st:status}{fd:int}( &sockfd0? >> sockopt(fd,st,false)) 
  : void


prfn sockopt_unsome{st:status}{fd:int}( &sockopt(fd,st,true) >> sockfd(fd,st))
  : void


prfn sockopt_unnone{st:status}{fd:int}( &sockopt(fd,st,false) >> sockfd(fd,st)? )
  : void


prfn sockopt_none_stat_univ{st1,st2:status}( &sockopt(st1,false) >> sockopt(st2,false) )
  : void


prfn sockalt_left{st1,st2:status}{fd:int}( &sockfd(fd,st1) >> sockalt(fd,st1,st2,true)) 
  : void


prfn sockalt_right{st1,st2:status}{fd:int}( &sockfd(fd,st2) >> sockalt(fd,st1,st2,false)) 
  : void


prfn sockalt_unleft{st1,st2:status}{fd:int}( &sockalt(fd,st1,st2,true) >> sockfd(fd,st1))
  : void


prfn sockalt_unright{st1,st2:status}{fd:int}( &sockalt(fd,st1,st2,false) >> sockfd(fd,st2))
  : void

fun {} sockfd_create
  ( sfd: &sockfd0? >> sockopt(init, b)
  , af: sa_family_t
  , st: socktype_t
  ) : #[b:bool] bool b

fun {} sockfd_set_nonblocking
  {fd:int}{st:status}
  ( sfd: !sockfd(fd,st)
  ) : bool

fun {} sockfd_set_cloexec
  {fd:int}{st:status}
  ( sfd: !sockfd(fd,st)
  ) : bool

fun {} sockfd_set_reuseaddr
  {fd:int}{st:status}
  ( sfd: !sockfd(fd,st)
  ) : bool

fun {} sockfd_set_nodelay
  {fd:int}{st:status}
  ( sfd: !sockfd(fd,st)
  ) : bool

fun {} sockfd_get_error_code
  {fd:int}{st:status}
  ( sfd: !sockfd(fd,st)
  ) : int

fun {} sockfd_get_error_string
  {fd:int}{st:status}
  ( sfd: !sockfd(fd,st)
  ) : string

fun {}  sockfd_create_exn
  ( af: sa_family_t
  , st: socktype_t
  ) : [fd:int] sockfd(fd,init)

fun {} sockfd_create_opt
  ( af: sa_family_t
  , st: socktype_t
  ) : Option_vt(sockfd1(init))

fun {} sockfd_bind_in{fd:int}(
   sfd: !sockfd(fd,init) >> sockalt(fd,bind,init,b) 
 , sockaddr: &sockaddr_in
) : #[b:bool] bool b

fun {} sockfd_close_exn{fd:int}{st:status}
  ( sfd: sockfd(fd,st)
  ) : void

fun {} sockfd_close{fd:int}{st:status}
  ( sfd: &sockfd(fd,st) >> sockopt(fd,st,~b)
  ) : #[b:bool] bool b

typedef sockfd_create_bind_params = @{
    af= sa_family_t
  , st= socktype_t
  , nonblocking = bool
  , reuseaddr   = bool
  , nodelay = bool
  , cloexec = bool
  , port= int
  , address = in_addr_nbo_t
}

fun {} sockfd_create_bind_port
  ( sfd: &sockfd0? >> sockopt(bind, b)
  , p : &sockfd_create_bind_params
  ) : #[b:bool] bool b

fun {} sockfd_listen{fd:int}
  ( sfd: &sockfd(fd,bind) >> sockalt(fd,listen,bind,b)
  , backlog : intGt(0)
  ): #[b:bool] bool b

fun {} sockfd_accept{fd:int}
  ( sfd: !sockfd(fd,listen)
  , cfd: &sockfd0? >> sockopt(conn,b)
  ): #[b:bool] bool b

typedef sockfd_setup_params = @{
    af = sa_family_t
  , st = socktype_t
  , nonblocking = bool
  , reuseaddr   = bool
  , nodelay = bool
  , cloexec = bool
  , port = int
  , address = in_addr_nbo_t
  , backlog = intGt(0)
} 

prfn sockfd_params_intr{l:addr}
  ( pf : !sockfd_setup_params @ l 
  ): sockfd_create_bind_params @ l

prfn sockfd_params_elim{l:addr}
  ( pf1 : !sockfd_setup_params @ l
  , pf2 : sockfd_create_bind_params @ l
  ): void

fun {} sockfd_setup(
   sfd: &sockfd0? >> sockopt(listen,b)
 , params : &sockfd_setup_params
) : #[b:bool] bool b

fun sockfd_read
  {fd:int}{n,m:nat | m <= n}
  ( pf: !sockfd(fd,conn), buf: &bytes(n), sz: size_t m )
  : ssizeBtwe(~1,m) = "mac#read"

fun sockfd_write
  {fd:int}{n,m:nat | m <= n}
  ( pf: !sockfd(fd,conn), buf: &bytes(n), sz: size_t m )
  : ssizeBtwe(~1,m) = "mac#write"

fun sockfd_write_string
  {fd:int}{n,m:nat | m <= n}
  ( pf: !sockfd(fd,conn), str: string n, sz: size_t m )
  : ssizeBtwe(~1,m) = "mac#write"

fun sockfd_write_strnptr
  {fd:int}{n,m:nat | m <= n}
  ( pf: !sockfd(fd,conn), buf: !strnptr(n), sz: size_t m )
  : ssizeBtwe(~1,m) = "mac#write"

fun 
{env:vt@ype+}
sockfd_readall$fwork{n:nat}( buf: &bytes(n), sz: size_t n, &env >> _ )
: bool

fun 
{env:vt@ype+}
sockfd_readall
  {fd:int}{n,m:nat | m <= n}
  ( pf: !sockfd(fd,conn), buf: &bytes(n), sz: size_t m, &env >> _ )
  : bool

fun {env: vt@ype+} sockfd_accept_all$withfd( cfd: sockfd1(conn), &env >> _ )
  : bool 

fun {env: vt@ype+} 
sockfd_accept_all{fd:int}( sfd: !sockfd(fd,listen), env: &env >> _ ) 
  : void

fun {} eq_sockfd_int {fd,n:int}{st:status}( sfd : !sockfd(fd,st), n: int n) 
  :<> [b:bool | b == (fd == n)] bool b 

fun {} eq_sockfd_sockfd {fd,fd1:int}{st,st1:status}( sfd : !sockfd(fd,st), sfd1 : !sockfd(fd1,st1)) 
  :<> [b:bool | b == (fd == fd1)] bool b 

overload = with eq_sockfd_int
overload = with eq_sockfd_sockfd
