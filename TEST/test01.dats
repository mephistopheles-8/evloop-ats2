#include "share/atspre_staload.hats"


local
#include "libats/libc/DATS/sys/socket_in.dats"
#include "libats/libc/DATS/sys/socket.dats"
%{
/** This should be defined in prelude **/
#define socket_AF_type(af,tp) socket(af,tp,0)
%}
in end

staload "libats/libc/SATS/sys/socket.sats"
staload "libats/libc/SATS/sys/socket_in.sats"
staload "libats/libc/SATS/netinet/in.sats"
staload _ = "libats/libc/DATS/sys/socket.dats"


(** This might come in handy at some point **)
absvt@ype socketfd(int,status) = int
vtypedef socketfd0 = [fd:int][st:status] socketfd(fd,st)
vtypedef socketfd1(st: status) = [fd:int] socketfd(fd,st)

extern
prfn socketfd_encode
  {fd:int}{s:status}
  ( socket_v(fd, s) | int fd ) 
  : socketfd(fd, s)

extern
prfn socketfd_decode
  {fd:int}{s:status}
  ( socketfd(fd, s) ) 
  : (socket_v(fd,s) | int fd)

absvt@ype sockopt(st:status,b:bool) = int 
absvt@ype sockalt(st1:status,st2:status,b:bool) = int 

extern
prfn sockopt_some{st:status}( &socketfd1(st) >> sockopt(st,true)) 
  : void

extern
prfn sockopt_none{st:status}( &socketfd0? >> sockopt(st,false)) 
  : void

extern
prfn sockopt_unsome{st:status}( &sockopt(st,true) >> socketfd1(st))
  : void

extern
prfn sockopt_unnone{st:status}( &sockopt(st,false) >> socketfd0? )
  : void

extern
prfn sockalt_left{st1,st2:status}( &socketfd1(st1) >> sockalt(st1,st2,true)) 
  : void

extern
prfn sockalt_right{st1,st2:status}( &socketfd1(st2) >> sockalt(st1,st2,false)) 
  : void

extern
prfn sockalt_unleft{st1,st2:status}( &sockalt(st1,st2,true) >> socketfd1(st1))
  : void

extern
prfn sockalt_unright{st1,st2:status}( &sockalt(st1,st2,false) >> socketfd1(st2))
  : void


fun socketfd_create
  ( sfd: &socketfd0? >> sockopt(init, b)
  , af: sa_family_t
  , st: socktype_t
  ) : #[b:bool] bool b
  = let
      val (pf | fd) = socket_AF_type(af,st)
     in if fd >= 0
        then 
          let
            prval Some_v(psock) = pf
            val () = sfd := socketfd_encode(psock | fd)
            prval () = sockopt_some(sfd)
          in true
          end
        else  
          let
            prval None_v() = pf
            prval () = sockopt_none(sfd)
          in false
          end
    end 

fun socketfd_create_exn
  ( af: sa_family_t
  , st: socktype_t
  ) : [fd:int] socketfd(fd,init)
  = let
      val (pf | fd) = socket_AF_type_exn(af,st)
      in socketfd_encode( pf | fd ) 
     end 

fun socketfd_create_opt
  ( af: sa_family_t
  , st: socktype_t
  ) : Option_vt(socketfd1(init))
  = let
      var sfd : socketfd0?
     in if socketfd_create( sfd, af, st )
        then 
          let
            prval () = sockopt_unsome(sfd)
          in Some_vt(sfd)
          end
        else  
          let
            prval () = sockopt_unnone(sfd)
          in None_vt()
          end
    end 



extern
fun socketfd_write_string
  {fd:int}{n,m:nat | m <= n}
  ( pf: !socketfd(fd,conn), str: string n, sz: size_t m )
  : ssizeBtwe(~1,m) = "mac#write"

extern
fun socket_write_string
  {fd:int}{n,m:nat | m <= n}
  ( pf: !socket_v(fd,conn) | fd : int fd, str: string n, sz: size_t m )
  : ssizeBtwe(~1,m) = "mac#write"


(** We really don't want this throwing exceptions **)

fun server_loop
  {fd:int}{n,sz:nat | n <= sz}( 
   pf: !socket_v(fd,listen) 
 | fd : int fd
 , buf : &bytes(sz) 
 , sz : size_t n 
) : void =
    let
      val (pconn | fd2) = accept_null_err( pf | fd )

      val () = 
        if fd2 >= 0
        then 
          let
            prval Some_v(pconn) = pconn
            val ssz = socket_read( pconn | fd2, buf, sz ) 
          in if ssz >= 0
             then 
                let
                  val ssz = socket_write_string( pconn | fd2, "Hello guys", i2sz(10) ) 
                  val () =  println!("Serving client")

                 in socket_close_exn( pconn | fd2 )
                end
             else ( println!("Error, read."); 
                    socket_close_exn( pconn | fd2 )
                  )
          end 
        else
          let
            prval None_v() = pconn
          in println!("Could not connect to client..")
          end
 
    in server_loop( pf | fd, buf, sz )
    end


implement main0 ()
 = println!("Hello [test01]")
 where {
  #define PORT  8888
  #define BACKLOG 24
  #define BUFSZ 1024

  var buf = @[byte][BUFSZ](i2byte(0))
  (** We could use socket_AF_type_exn here,
      but using the proofs as reference
  **)
  val (pf | sockfd) = 
    socket_AF_type( AF_INET, SOCK_STREAM )


  val () =
    if sockfd >= 0
    then 
      let
        prval Some_v( psock ) = pf

        val () = println!("Created socket")

        val inport = in_port_nbo(PORT)
        val inaddr = in_addr_hbo2nbo (INADDR_ANY)
        
        var servaddr : sockaddr_in_struct

        val () =
          sockaddr_in_init
            (servaddr, AF_INET, inaddr, inport)
 
      in 
        (** There is no bind_in_err in libats **)
        bind_in_exn( psock | sockfd, servaddr );
        listen_exn( psock | sockfd, BACKLOG );
        println!("Listening to port ", PORT);
        server_loop( psock | sockfd, buf, i2sz(BUFSZ) );
        socket_close_exn(psock | sockfd ) 
      end    
    else 
      let
        prval None_v(  ) = pf
        (** At the end of the day, we just have an exn **)
      in exit_errmsg_void(1, "Could not create socket.")
      end
 }
