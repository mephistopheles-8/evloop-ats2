
#include "./../HATS/project.hats"

%{#
#include <sys/event.h>
%}

abst@ype evfilt = int

typedef kevent_struct = $extype_struct "struct kevent" of {
    ident= uintptr
  , filter=int8
  , flags=int8
  , fflags= uint
  , data= int64
  , udata= ptr 
}

abstype kevent = ref(kevent_struct)

macdef EVFILT_READ = $extval(evfilt, "EVFILT_READ")
macdef EVFILT_WRITE = $extval(evfilt, "EVFILT_WRITE")
macdef EVFILT_AIO = $extval(evfilt, "EVFILT_AIO")
macdef EVFILT_VNODE = $extval(evfilt, "EVFILT_VNODE")
macdef EVFILT_PROC = $extval(evfilt, "EVFILT_PROC")
macdef EVFILT_SIGNAL = $extval(evfilt, "EVFILT_SIGNAL")
macdef EVFILT_TIMER = $extval(evfilt, "EVFILT_TIMER")
macdef EVFILT_DEVICE = $extval(evfilt, "EVFILT_DEVICE")

macdef EVFILT_SYSCOUNT = $extval(evfilt, "EVFILT_SYSCOUNT")

fn EV_SET(
    kevp : kevent
  , ident: uintptr
  , filter:int8
  , flags:int8
  , fflags: uint
  , data: int64
  , udata: ptr 
): void


/* actions */
abst@ype kevent_action = int
macdef EV_ADD = $extval(kevent_action, "EV_ADD")
macdef EV_DELETE = $extval(kevent_action, "EV_DELETE")
macdef EV_ENABLE = $extval(kevent_action, "EV_ENABLE")
macdef EV_DISABLE = $extval(kevent_action, "EV_DISABLE")

/* flags */
abst@ype kevent_flag = int
macdef EV_ONESHOT = $extval(kevent_flag, "EV_ONESHOT")
macdef EV_CLEAR = $extval(kevent_flag, "EV_CLEAR")
macdef EV_RECEIPT = $extval(kevent_flag, "EV_RECEIPT")
macdef EV_DISPATCH = $extval(kevent_flag, "EV_DISPATCH")

macdef EV_SYSFLAGS = $extval(kevent_flag, "EV_SYSFLAGS")
macdef EV_FLAG1 = $extval(kevent_flag, "EV_FLAG1")

/* returned values */
abst@ype kevent_status = int
macdef EV_EOF = $extval(kevent_status, "EV_EOF")
macdef EV_ERROR = $extval(kevent_status, "EV_ERROR")

/*
 * data/hint flags for EVFILT_{READ|WRITE}, shared with userspace
 */
macdef NOTE_LOWAT = $extval(kevent_status, "NOTE_LOWAT")
macdef NOTE_EOF = $extval(kevent_status, "NOTE_EOF")

/*
 * data/hint flags for EVFILT_VNODE, shared with userspace
 */
macdef NOTE_DELETE = $extval(kevent_flag, "NOTE_DELETE")
macdef NOTE_WRITE = $extval(kevent_flag, "NOTE_WRITE")
macdef NOTE_EXTEND = $extval(kevent_flag, "NOTE_EXTEND")
macdef NOTE_ATTRIB = $extval(kevent_flag, "NOTE_ATTRIB")
macdef NOTE_LINK = $extval(kevent_flag, "NOTE_LINK")
macdef NOTE_RENAME = $extval(kevent_flag, "NOTE_RENAME")
macdef NOTE_REVOKE = $extval(kevent_flag, "NOTE_REVOKE")
macdef NOTE_TRUNCATE = $extval(kevent_flag, "NOTE_TRUNCATE")

/*
 * data/hint flags for EVFILT_PROC, shared with userspace
 */
macdef NOTE_EXIT = $extval(kevent_flag, "NOTE_EXIT")
macdef NOTE_FORK = $extval(kevent_flag, "NOTE_FORK")
macdef NOTE_EXEC = $extval(kevent_flag, "NOTE_EXEC")
macdef NOTE_PCTRLMASK = $extval(kevent_flag, "NOTE_PCTRLMASK")
macdef NOTE_PDATAMASK = $extval(kevent_flag, "NOTE_PDATAMASK")

/* additional flags for EVFILT_PROC */
macdef NOTE_TRACK = $extval(kevent_flag, "NOTE_TRACK")
macdef NOTE_TRACKERR = $extval(kevent_flag, "NOTE_TRACKERR")
macdef NOTE_CHILD = $extval(kevent_flag, "NOTE_CHILD")

/* data/hint flags for EVFILT_DEVICE, shared with userspace */
macdef NOTE_CHANGE = $extval(kevent_flag, "NOTE_CHANGE")

// is this in the system already?
typedef timespec = $extype_struct "struct timespec" of {foo=int};

absvt@ype kqueuefd = int

fn kqueue () : kqueuefd = "mac#"
fn kevent {n,m:nat}
( kq: !kqueuefd
, changelist: &(@[kevent][n])
, nchanges: int n
, eventlist: &(@[kevent][m])
, nevents: int m
, timeout: &timespec   
): intBtwe(~1,m) = "mac#"


