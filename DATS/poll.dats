
#include "./../HATS/project.hats"
#include "share/atspre_staload.hats"

staload "./../SATS/poll.sats"


implement {}
pollfd_empty ( ) =
  let
    var pfd : pollfd(~1)
    val () = pfd.fd := ~1
    val () = pfd.events := $UNSAFE.cast{sint}(0)
    val () = pfd.revents :=$UNSAFE.cast{sint}(0)
   in pfd
  end

implement {}
poll_status_lhas_status_status( ps0, ps1) =
  (($UNSAFE.cast{uint}(ps0) land $UNSAFE.cast{uint}(ps1)) > 0 )

implement {}
poll_status_lhas_status_events( ps0, ps1) =
  (($UNSAFE.cast{uint}(ps0) land $UNSAFE.cast{uint}(ps1)) > 0 )

implement {}
pollfd_init{fd}( fd, s ) =
  let
    var pfd : pollfd(fd)
    val () = pfd.fd := fd
    val () = pfd.events := pe2si( s )
    val () = pfd.revents := $UNSAFE.cast{sint}(0)
   in pfd
  end

implement {}
pollfd_status( pfd ) =
 $UNSAFE.cast{poll_status}(pfd.revents)

implement {}
poll_status_lor( ps0, ps1) =
  ($UNSAFE.cast{poll_status}($UNSAFE.cast{uint}(ps0) lor $UNSAFE.cast{uint}(ps1)))




