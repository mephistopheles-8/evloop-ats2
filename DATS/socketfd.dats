
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

staload "libats/libc/SATS/sys/socket.sats"
staload "libats/libc/SATS/sys/socket_in.sats"
staload "libats/libc/SATS/netinet/in.sats"
staload "libats/libc/SATS/fcntl.sats"

staload _ = "libats/libc/DATS/sys/socket.dats"

(** This should be defined in libats ... **)
macdef O_NONBLOCK = $extval(fcntlflags, "O_NONBLOCK")

staload "./../SATS/socketfd.sats"

exception SocketfdCreateExn
exception SocketfdCloseExn of socketfd0


implement
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

implement
socketfd_set_nonblocking( sfd )
  = let
      val (psock | fd) = socketfd_fildes( sfd ) 
      val flags = fcntl_getfl(fd)
      val s = fcntl_setfl(fd, flags lor O_NONBLOCK )  
      val () = sfd := fildes_socketfd( psock | fd )
    in s > ~1
    end

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

implement
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

implement
socketfd_bind_in(sfd,sockaddr)
     = if _socketfd_bind_in( sfd, sockaddr, sizeof<sockaddr_in> ) > ~1 
     then true
     else false


implement
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

implement
socketfd_create_bind_port(sfd,p)
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

implement
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
implement
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

implement
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
        in ()
        end
  end

