
#include "share/atspre_staload.hats"
#include "./../mylibies_link.hats"

typedef asyncpool_epoll = @{
   lfd : int
 , efd : int 
 , ebuf : ptr
 , esz : size_t
}


implement main0 () = println!("Hello [test03]")
