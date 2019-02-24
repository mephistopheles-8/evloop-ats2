#include "./../HATS/project.hats"

staload "libats/libc/SATS/sys/socket.sats"
staload "./../SATS/socketfd.sats"

absvt@ype async_tcp_pool
abst@ype async_tcp_params
abst@ype async_tcp_event


(** internal **)

fun {} 
  async_tcp_pool_create
  ( &async_tcp_pool? >> opt(async_tcp_pool,b), &async_tcp_params )
  : #[b:bool] bool b

fun {env:vt@ype+}
   async_tcp_pool_run( !async_tcp_pool, env: &env >> _ ) : void

fun {}
  async_tcp_pool_close
  ( &async_tcp_pool? >> opt(async_tcp_pool,~b) )
  : #[b:bool] bool b


fun {}
  async_tcp_pool_add{fd:int}
  ( !async_tcp_pool, &socketfd(fd,conn) >> opt(socketfd(fd,conn),~b) )
  : #[b:bool] bool b 


fun {}
  async_tcp_pool_del{fd:int}
  ( !async_tcp_pool, &socketfd(fd,conn) >> opt(socketfd(fd,conn),~b) )
  : #[b:bool] bool b


(** user **)

fun {env:vt@ype+} 
  async_tcp_pool_accept{fd:int}
  ( socketfd(fd,conn), &env >> _ )
  : void

fun {env:vt@ype+} 
  async_tcp_pool_process{fd:int}
  ( async_tcp_event, socketfd(fd,conn), &env >> _ )
  : void
