
#include "./../HATS/project.hats"

#include "share/atspre_staload.hats"
staload "libats/libc/SATS/sys/socket.sats"
staload "./../SATS/socketfd.sats"
staload "./../SATS/epoll.sats"

implement
epoll_event_kind_lor( e1, e2 ) =
  $UNSAFE.cast{epoll_event_kind}( eek2ui(e1) lor eek2ui(e2) ) 

implement
eek_has( e1,e2 ) 
  = $UNSAFE.cast{int}(eek2ui(e1) land eek2ui(e2)) != 0 


implement
epollfd_add0( efd, sfd )
  = let
      var event = (@{
          events = EPOLLIN lor EPOLLET
        , data = epoll_data_socketfd( sfd )   
        }): epoll_event
     in epoll_ctl( efd, EPOLL_CTL_ADD, sfd, event )
    end 

implement
epollfd_create_exn ()
  = let
      val (pf | fd ) = epoll_create1(EP0)
      val () = assertloc( fd > 0 ) 
      prval Some_v( pfep ) = pf
    in epollfd_encode( pfep | fd )
    end

implement
epollfd_close_exn(efd) 
  = let
      val (pfep | fd ) = epollfd_decode( efd )  
      val ( pf | err ) = epollfd_close( pfep | fd )
      val () = assertloc( err = 0 )
      prval None_v() = pf  
     in ()
    end

implement
epoll_event_empty () =
      @{events = $UNSAFE.cast{epoll_event_kind}(0), data = epoll_data_ptr(the_null_ptr) }

implement
eq_socketfd_int{fd,n}{st}( sfd, n) 
  = $UNSAFE.castvwtp1{int fd}(sfd) = n

implement eq_socketfd_socketfd{fd,fd1}{st,st1}( sfd, sfd1 ) 
  = $UNSAFE.castvwtp1{int fd}(sfd) = $UNSAFE.castvwtp1{int fd1}(sfd1)

implement {env}
epoll_events_foreach( pwait, parr | p, n, env ) 
  = let
      implement
      array_foreach$fwork<epoll_event><env>( x, env ) =
          epoll_events_foreach$fwork<env>( pf | x.events, sfd , env )
        where {
            extern
            prfn epoll_add_intr {fd:int}{st:status}( !socketfd(fd,st) ) 
              : epoll_add_v(fd,st)

            val sfd = $UNSAFE.castvwtp1{socketfd0}(x.data.fd)
            prval pf = epoll_add_intr(sfd)
          }

      prval (pf1, pf2 ) = array_v_split_at(parr | i2sz(n))
 
      val _ = array_foreach_env<epoll_event><env>( !p, i2sz(n), env )

      prval () = parr := array_v_unsplit( pf1, pf2 )
 
    in ()
    end

