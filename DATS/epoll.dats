
#include "./../HATS/project.hats"

#include "share/atspre_staload.hats"
staload "libats/libc/SATS/sys/socket.sats"
staload "./../SATS/socketfd.sats"
staload "./../SATS/epoll.sats"

#ifdef _ASYNCNET_LINK
exception EpollCreateExn
exception EpollCloseExn of (epollfd)
#endif

implement
epoll_event_kind_lor( e1, e2 ) =
  $UNSAFE.cast{epoll_event_kind}( eek2ui(e1) lor eek2ui(e2) ) 

implement
eek_has( e1,e2 ) 
  = $UNSAFE.cast{int}(eek2ui(e1) land eek2ui(e2)) != 0 


implement
epollfd_add0( efd, sfd, events, data )
  = let
      var event = (@{
          events = events
        , data = data 
        }): epoll_event
     in epoll_ctl( efd, EPOLL_CTL_ADD, sfd, event )
    end 

implement
epollfd_create_exn ()
  = let
      val (pf | fd ) = epoll_create1(EP0)
    in if fd > 0
       then 
          let
              prval Some_v( pfep ) = pf
           in epollfd_encode( pfep | fd )
          end
       else $raise EpollCreateExn()
          where {
              prval None_v(  ) = pf

          }
    end

implement
epollfd_close_exn(efd) 
  = let
      val (pfep | fd ) = epollfd_decode( efd )  
      val ( pf | err ) = epollfd_close( pfep | fd )
      val () = assertloc( err = 0 )
     in if err = 0 
        then { 
            prval None_v() = pf  
          }
        else $raise EpollCloseExn(epollfd_encode( pfep | fd ))
          where {
            prval Some_v(pfep) = pf  
          }
    end

implement
epoll_event_empty () =
      @{events = $UNSAFE.cast{epoll_event_kind}(0), data = epoll_data_ptr(the_null_ptr) }


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

