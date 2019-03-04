
#include "./../HATS/project.hats"
#include "share/atspre_staload.hats"

staload "./../SATS/kqueue.sats"

#ifdef _ASYNCNET_LINK
exception KqueueCreateExn
exception KqueueCloseExn
#endif

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
            val () = $UNSAFE.cast2void( kfd )
          } 
    end








