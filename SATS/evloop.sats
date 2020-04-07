#include "./../HATS/project.hats"

staload "libats/libc/SATS/sys/socket.sats"
staload "./../SATS/sockfd.sats"

absvt@ype evloop(a:vt@ype+)
vtypedef  evloop = [a:vt@ype+] evloop(a)
abst@ype evloop_params
abst@ype evloop_event

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

absvt@ype sockenv_evloop_data

datavtype sockenv(env:vt@ype+) =
  | CLIENT of (sockfd0, sockenv_evloop_data, env)

vtypedef sockenv = [a:vt@ype+] sockenv(a)

fun {env:vt@ype+}
  evloop$process( &evloop(env), sockevt , !sockenv(env) ) : void

fun {}
  evloop_events_mod{a:vt@ype+}( &evloop(a), sockevt, !sockenv(a) ) : bool 

fun {}
  evloop_events_del{a:vt@ype+}( &evloop(a), !sockenv(a) ) : bool 

fun {}
  evloop_events_add{a:vt@ype+}( &evloop(a), sockevt, !sockenv(a) >> opt(sockenv(a),~b) ) : #[b:bool] bool b 

fun {}
  evloop_events_dispose{a:vt@ype+}( &evloop(a), !sockenv(a) ) : bool
 
fun {env:vt@ype+}
  sockenv_create( sockfd0, env ) : sockenv(env)

fun {env:vt@ype+}
  sockenv_decompose( sockenv(env) ) : @(sockfd0,env)

fun {a:vt@ype+} 
  evloop_create
  ( &evloop(a)? >> opt(evloop(a),b), &evloop_params )
  : #[b:bool] bool b

fun {env:vt@ype+}{sockenv:vt@ype+}
   evloop_run( &evloop(sockenv), env: &env >> _ ) : void

fun {a:vt@ype+}
  evloop_close_exn
  ( &evloop(a) >> evloop(a)?  )
  : void

(** user **)
fun {senv:vt@ype+} sockenv$free( senv ) :  void 

fun {env:vt@ype+}{senv:vt@ype} 
  evloop_error
  ( &evloop(senv), &env >> _, !sockenv(senv) )
  : void

fun {env:vt@ype+}{senv:vt@ype} 
  evloop_hup
  ( &evloop(senv), &env >> _, !sockenv(senv) )
  : void

fun {senv:vt@ype+} 
  evloop_process
  ( &evloop(senv), evloop_event, !sockenv(senv) >> _ )
  : void

