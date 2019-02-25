
#include "./../HATS/project.hats"

(** A pointer to a buffer. An attempt to get arrays to play nicely with templates and records.
    Basically an arrayptr without gc
 **)


absvtype bufptr(a:vt@ype+,l:addr, n:int) = ptr

castfn 
bufptr_encode{a:vt@ype+}{l:addr}{n:nat}( array_v(INV(a), l, n) | ptr l ) :<> bufptr(a,l,n)

castfn 
bufptr_decode{a:vt@ype+}{l:addr}{n:nat}( bufptr(INV(a),l,n)  ) :<> (array_v( a, l, n) | ptr l)
