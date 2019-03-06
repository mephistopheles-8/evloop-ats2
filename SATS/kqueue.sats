
#include "./../HATS/project.hats"
(**
 * Userspace Bindings for kqueue.
 *)
staload "libats/libc/SATS/time.sats"
staload "libats/libc/SATS/sys/socket.sats"
staload "./socketfd.sats"

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

macdef evfilt_empty = $extval(evfilt, "0")

castfn evfilt2uint( evfilt ) : uint

fn lor_evfilt_evfilt( evfilt, evfilt ) :<> evfilt
fn land_evfilt_evfilt( evfilt, evfilt ) :<> evfilt
fn evfilt_has( evfilt, evfilt ) :<> [b:bool] bool b
overload lor with lor_evfilt_evfilt
overload land with land_evfilt_evfilt




/* actions */
abst@ype kevent_action = usint
macdef EV_ADD = $extval(kevent_action, "EV_ADD")
macdef EV_DELETE = $extval(kevent_action, "EV_DELETE")
macdef EV_ENABLE = $extval(kevent_action, "EV_ENABLE")
macdef EV_DISABLE = $extval(kevent_action, "EV_DISABLE")

castfn kevent_action_usint( kevent_action ) : usint

fn kevent_action_land( kevent_action, kevent_action ) :<> kevent_action
fn kevent_action_lor( kevent_action, kevent_action ) :<> kevent_action
fn kevent_action_has( kevent_action, kevent_action ) :<> [b:bool] bool b

overload lor with kevent_action_lor
overload land with kevent_action_land

/* flags */
abst@ype kevent_flag = usint
macdef EV_ONESHOT = $extval(kevent_flag, "EV_ONESHOT")
macdef EV_CLEAR = $extval(kevent_flag, "EV_CLEAR")
macdef EV_RECEIPT = $extval(kevent_flag, "EV_RECEIPT")
macdef EV_DISPATCH = $extval(kevent_flag, "EV_DISPATCH")

macdef EV_SYSFLAGS = $extval(kevent_flag, "EV_SYSFLAGS")
macdef EV_FLAG1 = $extval(kevent_flag, "EV_FLAG1")

macdef kevent_flag_empty = $extval(kevent_flag, "0")

castfn kevent_flag_usint( kevent_flag ) : usint

fn kevent_flag_land( kevent_flag, kevent_flag ) :<> kevent_flag
fn kevent_flag_lor( kevent_flag, kevent_flag ) :<> kevent_flag
fn kevent_flag_has( kevent_flag, kevent_flag ) :<> [b:bool] bool b

overload lor with kevent_flag_lor
overload land with kevent_flag_land

/* returned values */
abst@ype kevent_status = usint
macdef EV_EOF = $extval(kevent_status, "EV_EOF")
macdef EV_ERROR = $extval(kevent_status, "EV_ERROR")

castfn kevent_status_usint( kevent_status ) : usint
castfn flags2status( kevent_flag ) : kevent_status

fn kevent_status_land( kevent_status, kevent_status ) :<> kevent_status
fn kevent_status_lor( kevent_status, kevent_status ) :<> kevent_status
fn kevent_status_has( kevent_status, kevent_status ) :<> [b:bool] bool b

overload lor with kevent_status_lor
overload land with kevent_status_land

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


castfn kevent_fflag_usint( kevent_fflag ) : uint

fn kevent_fflag_land( kevent_fflag, kevent_fflag ) :<> kevent_fflag
fn kevent_fflag_lor( kevent_fflag, kevent_fflag ) :<> kevent_fflag
fn kevent_fflag_has( kevent_fflag, kevent_fflag ) :<> [b:bool] bool b

overload lor with kevent_fflag_lor
overload land with kevent_fflag_land


abst@ype kevent_data = int64
macdef kevent_data_empty = $extval(kevent_data, "0")

typedef kevent = $extype_struct "struct kevent" of {
    ident= uintptr
  , filter= evfilt
  , flags= kevent_flag
  , fflags=kevent_fflag
  , data= kevent_data
  , udata= ptr 
}

fn kevent_empty() : kevent

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
    kevp : &kevent
  , ident: !socketfd0
  , filter:evfilt
  , flags: kevent_action
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

symintr kevent

fn kevent_arr_arr_timeout {n,m,sn,sm:nat | sn <= n; sm <= m}
( kq: !kqueuefd
, changelist: &(@[kevent][n])
, nchanges: int sn
, eventlist: &(@[kevent][m])
, nevents: int sm
, timeout: &timespec   
): intBtwe(~1,sm) = "mac#"

fn kevent_sing_null_null
( kq: !kqueuefd
, changelist: &kevent
, nchanges: int 1
, eventlist: ptr null
, nevents: int 0
, timeout: ptr null 
): intBtwe(~1,0) = "mac#kevent"

fn kevent_null_arr_null {n,m:nat | m <= n}
( kq: !kqueuefd
, changelist: ptr null
, nchanges: int 0
, eventlist: &(@[kevent][n])
, nevents: int m
, timeout: ptr null 
): intBtwe(~1,m) = "mac#kevent"

overload kevent with kevent_arr_arr_timeout
overload kevent with kevent_sing_null_null
overload kevent with kevent_null_arr_null


fn kqueue_close{fd:int}( kqueue_v(fd) | int fd  )  
  : [err: int | err >= ~1; err <= 0] 
    ( option_v(kqueue_v(fd), err == ~1) | int err ) = "mac#close"

fn kqueuefd_close{fd:int}
  ( kfd: &kqueuefd(fd) >> opt(kqueuefd(fd), ~b) ) 
  : #[b:bool] bool b
 
fn kqueuefd_close_exn{fd:int}( kqueuefd(fd) ) : void


fn kqueuefd_add0( kfd: !kqueuefd, sfd: !socketfd0, kevent_action ) 
  : intBtwe(~1,0) = "ext#%"


absprop kqueue_add_v(fd:int, st:status)

fn kqueuefd_add1{kfd,fd:int}{st:status}( kfd: !kqueuefd(kfd), sfd: !socketfd(fd,st), kevent_action ) 
  : [err: int | err >= ~1; err <= 0]
    (option_v(kqueue_add_v(fd,st), err == 0) | int err )
  = "mac#%kqueukfd_add0"

prfn kqueue_add_elim{fd:int}{st:status}( kqueue_add_v(fd,st) ) : void

prfn kqueue_add_sfd_elim{fd:int}{st:status}( kqueue_add_v(fd,st), socketfd(fd,st) ) : void


absprop kevent_v(l:addr, n:int)

fun kevent1 {n,m:nat}{l:addr} 
  ( pf: (@[kevent][m]) @ l
  | kq: !kqueuefd
  , changelist: &(@[kevent][n])
  , nchanges: int n
  , eventlist: ptr l 
  , nevents: int m
  , timeout: &timespec   
  ): [o:int | o >= ~1 && o <= m]
     (option_v(kevent_v(l,o), o > ~1) | int o ) = "mac#kevent"

fun {env: vt@ype+}
  kevents_foreach$fwork{fd:int}{st:status}
  ( kqueue_add_v(fd,st) | &kevent, socketfd(fd,st), &env >> _ )
  : void 

fun {env: vt@ype+}
  kevents_foreach{n,o:nat | o <= n}{l:addr}
  ( kevent_v(l,o), !(@[kevent][n] @ l) | ptr l, int o, &env >> _ )
  : void


