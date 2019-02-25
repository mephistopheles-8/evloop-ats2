
#include "share/atspre_staload.hats"
#include "./../mylibies_link.hats"

typedef asyncpool_epoll = @{
   lfd = int
 , efd = int 
 , ebuf = ptr
 , esz = size_t
}

vtypedef bufptr = [l:addr][n:int][a:vt@ype+] bufptr(a,l,n)

vtypedef bufptr(n:int) = [l:addr][a:vt@ype+] bufptr(a,l,n)

fun test_bufptr () =
  let

    vtypedef mystate(l,n) = @{
      buf = bufptr(byte,l,n)
    , bsz = size_t n
    }


    var ints = @[int][1024](0)
    var buf = @[byte][1024](i2byte(0))

  
    implement(a,l,n)
    array_foreach$fwork<int><bufptr(a,l,n)>(x,env) =
      let
      in
      end

    var pbuf = bufptr_encode( view@buf | addr@buf )

    val _ = array_foreach_env<int><bufptr(byte,buf,1024)>(ints,i2sz(1024),pbuf)

    val ( pf | p0 ) = bufptr_decode( pbuf )
    prval () = view@buf := pf 

  in
  end


implement main0 () = println!("Hello [test03]")
  where {
    val () = test_bufptr()

  }
