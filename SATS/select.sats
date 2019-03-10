
#include "./../HATS/project.hats"

%{#
  #include <sys/select.h>
%}

staload "libats/libc/SATS/sys/time.sats"
staload "libats/libc/SATS/time.sats"
staload "libats/libc/SATS/signal.sats"

(** TODO: Best define a more sane interface **)
abst@ype fd_set = $extype"fd_set"

fun select_read_timeout{n,m:nat | m <= n}( 
   nfds: int m
 , readfds:  &(@[fd_set][n])  
 , writefds:  ptr null
 , exceptfds: ptr null
 , timeout : &timeval
 ): intBtwe(~1,m) = "mac#select" 

fun select_read{n,m:nat | m <= n}( 
   nfds: int m
 , readfds:  &(@[fd_set][n])  
 , writefds:  ptr null
 , exceptfds: ptr null
 , timeout : ptr null
 ): intBtwe(~1,m) = "mac#select" 

fun select_write_timeout{n,m:nat | m <= n}( 
   nfds: int m
 , readfds:  ptr null
 , writefds:  &(@[fd_set][n])  
 , exceptfds: ptr null
 , timeout : &timeval
 ): intBtwe(~1,m) = "mac#select" 

fun select_write{n,m:nat | m <= n}( 
   nfds: int m
 , readfds:  ptr null
 , writefds:  &(@[fd_set][n])  
 , exceptfds: ptr null
 , timeout : ptr null
 ): intBtwe(~1,m) = "mac#select" 

fun select_except_timeout{n,m:nat | m <= n}( 
   nfds: int m
 , readfds:  ptr null
 , writefds:  ptr null
 , exceptfds:  &(@[fd_set][n])  
 , timeout : &timeval
 ): intBtwe(~1,m) = "mac#select" 

fun select_except{n,m:nat | m <= n}( 
   nfds: int m
 , readfds:  ptr null
 , writefds:  ptr null
 , exceptfds:  &(@[fd_set][n])  
 , timeout : ptr null
 ): intBtwe(~1,m) = "mac#select" 

symintr select
overload select with select_read_timeout
overload select with select_read
overload select with select_write_timeout
overload select with select_write
overload select with select_except_timeout
overload select with select_except

fun pselect_read_timeout{n,m:nat | m <= n}( 
   nfds: int m
 , readfds:  &(@[fd_set][n])  
 , writefds:  ptr null
 , exceptfds: ptr null
 , timeout : &timespec
 , sigmask : &sigset_t
 ): intBtwe(~1,m) = "mac#pselect" 

fun pselect_read{n,m:nat | m <= n}( 
   nfds: int m
 , readfds:  &(@[fd_set][n])  
 , writefds:  ptr null
 , exceptfds: ptr null
 , timeout : ptr null
 , sigmask : &sigset_t
 ): intBtwe(~1,m) = "mac#pselect" 

fun pselect_write_timeout{n,m:nat | m <= n}( 
   nfds: int m
 , readfds:  ptr null
 , writefds:  &(@[fd_set][n])  
 , exceptfds: ptr null
 , timeout : &timespec
 , sigmask : &sigset_t
 ): intBtwe(~1,m) = "mac#pselect" 

fun pselect_write{n,m:nat | m <= n}( 
   nfds: int m
 , readfds:  ptr null
 , writefds:  &(@[fd_set][n])  
 , exceptfds: ptr null
 , timeout : ptr null
 , sigmask : &sigset_t
 ): intBtwe(~1,m) = "mac#pselect" 

fun pselect_except_timeout{n,m:nat | m <= n}( 
   nfds: int m
 , readfds:  ptr null
 , writefds:  ptr null
 , exceptfds:  &(@[fd_set][n])  
 , timeout : &timespec
 , sigmask : &sigset_t
 ): intBtwe(~1,m) = "mac#pselect" 

fun pselect_except{n,m:nat | m <= n}( 
   nfds: int m
 , readfds:  ptr null
 , writefds:  ptr null
 , exceptfds:  &(@[fd_set][n])  
 , timeout : ptr null
 , sigmask : &sigset_t
 ): intBtwe(~1,m) = "mac#pselect" 

symintr pselect
overload pselect with pselect_read_timeout
overload pselect with pselect_read
overload pselect with pselect_write_timeout
overload pselect with pselect_write
overload pselect with pselect_except_timeout
overload pselect with pselect_except

fn FD_CLR{fd:int}( int fd, &fd_set) : void = "mac#" 
fn FD_ISSET{fd:int}( int fd, &fd_set) : bool = "mac#"
fn FD_SET{fd:int}( int fd, &fd_set) : void = "mac#"
fn FD_ZERO{fd:int}( &fd_set) : void = "mac#"
