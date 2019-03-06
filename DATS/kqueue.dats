
#include "./../HATS/project.hats"
#include "share/atspre_staload.hats"

staload "libats/libc/SATS/sys/socket.sats"
staload "./../SATS/socketfd.sats"
staload "./../SATS/kqueue.sats"

#ifdef _ASYNCNET_LINK
exception KqueueCreateExn
exception KqueueCloseExn
#endif


implement
lor_evfilt_evfilt( e1, e2 ) 
= $UNSAFE.cast{evfilt}( evfilt2uint( e1 ) lor evfilt2uint( e2 ))

implement
land_evfilt_evfilt( e1, e2 ) 
= $UNSAFE.cast{evfilt}( evfilt2uint( e1 ) land evfilt2uint( e2 ))

implement
evfilt_has( e1, e2 ) 
= g1ofg0( evfilt2uint( e1 land e2 ) != 0U )


implement
kevent_action_land( k1, k2 )
= $UNSAFE.cast{kevent_action}( kevent_action_usint( k1 ) land kevent_action_usint( k2 ) )

implement
kevent_action_lor( k1, k2 ) 
= $UNSAFE.cast{kevent_action}( kevent_action_usint( k1 ) lor kevent_action_usint( k2 ) )

implement
kevent_action_has( k1, k2 ) 
= g1ofg0( $UNSAFE.cast{int}(( k1 land k2 )) != 0 )


implement
kevent_flag_land( k1, k2 )
= $UNSAFE.cast{kevent_flag}( kevent_flag_usint( k1 ) land kevent_flag_usint( k2 ) )

implement
kevent_flag_lor( k1, k2 ) 
= $UNSAFE.cast{kevent_flag}( kevent_flag_usint( k1 ) lor kevent_flag_usint( k2 ) )

implement
kevent_flag_has( k1, k2 ) 
= g1ofg0( $UNSAFE.cast{int}(( k1 land k2 )) != 0 )


implement
kevent_status_land( k1, k2 )
= $UNSAFE.cast{kevent_status}( kevent_status_usint( k1 ) land kevent_status_usint( k2 ) )

implement
kevent_status_lor( k1, k2 ) 
= $UNSAFE.cast{kevent_status}( kevent_status_usint( k1 ) lor kevent_status_usint( k2 ) )

implement
kevent_status_has( k1, k2 ) 
= g1ofg0( $UNSAFE.cast{int}(( k1 land k2 )) != 0 )


implement
kevent_fflag_land( k1, k2 )
= $UNSAFE.cast{kevent_fflag}( kevent_fflag_uint( k1 ) land kevent_fflag_uint( k2 ) )

implement
kevent_fflag_lor( k1, k2 ) 
= $UNSAFE.cast{kevent_fflag}( kevent_fflag_uint( k1 ) lor kevent_fflag_uint( k2 ) )

implement
kevent_fflag_has( k1, k2 ) 
= g1ofg0( kevent_fflag_uint( k1 land k2 ) != 0 )


implement
kevent_empty() 
 = (@{
     ident = $UNSAFE.cast{uintptr}(0)
   , filter = evfilt_empty
   , flags = kevent_flag_empty 
   , fflags = kevent_fflag_empty
   , data = kevent_data_empty
   , udata = the_null_ptr 
  })

implement 
kqueue_exn ()  
= let
    val (pf | fd) = kqueue()
  in if fd > ~1 
     then 
      let
        prval Some_v(pkq) = pf
      in kqueuefd_encode( pkq | fd )
      end
     else 
      let
        prval None_v() = pf
      in $raise KqueueCreateExn()
      end
  end 

implement
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

implement
kqueuefd_create_exn() 
  = let
      var kfd : kqueuefd?
      
     in if kqueuefd_create( kfd ) 
        then kfd 
         where { prval () = opt_unsome( kfd ) }
        else $raise KqueueCreateExn()
          where { prval () = opt_unnone( kfd ) }
    end


implement
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

implement
kqueuefd_close_exn( kfd ) 
  = let
      var kfd = kfd
     in if kqueuefd_close( kfd )
        then { prval () = opt_unnone( kfd )   } 
        else $raise KqueueCloseExn()
          where {
            prval () = opt_unsome( kfd ) 
            prval () = $UNSAFE.cast2void( kfd )
          } 
    end

implement
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

implement {env}
kevents_foreach( pwait, parr | p, n, env ) 
  = let
      implement
      array_foreach$fwork<kevent><env>( x, env ) =
          kevents_foreach$fwork<env>( pf | x, sfd , env )
        where {
            extern
            prfn kqueue_add_intr {fd:int}{st:status}( !socketfd(fd,st) ) 
              : kqueue_add_v(fd,st)

            val sfd = $UNSAFE.castvwtp1{socketfd0}(x.ident)
            prval pf = kqueue_add_intr(sfd)
          }

      prval (pf1, pf2 ) = array_v_split_at(parr | i2sz(n))
 
      val _ = array_foreach_env<kevent><env>( !p, i2sz(n), env )

      prval () = parr := array_v_unsplit( pf1, pf2 )
 
    in ()
    end

