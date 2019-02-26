
#include "./../HATS/project.hats"

(** A pointer to a buffer. An attempt to get arrays to play nicely with templates and records.
    Basically an arrayptr without gc
 **)


absvtype bufptr(a:vt@ype+,l:addr, n:int) = ptr

castfn 
bufptr_encode{a:vt@ype+}{l:addr}{n:nat}( array_v(INV(a), l, n) | ptr l ) :<> bufptr(a,l,n)

castfn 
bufptr_decode{a:vt@ype+}{l:addr}{n:nat}( bufptr(INV(a),l,n)  ) :<> (array_v( a, l, n) | ptr l)

vtypedef bufptr(a:vt@ype+) = [l:addr][n:int] bufptr(a,l,n)

vtypedef bufptr(a:vt@ype+,n:int) = [l:addr] bufptr(a,l,n)


typedef ptrsz(l:addr,n:int) = @{
    buf = ptr l
  , sz  = size_t n 
  }

absvt@ype bufptrsz(a:vt@ype+,l:addr,n:int) = ptrsz(l,n)

fn bufptrsz_create_bufptr{a:vt@ype+}{l:addr}{n:nat}
  ( bufptr(a,l,n), size_t n ) : bufptrsz(a,l,n) 

fn bufptrsz_create_array{a:vt@ype+}{l:addr}{n:nat}
  ( array_v(INV(a),l,n) | ptr l, size_t n ) : bufptrsz(a,l,n)

castfn bufptrsz_decode{a:vt@ype}{l:addr}{n:nat}
  ( bufptr(a,l,n) ) : (array_v(a,l,n) | ptrsz(l,n))


