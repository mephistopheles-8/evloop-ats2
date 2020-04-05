
#include "./../HATS/project.hats"

%{#
 #include <poll.h>
%}

staload "libats/libc/SATS/time.sats"
staload "libats/libc/SATS/signal.sats"

abst@ype nfds_t(int) = $extype"nfds_t"

castfn ulint2nfds : {n:int} ulint n -> nfds_t(n) 
castfn nfds2ulint : {n:int} nfds_t(n) -> ulint n 
castfn size2nfds : {n:int} size_t n -> nfds_t(n) 

castfn int2nfds : {n:int} int n -> nfds_t(n) 
castfn nfds2int : {n:int} nfds_t(n) -> int n 

symintr i2nfds nfds2i sz2nfds
overload i2nfds with ulint2nfds
overload i2nfds with int2nfds
overload sz2nfds with size2nfds
overload nfds2i with nfds2int
overload nfds2i with nfds2ulint


typedef pollfd(n:int) = 
  $extype_struct"struct pollfd" of {
      fd = int n
    , events = sint
    , revents = sint
    }

typedef pollfd = [fd:int] pollfd(fd)

fn pollfd_empty() : pollfd

fn poll{n,m:nat | m <= n}(
   fds: &(@[pollfd][n])
 , nfds: nfds_t(m)
 , timeout: intGte(~1) 
): intBtwe(~1,m) = "mac#" 

fn ppoll{n,m:nat | m <= n}( 
    fds: &(@[pollfd][n])
  , nfds : nfds_t(m)
  , timeout: &timespec
  , ss: &sigset_t 
): intBtwe(~1,m) = "mac#"

/* Event types that can be polled for.  These bits may be set in `events'
   to indicate the interesting event types; they will appear in `revents'
   to indicate the status of the file descriptor.  */
abst@ype poll_events = sint
abst@ype poll_status = sint

castfn poll_events2sint : poll_events -<> sint
castfn poll_status2sint : poll_status -<> sint

castfn poll_events2status : poll_events -<> poll_status


fn poll_status_has_status( poll_status, poll_status ) : bool
fn poll_status_has_event( poll_status, poll_events ) : bool

symintr poll_status_has 
overload poll_status_has with poll_status_has_status
overload poll_status_has with poll_status_has_event

fn pollfd_init{n:int}( fd : int n, events : poll_events ) : pollfd(n) 
fn pollfd_status ( pollfd ) :<> poll_status

symintr pe2si ps2si pe2ps 
overload pe2si with poll_events2sint
overload ps2si with poll_status2sint
overload pe2ps with poll_events2status

macdef POLLIN = $extval(poll_status,"POLLIN")
macdef POLLPRI = $extval(poll_status,"POLLPRI")
macdef POLLOUT = $extval(poll_status,"POLLOUT")

fun {} poll_status_lor ( poll_status, poll_status ) :<> poll_status
overload lor with poll_status_lor

/* These values are defined in XPG4.2.  */
macdef POLLRDNORM = $extval(poll_events,"POLLRDNORM")
macdef POLLRDBAND = $extval(poll_events,"POLLRDBAND")
macdef POLLWRNORM = $extval(poll_events,"POLLWRNORM")
macdef POLLWRBAND = $extval(poll_events,"POLLWRBAND")

/* These are extensions for Linux.  */
macdef POLLMSG = $extval(poll_events,"POLLMSG")
macdef POLLREMOVE = $extval(poll_events,"POLLREMOVE")
macdef POLLRDHUP = $extval(poll_events,"POLLRDHUP")

/* Event types always implicitly polled for.  These bits need not be set in
   `events', but they will appear in `revents' to indicate the status of
   the file descriptor.  */
macdef POLLERR = $extval(poll_status,"POLLERR")
macdef POLLHUP = $extval(poll_status,"POLLHUP")
macdef POLLNVAL = $extval(poll_status,"POLLNVAL")
                                                                               
