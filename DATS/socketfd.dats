
#include "./../HATS/project.hats"

#include "share/atspre_staload.hats"


local
#include "libats/libc/DATS/sys/socket_in.dats"
#include "libats/libc/DATS/sys/socket.dats"
%{
/** This should be defined in libats **/
#define socket_AF_type(af,tp) socket(af,tp,0)
%}
in end

staload "libats/libc/SATS/stdio.sats"
staload "libats/libc/SATS/sys/socket.sats"
staload "libats/libc/SATS/sys/socket_in.sats"
staload "libats/libc/SATS/netinet/in.sats"
staload "libats/libc/SATS/fcntl.sats"
staload "libats/libc/SATS/errno.sats"

staload _ = "libats/libc/DATS/sys/socket.dats"

%{#
#include <netinet/tcp.h>
%}

(** This should be defined in libats ... **)
macdef O_NONBLOCK = $extval(fcntlflags, "O_NONBLOCK")

staload "./../SATS/socketfd.sats"

#ifdef _ASYNCNET_LINK
exception SocketfdCreateExn
exception SocketfdCloseExn of socketfd0
#endif


macdef SO_REUSEPORT = $extval(int, "SO_REUSEPORT")
macdef SO_REUSEADDR = $extval(int, "SO_REUSEADDR")
macdef SO_ERROR = $extval(int, "SO_ERROR")
macdef SOL_SOCKET = $extval(int, "SOL_SOCKET")
macdef TCP_NODELAY = $extval(int, "TCP_NODELAY")
macdef IPPROTO_TCP = $extval(int, "IPPROTO_TCP")
macdef FD_CLOEXEC = $extval(fcntlflags, "FD_CLOEXEC")

extern
fn setsockopt( int, int, int, &int, size_t (sizeof(int)) ) : int = "mac#"
extern
fn getsockopt( int, int, int, &int, size_t (sizeof(int)) ) : int = "mac#"

extern
fn strerror( int ) : string = "mac#"

implement {}
socketfd_create( sfd, af, st )
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

implement {}
socketfd_set_nonblocking( sfd )
  = let
      val fd = socketfd_fildes1( sfd ) 
      val flags = fcntl_getfl(fd)
      val s = fcntl_setfl(fd, flags lor O_NONBLOCK )  
      prval () = fildes_socketfd1( sfd, fd)
    in s > ~1
    end

implement {}
socketfd_set_cloexec( sfd )
  = let
      val fd = socketfd_fildes1( sfd ) 
      val flags = fcntl_getfl(fd)
      val s = fcntl_setfl(fd, flags lor FD_CLOEXEC )  
      prval () = fildes_socketfd1( sfd, fd)
    in s > ~1
    end

implement {}
socketfd_set_nodelay( sfd ) 
  = st > ~1 where {
      var n : int = 1 
      val st = setsockopt( socketfd_value(sfd), IPPROTO_TCP, TCP_NODELAY, n, sizeof<int> ) 
  
  }

implement {}
socketfd_get_error_code( sfd ) 
  = (if st > ~1 then n else st) where {
      var n : int = 0 
      val st = setsockopt( socketfd_value(sfd), SOL_SOCKET, SO_ERROR, n, sizeof<int> ) 
  
  }

implement {}
socketfd_get_error_string( sfd ) 
  = str where { val x = socketfd_get_error_code( sfd )
      val str = if x = ~1 then "Could not get error code"
                          else strerror(x)
      }

implement 
socketfd_create_exn(af,st)
  = let
      val (pf | fd) = socket_AF_type(af,st)
     in if fd >= 0
        then 
          let
             prval Some_v(psock) = pf
           in socketfd_encode(psock | fd)
          end
        else  
          let
            prval None_v() = pf
          in $raise SocketfdCreateExn()
          end
    end 

implement {}
socketfd_create_opt(af,st) 
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

implement {}
socketfd_bind_in(sfd,sockaddr)
     = if _socketfd_bind_in( sfd, sockaddr, sizeof<sockaddr_in> ) > ~1 
     then true
     else false


implement {}
socketfd_close(sfd)
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

implement 
socketfd_close_exn(sfd)
  = let
      var sfd = sfd
    in if socketfd_close( sfd ) 
       then {
            prval () = sockopt_unnone(sfd)
          }
        else $raise SocketfdCloseExn(sfd)
        where {
            prval () = sockopt_unsome(sfd)
        }
    end

implement {}
socketfd_create_bind_port(sfd,p)
  = let

    in if socketfd_create(sfd,p.af,p.st)
       then
        let
          prval () = sockopt_unsome(sfd)

          prval prv = view@sfd         
          val () = 
            if p.reuseaddr
            then 
                { 
                  var n : int = 1 
                  val _ = assertloc( setsockopt( socketfd_value(sfd), SOL_SOCKET, SO_REUSEADDR, n, sizeof<int> ) > ~1 )
                }
            
          val () = 
            if p.nodelay
            then 
                { 
                  val () =  assertloc( socketfd_set_nodelay( sfd ) ) 
                }
            else () 
          val () = 
            if p.nonblocking 
            then  assertloc( socketfd_set_nonblocking( sfd ) ) 
            else ()
          val () = 
            if p.cloexec 
            then  assertloc( socketfd_set_cloexec( sfd ) ) 
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

implement {}
socketfd_listen(sfd, backlog)
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

local
      extern castfn
      socketfd_decode1{fd:int}{st:status}
        ( !socketfd(fd,st) )
        : ( socket_v(fd,st) | int fd )

      extern praxi
      socket_v_elim{fd:int}{st:status}
      ( socket_v(fd,st) ) : void

in
implement {}
socketfd_accept(sfd,cfd)
  = let
 
      val (pf | fd) = socketfd_decode1( sfd )
      val (pfc | fd2) = accept_null_err( pf | fd) 
    in if fd2 >= 0 
       then 
        let
            prval Some_v(pconn) = pfc
            prval () = socket_v_elim( pf )
            val () = cfd := socketfd_encode( pconn | fd2 )
            prval () = sockopt_some( cfd ) 
         in true 
        end 
       else
        let
            prval None_v() = pfc
            prval () = socket_v_elim( pf )
            prval () = sockopt_none( cfd  ) 
         in false 
        end 
    end 
end (** END, [local] **)

implement {}
socketfd_setup(sfd,params)
 = let
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

implement {env} 
socketfd_accept_all{fd:int}( sfd, env ) 
  : void =
  let
      var cfd : socketfd0?
   in if socketfd_accept( sfd, cfd ) 
      then
        let
          prval () = sockopt_unsome(cfd)
          val () = socketfd_accept_all$withfd<env>(cfd,env)
        in socketfd_accept_all<env>( sfd, env )
        end
      else 
        let
          prval () = sockopt_unnone(cfd)
        

        in if ~the_errno_test(EAGAIN) && ~the_errno_test(EWOULDBLOCK)
           then perror("accept")
        end
  end

implement
eq_socketfd_int{fd,n}{st}( sfd, n) 
  = $UNSAFE.castvwtp1{int fd}(sfd) = n

implement eq_socketfd_socketfd{fd,fd1}{st,st1}( sfd, sfd1 ) 
  = $UNSAFE.castvwtp1{int fd}(sfd) = $UNSAFE.castvwtp1{int fd1}(sfd1)

implement {env}
socketfd_readall( sfd, buf, sz, env ) 
 = let
      val ssz = socketfd_read(sfd,buf,sz) 
    in if  ssz > 0 then 
        let
          prval (pf1,pf2) = array_v_split_at( view@buf | g1int2uint(ssz) )

          val b = socketfd_readall$fwork<env>( buf, g1int2uint( ssz ), env )

          prval () = view@buf := array_v_unsplit( pf1, pf2 ) 
        in if b then  socketfd_readall<env>(sfd,buf,sz,env)
           else false
        end
      else if ssz = ~1 then
        ifcase
          | the_errno_test(EAGAIN) =>
              socketfd_readall<env>( sfd, buf, sz, env ) 
          | _ => false  
      else true
   end

