
#include "./../HATS/project.hats"
(**
 * Userspace Bindings for kqueue.
 *)
staload "libats/libc/SATS/time.sats"

%{#
#include <sys/event.h>
%}


typedef kevent_struct0 = $extype_struct "struct kevent" of {
    ident= uintptr
  , filter= sint
  , flags= usint
  , fflags=uint
  , data= int64
  , udata= ptr 
}

abst@ype evfilt = uint
macdef EVFILT_READ = $extval(evfilt, "EVFILT_READ")
macdef EVFILT_WRITE = $extval(evfilt, "EVFILT_WRITE")
macdef EVFILT_AIO = $extval(evfilt, "EVFILT_AIO")
macdef EVFILT_VNODE = $extval(evfilt, "EVFILT_VNODE")
macdef EVFILT_PROC = $extval(evfilt, "EVFILT_PROC")
macdef EVFILT_SIGNAL = $extval(evfilt, "EVFILT_SIGNAL")
macdef EVFILT_TIMER = $extval(evfilt, "EVFILT_TIMER")
macdef EVFILT_DEVICE = $extval(evfilt, "EVFILT_DEVICE")

macdef EVFILT_SYSCOUNT = $extval(evfilt, "EVFILT_SYSCOUNT")


/* actions */
abst@ype kevent_action = usint
macdef EV_ADD = $extval(kevent_action, "EV_ADD")
macdef EV_DELETE = $extval(kevent_action, "EV_DELETE")
macdef EV_ENABLE = $extval(kevent_action, "EV_ENABLE")
macdef EV_DISABLE = $extval(kevent_action, "EV_DISABLE")

/* flags */
abst@ype kevent_flag = usint
macdef EV_ONESHOT = $extval(kevent_flag, "EV_ONESHOT")
macdef EV_CLEAR = $extval(kevent_flag, "EV_CLEAR")
macdef EV_RECEIPT = $extval(kevent_flag, "EV_RECEIPT")
macdef EV_DISPATCH = $extval(kevent_flag, "EV_DISPATCH")

macdef EV_SYSFLAGS = $extval(kevent_flag, "EV_SYSFLAGS")
macdef EV_FLAG1 = $extval(kevent_flag, "EV_FLAG1")

/* returned values */
abst@ype kevent_status = usint
macdef EV_EOF = $extval(kevent_status, "EV_EOF")
macdef EV_ERROR = $extval(kevent_status, "EV_ERROR")

/*
 * data/hint flags for EVFILT_{READ|WRITE}, shared with userspace
 */

sortdef fflag_sort = int
stadef ff_empty = 0
stadef ff_rw = 1
stadef ff_vnode = 2
stadef ff_proc = 3
stadef ff_device = 4

abst@ype kevent_fflag(fflag_sort) = uint
typedef kevent_fflag = [ff: fflag_sort] kevent_fflag(ff)

macdef kevent_fflag_empty = $extval(kevent_fflag(ff_empty), "0")
 
macdef NOTE_LOWAT = $extval(kevent_fflag(ff_rw), "NOTE_LOWAT")
macdef NOTE_EOF = $extval(kevent_fflag(ff_rw), "NOTE_EOF")

/*
 * data/hint flags for EVFILT_VNODE, shared with userspace
 */
macdef NOTE_DELETE = $extval(kevent_fflag(ff_vnode), "NOTE_DELETE")
macdef NOTE_WRITE = $extval(kevent_fflag(ff_vnode), "NOTE_WRITE")
macdef NOTE_EXTEND = $extval(kevent_fflag(ff_vnode), "NOTE_EXTEND")
macdef NOTE_ATTRIB = $extval(kevent_fflag(ff_vnode), "NOTE_ATTRIB")
macdef NOTE_LINK = $extval(kevent_fflag(ff_vnode), "NOTE_LINK")
macdef NOTE_RENAME = $extval(kevent_fflag(ff_vnode), "NOTE_RENAME")
macdef NOTE_REVOKE = $extval(kevent_fflag(ff_vnode), "NOTE_REVOKE")
macdef NOTE_TRUNCATE = $extval(kevent_fflag(ff_vnode), "NOTE_TRUNCATE")

/*
 * data/hint flags for EVFILT_PROC, shared with userspace
 */
(** FIXME: Aren't these int64? Looks like they are defined as 64 bits but used in ffilt **)
macdef NOTE_EXIT = $extval(kevent_fflag(ff_proc), "NOTE_EXIT")
macdef NOTE_FORK = $extval(kevent_fflag(ff_proc), "NOTE_FORK")
macdef NOTE_EXEC = $extval(kevent_fflag(ff_proc), "NOTE_EXEC")
macdef NOTE_PCTRLMASK = $extval(kevent_fflag(ff_proc), "NOTE_PCTRLMASK")
macdef NOTE_PDATAMASK = $extval(kevent_fflag(ff_proc), "NOTE_PDATAMASK")

/* additional flags for EVFILT_PROC */
macdef NOTE_TRACK = $extval(kevent_fflag(ff_proc), "NOTE_TRACK")
macdef NOTE_TRACKERR = $extval(kevent_fflag(ff_proc), "NOTE_TRACKERR")
macdef NOTE_CHILD = $extval(kevent_fflag(ff_proc), "NOTE_CHILD")

/* data/hint flags for EVFILT_DEVICE, shared with userspace */
macdef NOTE_CHANGE = $extval(kevent_fflag(ff_device), "NOTE_CHANGE")

abst@ype kevent_data = int64

typedef kevent = $extype_struct "struct kevent" of {
    ident= uintptr
  , filter= evfilt
  , flags= kevent_flag
  , fflags=kevent_fflag
  , data= kevent_data
  , udata= ptr 
}

macdef kevent_data_empty = $extval(kevent_data, "0")


absvt@ype kqueuefd(int) = int
abst@ype kqueue(int) = int

vtypedef kqueuefd = [fd:int] kqueuefd(fd)

absview kqueue_v( fd:int )


exception KqueueCreateExn
exception KqueueCloseExn

castfn kqueuefd_encode{fd:int}
  ( kqueue_v(fd) | int fd ) 
  : kqueuefd(fd)
 
castfn kqueuefd_decode{fd:int}
  ( kqueuefd(fd) ) 
  : (kqueue_v(fd) | int fd) 


castfn 
kqueuefd_kqueue{fd:int}( kqueuefd(fd) ) 
  : ( kqueue_v(fd) | kqueue(fd) )

castfn 
kqueue_kqueuefd{fd:int}( kqueue_v(fd) | kqueue(fd) ) 
  : kqueuefd(fd)


fn EV_SET(
    kevp : kevent
  , ident: uintptr
  , filter:evfilt
  , flags: kevent_flag
  , fflags: kevent_fflag
  , data: kevent_data
  , udata: ptr 
): void = "mac#"

fn kqueue () : [fd:int] ( option_v(kqueue_v(fd), fd > ~1) |  int fd ) = "mac#"

fn kqueue_exn () : [fd:int] kqueuefd(fd)

fn kqueuefd_create
  ( kfd: &kqueuefd? >> opt(kqueuefd,b) ) 
  : #[b:bool] bool b

fn kqueuefd_create_exn()
  : kqueuefd

fn kevent {n,m:nat}
( kq: !kqueuefd
, changelist: &(@[kevent][n])
, nchanges: int n
, eventlist: &(@[kevent][m])
, nevents: int m
, timeout: &timespec   
): intBtwe(~1,m) = "mac#"


fn kqueue_close{fd:int}( kqueue_v(fd) | int fd  )  
  : [err: int | err >= ~1; err <= 0] 
    ( option_v(kqueue_v(fd), err == ~1) | int err ) = "mac#close"

fn kqueuefd_close{fd:int}
  ( kfd: &kqueuefd(fd) >> opt(kqueuefd(fd), ~b) ) 
  : #[b:bool] bool b
 
fn kqueuefd_close_exn{fd:int}( kqueuefd(fd) ) : void


