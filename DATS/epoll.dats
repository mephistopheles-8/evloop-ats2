
#include "./../HATS/project.hats"

#include "share/atspre_staload.hats"
staload "libats/libc/SATS/sys/socket.sats"
staload "libats/libc/SATS/errno.sats"
staload "./../SATS/sockfd.sats"
staload "./../SATS/epoll.sats"

implement {}
epoll_event_kind_lor( e1, e2 ) =
  $UNSAFE.cast{epoll_event_kind}( eek2ui(e1) lor eek2ui(e2) ) 

implement {}
event_kind_lhas( e1,e2 ) 
  = $UNSAFE.cast{int}(eek2ui(e1) land eek2ui(e2)) != 0 


implement {}
epollfd_add0( efd, sfd, events, data )
  = let
      (** Ignore EINTR **)
      fun loop
      ( efd: !epollfd, sfd: !sockfd0, event: &epoll_event )
      : intBtwe(~1,0) =
          if epoll_ctl(efd,EPOLL_CTL_ADD,sfd,event) = 0
          then 0
          else 
            if the_errno_test(EINTR) || the_errno_test(EAGAIN)
            then loop( efd, sfd, event )
            else ~1

      var event = (@{
          events = events
        , data = data 
        }): epoll_event

     in loop( efd, sfd, event )
    end 

implement {}
epollfd_create_exn (behv)
  = let
      val (pf | fd ) = epoll_create1(behv)
      val () 
        = assert_errmsg( fd > 0
            , "[epoll_create_exn] Could not create epoll fd" )
      prval Some_v(pep) = pf
    in epollfd_encode( pep | fd ) 
    end

implement {}
epollfd_close_exn(efd) 
  = let
      val (pfep | fd ) = epollfd_decode( efd )  
      val ( pf | err ) = epollfd_close( pfep | fd )
      val () 
        = assert_errmsg( err = 0
            , "[epoll_close_exn] Could not close epoll fd" )
      prval None_v() = pf
    in
    end

implement {}
epoll_event_empty () =
      @{events = $UNSAFE.cast{epoll_event_kind}(0), data = epoll_data_ptr(the_null_ptr) }

