
#include "./../HATS/project.hats"

(** libats imports **)
staload "libats/libc/SATS/sys/socket.sats"
staload "./sockfd.sats"

abst@ype socket(int,status) = int
typedef socket0 = [fd:int][st:status] socket(fd,st)
typedef socket1(st: status) = [fd:int] socket(fd,st)
(** ** ** ** ** ** **)


castfn sockfd_socket
  {fd:int}{s:status}
  ( sockfd(fd,s) ) 
  : (socket_v(fd,s) | socket(fd, s) )

castfn socket_sockfd
  {fd:int}{s:status}
  ( socket_v(fd,s) | socket(fd,s) ) 
  : sockfd(fd,s)

fun socket_read
  {fd:int}{n,m:nat | m <= n}
  ( pf: !socket(fd,conn), buf: &bytes(n), sz: size_t m )
  : ssizeBtwe(~1,m) = "mac#read"

fun socket_write
  {fd:int}{n,m:nat | m <= n}
  ( pf: !socket(fd,conn), buf: &bytes(n), sz: size_t m )
  : ssizeBtwe(~1,m) = "mac#write"

fun socket_write_string
  {fd:int}{n,m:nat | m <= n}
  ( pf: !socket(fd,conn), str: string n, sz: size_t m )
  : ssizeBtwe(~1,m) = "mac#write"

fun socket_write_strnptr
  {fd:int}{n,m:nat | m <= n}
  ( pf: !socket(fd,conn), buf: !strnptr(n), sz: size_t m )
  : ssizeBtwe(~1,m) = "mac#write"

