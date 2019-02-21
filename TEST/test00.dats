
#include "share/atspre_staload.hats"

local
#include "libats/libc/DATS/sys/socket_in.dats"
#include "libats/libc/DATS/sys/socket.dats"
%{
/** This should be defined in libats **/
#define socket_AF_type(af,tp) socket(af,tp,0)
%}
in end

staload "libats/libc/SATS/sys/socket.sats"
staload "libats/libc/SATS/sys/socket_in.sats"
staload "libats/libc/SATS/netinet/in.sats"
staload "libats/libc/SATS/fcntl.sats"

staload _ = "libats/libc/DATS/sys/socket.dats"

(** This should be defined in libats ... **)
macdef O_NONBLOCK = $extval(fcntlflags, "O_NONBLOCK")

(** This might come in handy at some point **)
absvt@ype socketfd(int,status) = int
vtypedef socketfd0 = [fd:int][st:status] socketfd(fd,st)
vtypedef socketfd1(st: status) = [fd:int] socketfd(fd,st)

extern
castfn socketfd_encode
  {fd:int}{s:status}
  ( socket_v(fd, s) | int fd ) 
  : socketfd(fd, s)

extern
castfn socketfd_decode
  {fd:int}{s:status}
  ( socketfd(fd, s) ) 
  : (socket_v(fd,s) | int fd)

extern
castfn socketfd_fildes
  {fd:int}{s:status}
  ( socketfd(fd,s) ) 
  : [fd > 0] (socket_v(fd,s) | fildes(fd))

extern
castfn fildes_socketfd
  {fd:int}{s:status}
  ( socket_v(fd,s) | fildes(fd) ) 
  : socketfd(fd,s)

absvt@ype sockopt(fd:int,st:status,b:bool) = int 
absvt@ype sockalt(fd:int,st1:status,st2:status,b:bool) = int 
vtypedef sockopt(st:status, b:bool) = [fd:int] sockopt(fd,st,b)

extern
prfn sockopt_some{st:status}{fd:int}( &socketfd(fd,st) >> sockopt(fd,st,true)) 
  : void

extern
prfn sockopt_none{st:status}{fd:int}( &socketfd0? >> sockopt(fd,st,false)) 
  : void

extern
prfn sockopt_unsome{st:status}{fd:int}( &sockopt(fd,st,true) >> socketfd(fd,st))
  : void

extern
prfn sockopt_unnone{st:status}( &sockopt(st,false) >> socketfd0? )
  : void

extern
prfn sockopt_none_stat_univ{st1,st2:status}( &sockopt(st1,false) >> sockopt(st2,false) )
  : void

extern
prfn sockalt_left{st1,st2:status}{fd:int}( &socketfd(fd,st1) >> sockalt(fd,st1,st2,true)) 
  : void

extern
prfn sockalt_right{st1,st2:status}{fd:int}( &socketfd(fd,st2) >> sockalt(fd,st1,st2,false)) 
  : void

extern
prfn sockalt_unleft{st1,st2:status}{fd:int}( &sockalt(fd,st1,st2,true) >> socketfd(fd,st1))
  : void

extern
prfn sockalt_unright{st1,st2:status}{fd:int}( &sockalt(fd,st1,st2,false) >> socketfd(fd,st2))
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

fun socketfd_set_nonblocking
  {fd:int}
  ( sfd: &socketfd(fd,init)
  ) : bool
  = let
      val (psock | fd) = socketfd_fildes( sfd ) 
      val flags = fcntl_getfl(fd)
      val s = fcntl_setfl(fd, flags lor O_NONBLOCK )  
      val () = sfd := fildes_socketfd( psock | fd )
    in s > ~1
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
fun _socketfd_bind_in{fd:int}(
   sfd: !socketfd(fd,init) >> sockalt(fd,bind,init,n > ~1) 
 , sockaddr: &sockaddr_in
 , size : size_t (sizeof(sockaddr_in)) 
) : #[n:int] int n = "mac#bind" 

fun socketfd_bind_in{fd:int}(
   sfd: !socketfd(fd,init) >> sockalt(fd,bind,init,b) 
 , sockaddr: &sockaddr_in
) : #[b:bool] bool b = 
     if _socketfd_bind_in( sfd, sockaddr, sizeof<sockaddr_in> ) > ~1 
     then true
     else false

fun socketfd_close_exn
  ( sfd: socketfd0
  ) : void
  = {
      val (pf | fd) = socketfd_decode( sfd )
      val () = socket_close_exn( pf | fd )
  }

fun socketfd_close{fd:int}{st:status}
  ( sfd: &socketfd(fd,st) >> sockopt(fd,st,~b)
  ) : #[b:bool] bool b
  = let
      val (pf | fd) = socketfd_decode( sfd )
      val (pf | i) = socket_close( pf | fd )
    in if i < 0 
       then 
        let
          prval Some_v(psock) = pf
          val () = sfd := socketfd_encode( psock | fd )
          prval () = sockopt_some( sfd ) 
         in false
        end
       else
        let
          prval None_v() = pf
          prval () = sockopt_none( sfd ) 
         in true 
        end
    end


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
  = let

    in if socketfd_create(sfd,p.af,p.st)
       then
        let
          prval () = sockopt_unsome(sfd)

          prval prv = view@sfd          
          val () = 
            if p.nonblocking 
            then  assertloc( socketfd_set_nonblocking( sfd ) ) 
            else ()
          prval () = view@sfd := prv
 
          val inport = in_port_nbo(p.port)
          val inaddr = p.address 
          
          var servaddr : sockaddr_in_struct
          
          val () =
            sockaddr_in_init
              (servaddr, AF_INET, inaddr, inport)

        in if socketfd_bind_in(sfd, servaddr)
           then
              let
                prval () = sockalt_unleft(sfd)
                prval () = sockopt_some(sfd)
              in true
              end
           else
              let
                prval () = sockalt_unright(sfd)

                val () = socketfd_close_exn( sfd )
               
                prval () = sockopt_none{bind}(sfd)
                  
              in false
              end
        end
       else
        let
          prval () = sockopt_none_stat_univ(sfd)
        in false
        end
    end 


fun socketfd_listen{fd:int}
  ( sfd: &socketfd(fd,bind) >> sockalt(fd,listen,bind,b)
  , backlog : intGt(0)
  ): #[b:bool] bool b
  = let
      val (pf | fd) = socketfd_decode( sfd )
      val (pfl | err) = listen_err( pf | fd, backlog) 
    in if err = 0 
       then 
        let
            prval listen_v_succ(psock) = pfl
            val () = sfd := socketfd_encode( psock | fd )
            prval () = sockalt_left( sfd ) 
         in true 
        end 
       else
        let
            prval listen_v_fail(psock) = pfl
            val () = sfd := socketfd_encode( psock | fd )
            prval () = sockalt_right( sfd ) 
         in false 
        end 
    end 

fun socketfd_accept{fd:int}
  ( sfd: &socketfd(fd,listen)
  , cfd: &socketfd0? >> sockopt(conn,b)
  ): #[b:bool] bool b
  = let
      val (pf | fd) = socketfd_decode( sfd )
      val (pfc | fd2) = accept_null_err( pf | fd) 
    in if fd2 >= 0 
       then 
        let
            prval Some_v(pconn) = pfc
            val () = sfd := socketfd_encode( pf | fd )
            val () = cfd := socketfd_encode( pconn | fd2 )
            prval () = sockopt_some( cfd ) 
         in true 
        end 
       else
        let
            prval None_v() = pfc
            val () = sfd := socketfd_encode( pf | fd )
            prval () = sockopt_none( cfd  ) 
         in false 
        end 
    end 

typedef socketfd_setup_params = @{
    af = sa_family_t
  , st = socktype_t
  , nonblocking = bool
  , port = int
  , address = in_addr_nbo_t
  , backlog = intGt(0)
} 

extern
prfn socketfd_params_intr{l:addr}
  ( pf : !socketfd_setup_params @ l 
  ): socketfd_create_bind_params @ l

extern
prfn socketfd_params_elim{l:addr}
  ( pf1 : !socketfd_setup_params @ l
  , pf2 : socketfd_create_bind_params @ l
  ): void


fun socketfd_setup(
   sfd: &socketfd0? >> sockopt(listen,b)
 , params : &socketfd_setup_params
) : #[b:bool] bool b =
  let
    prval pfv = view@params
    prval pfp = socketfd_params_intr( pfv )
   in if socketfd_create_bind_port( sfd, params )
      then
        let
          prval () = socketfd_params_elim( pfv, pfp )
          prval () = view@params := pfv
          prval () = sockopt_unsome( sfd )
        in if socketfd_listen( sfd, params.backlog ) 
           then 
            let
                 prval () = sockalt_unleft( sfd )   
                 prval () = sockopt_some( sfd ) 
             in  true
            end 
           else 
            let
                prval () = sockalt_unright( sfd )   
                val () = socketfd_close_exn( sfd )
                prval () = sockopt_none( sfd )
             in false 
            end
        end
      else 
        let 
          prval () = socketfd_params_elim( pfv, pfp )
          prval () = view@params := pfv
          prval () = sockopt_none_stat_univ(sfd)
        in false
        end
  end


extern
fun socketfd_write_string
  {fd:int}{n,m:nat | m <= n}
  ( pf: !socketfd(fd,conn), str: string n, sz: size_t m )
  : ssizeBtwe(~1,m) = "mac#write"

extern
fun socketfd_read
  {fd:int}{n,m:nat | m <= n}
  ( pf: !socketfd(fd,conn), buf: &bytes(n), sz: size_t m )
  : ssizeBtwe(~1,m) = "mac#read"

extern
fun socket_write_string
  {fd:int}{n,m:nat | m <= n}
  ( pf: !socket_v(fd,conn) | fd : int fd, str: string n, sz: size_t m )
  : ssizeBtwe(~1,m) = "mac#write"


(** We really don't want this throwing exceptions **)

fun server_loop
  {fd:int}{n,sz:nat | n <= sz}( 
   lfd:  &socketfd(fd,listen)
 , buf : &bytes(sz) 
 , sz : size_t n 
) : void =
    let
      var cfd : socketfd0?

      val () = 
        if socketfd_accept(lfd,cfd) 
        then 
          let
            prval () = sockopt_unsome( cfd )
            val ssz = socketfd_read( cfd, buf, sz ) 
          in if ssz >= 0
             then 
                let
                  val ssz = socketfd_write_string( cfd, "Hello guys", i2sz(10) ) 
                  val () =  println!("Serving client")

                 in socketfd_close_exn( cfd )
                end
             else ( println!("Error, read."); 
                    socketfd_close_exn( cfd )
                  )
          end 
        else
          let
            prval () = sockopt_unnone( cfd )
          in println!("Could not connect to client..")
          end
 
    in server_loop( lfd, buf, sz )
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
  var sp : socketfd_setup_params = @{
        af = AF_INET
      , st = SOCK_STREAM
      , nonblocking = false 
      , port = PORT
      , address = in_addr_hbo2nbo (INADDR_ANY)
      , backlog = BACKLOG
    }

  var sfd : socketfd0?

  val () = 
    if socketfd_setup( sfd, sp )
    then
        let 
          prval () = sockopt_unsome( sfd )
          val () = println!("Listening to port ", PORT)
          val () = server_loop( sfd, buf, i2sz(BUFSZ ) )
        in socketfd_close_exn( sfd ) 
       end
     else 
      let
          prval () = sockopt_unnone( sfd )    
       in (  exit_errmsg_void(1, "Socket setup failed") )
      end
 }
