#include "./../HATS/project.hats"

staload "libats/libc/SATS/sys/socket.sats"
staload "./../SATS/socketfd.sats"

absvt@ype async_tcp_pool(a:vtype)
vtypedef  async_tcp_pool = [a:vtype] async_tcp_pool(a)
abst@ype async_tcp_params
abst@ype async_tcp_event
absvtype sockenv(a:vt@ype+) = ptr
vtypedef sockenv = [a:vt@ype+] sockenv(a)

datatype sock_polling_state = 
  | PolledR
  | PolledW
  | PolledRW
  | NotPolled
  | Disposed

datatype sockevt = 
  | EvtR
  | EvtW
  | EvtRW
  | EvtOther

fun {env:vt@ype+}
  evloop$process( &async_tcp_pool, sockevt , !sockenv(env) ) : void

fun {}
  evloop_events_mod{a:vtype}( &async_tcp_pool(a), sockevt, !sockenv ) : bool 

fun {}
  evloop_events_del{a:vtype}( &async_tcp_pool(a), !sockenv ) : bool 

fun {}
  evloop_events_add{a:vtype}( &async_tcp_pool(a), sockevt, !sockenv >> opt(sockenv,~b) ) : #[b:bool] bool b 

fun {}
  evloop_events_dispose( &async_tcp_pool, !sockenv ) : bool
 
fun {env:vt@ype+}
  sockenv_create( socketfd0, env ) : sockenv(env)

(** internal **)

fun {a:vtype} 
  async_tcp_pool_create
  ( &async_tcp_pool(a)? >> opt(async_tcp_pool(a),b), &async_tcp_params )
  : #[b:bool] bool b

fun {env:vt@ype+}{sockenv:vtype}
   async_tcp_pool_run( &async_tcp_pool(sockenv), env: &env >> _ ) : void

fun {a:vtype}
  async_tcp_pool_close_exn
  ( &async_tcp_pool(a) >> async_tcp_pool(a)?  )
  : void


(** We may not need to consume socketfd ? It's expected the user maintain them in sockenv **)
fun {}
  async_tcp_pool_add{sockenv:vtype}{fd:int}{st:status}
  ( &async_tcp_pool(sockenv), !socketfd(fd,st), async_tcp_event, &sockenv >> opt(sockenv,~b) )
  : #[b:bool] bool b 


fun {}
  async_tcp_pool_add_exn{sockenv:vtype}{fd:int}
  ( &async_tcp_pool(sockenv), !socketfd(fd), async_tcp_event, sockenv )
  : void

fun {}
  async_tcp_pool_mod{sockenv:vtype}{fd:int}{st:status}
  ( &async_tcp_pool(sockenv), !socketfd(fd,st), async_tcp_event, !sockenv )
  : bool 

fun {}
  async_tcp_pool_mod_exn{sockenv:vtype}{fd:int}
  ( &async_tcp_pool(sockenv), !socketfd(fd), async_tcp_event, !sockenv )
  : void

fun {}
  async_tcp_pool_del{fd:int}{st:status}
  ( &async_tcp_pool, !socketfd(fd,st) )
  : bool

fun {}
  async_tcp_pool_del_exn{fd:int}{st:status}
  ( &async_tcp_pool, !socketfd(fd,st)  )
  : void

(** user **)
fun {senv:vtype} sockenv$free( senv ) :  void 
fun {senv:vtype} sockenv$isdisposed( !senv ) : bool
fun {senv:vtype} sockenv$setdisposed(&async_tcp_pool(senv), !senv ) : void

fun {env:vt@ype+}{senv:vtype} 
  async_tcp_pool_error
  ( &async_tcp_pool(senv), &env >> _, !senv )
  : void

fun {env:vt@ype+}{senv:vtype} 
  async_tcp_pool_hup
  ( &async_tcp_pool(senv), &env >> _, !senv )
  : void

fun {env:vt@ype+} 
  async_tcp_pool_accept{fd:int}
  ( &async_tcp_pool, socketfd(fd,conn), &env >> _ )
  : void

fun {sockenv:vtype} 
  async_tcp_pool_process
  ( &async_tcp_pool(sockenv), async_tcp_event, !sockenv >> _ )
  : void
