
#include "./../HATS/project.hats"
#include "share/atspre_staload.hats"

staload "libats/libc/SATS/sys/socket.sats"
staload "./../SATS/sockfd.sats"
staload "./../SATS/kqueue.sats"

implement {}
evfilt_lor( e1, e2 ) 
= $UNSAFE.cast{evfilt}( evfilt2uint( e1 ) lor evfilt2uint( e2 ))

implement {}
evfilt_land( e1, e2 ) 
= $UNSAFE.cast{evfilt}( evfilt2uint( e1 ) land evfilt2uint( e2 ))

implement {}
evfilt_lhas( e1, e2 ) 
= g1ofg0( evfilt2uint( e1 land e2 ) != 0U )


implement {}
kevent_action_land( k1, k2 )
= $UNSAFE.cast{kevent_action}( kevent_action_usint( k1 ) land kevent_action_usint( k2 ) )

implement {}
kevent_action_lor( k1, k2 ) 
= $UNSAFE.cast{kevent_action}( kevent_action_usint( k1 ) lor kevent_action_usint( k2 ) )

implement {}
kevent_action_lhas( k1, k2 ) 
= g1ofg0( $UNSAFE.cast{int}(( k1 land k2 )) != 0 )


implement {}
kevent_flag_land( k1, k2 )
= $UNSAFE.cast{kevent_flag}( kevent_flag_usint( k1 ) land kevent_flag_usint( k2 ) )

implement {}
kevent_flag_lor( k1, k2 ) 
= $UNSAFE.cast{kevent_flag}( kevent_flag_usint( k1 ) lor kevent_flag_usint( k2 ) )

implement {}
kevent_flag_lhas( k1, k2 ) 
= g1ofg0( $UNSAFE.cast{int}(( k1 land k2 )) != 0 )


implement {}
kevent_status_land( k1, k2 )
= $UNSAFE.cast{kevent_status}( kevent_status_usint( k1 ) land kevent_status_usint( k2 ) )

implement {}
kevent_status_lor( k1, k2 ) 
= $UNSAFE.cast{kevent_status}( kevent_status_usint( k1 ) lor kevent_status_usint( k2 ) )

implement {}
kevent_status_lhas( k1, k2 ) 
= g1ofg0( $UNSAFE.cast{int}(( k1 land k2 )) != 0 )


implement {}
kevent_fflag_land( k1, k2 )
= $UNSAFE.cast{kevent_fflag}( kevent_fflag_uint( k1 ) land kevent_fflag_uint( k2 ) )

implement {}
kevent_fflag_lor( k1, k2 ) 
= $UNSAFE.cast{kevent_fflag}( kevent_fflag_uint( k1 ) lor kevent_fflag_uint( k2 ) )

implement {}
kevent_fflag_lhas( k1, k2 ) 
= g1ofg0( kevent_fflag_uint( k1 land k2 ) != 0 )


implement {}
kevent_empty() 
 = (@{
     ident = $UNSAFE.cast{uintptr}(0)
   , filter = evfilt_empty
   , flags = kevent_flag_empty 
   , fflags = kevent_fflag_empty
   , data = kevent_data_empty
   , udata = the_null_ptr 
  })

implement {}
kqueue_exn ()  
= let
    val (pf | fd) = kqueue()
    val () 
      = assert_errmsg( fd > ~1
          , "[kqueue_exn] Could not create kqueue fd" )
    prval Some_v(pkq) = pf
   in kqueuefd_encode( pkq | fd )
  end 

implement {}
kqueuefd_create( kfd ) 
 = let
      val (pf | fd) = kqueue()
    in if fd > ~1 
       then
        let
          prval Some_v(pkq) = pf
          val () = kfd := kqueuefd_encode( pkq | fd ) 
          prval () = opt_some( kfd )
        in true
        end
       else
        let
          prval None_v() = pf
          prval () = opt_none( kfd )
        in false
        end
   end 

implement {}
kqueuefd_create_exn() 
  = let
      var kfd : kqueuefd?
       val () 
          = assert_errmsg( kqueuefd_create( kfd )
              , "[kqueue_create_exn] Could not create kqueue fd" )
       prval () = opt_unsome( kfd )
     in kfd 
    end


implement {}
kqueuefd_close( kfd ) 
  = let
      val (pf | fd) = kqueuefd_decode( kfd )
      val (pfclose | err) = kqueue_close( pf | fd )
     in if err != ~1 
        then true
          where {
            prval None_v() = pfclose
            prval () = opt_none(kfd)
          }
        else false
          where {
            prval Some_v(pkq) = pfclose
            val () = kfd := kqueuefd_encode( pkq | fd )
            prval () = opt_some(kfd)
          }
    end

implement {}
kqueuefd_close_exn( kfd ) 
  = let
      var kfd = kfd
       val () 
          = assert_errmsg( kqueuefd_close( kfd )
              , "[kqueue_close_exn] Could not close kqueue fd" )
       prval () = opt_unnone( kfd )
     in
    end

implement {}
kqueuefd_add0( kfd, sfd, efilt, ka ) 
  = let
      var ke : kevent 
      val () 
        = EV_SET( 
            ke
          , sfd
          , efilt
          , ka
          , kevent_fflag_empty
          , kevent_data_empty
          , the_null_ptr 
          ) 
     in kevent(kfd, ke, 1, the_null_ptr, 0, the_null_ptr) 
    end


