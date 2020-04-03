
#include "share/atspre_staload.hats"

staload "libats/libc/SATS/sys/socket.sats"
staload "libats/libc/SATS/netinet/in.sats"
staload "libats/libc/SATS/unistd.sats"
staload "libats/libc/SATS/stdio.sats"

staload "./../SATS/socketfd.sats"
staload "./../SATS/poll.sats"
staload "./../SATS/async_tcp_pool.sats"

(** FIXME: Replace assertloc with proper exceptions **)
(** FIXME: Make threading optional **)
(** FIXME: Make sure env is handled safely when threading is enabled **)

vtypedef async_tcp_pool_impl(a:vtype,n:int) = @{
   maxconn   = size_t n
 , clients   = List0_vt(a) 

 , fds       = arrayptr(pollfd,n)
 , data      = arrayptr(ptr,n)
 , nfds      = sizeLte(n)
 , fdcurr    = sizeLt(n)
 , compress  = bool

}
vtypedef async_tcp_pool_impl(a:vtype) = [n:pos] async_tcp_pool_impl(a,n)

local
absimpl
async_tcp_pool(a) = [n:pos] async_tcp_pool_impl(a,n)
in end
extern
castfn async_tcp_pool_reveal{a:vtype}( async_tcp_pool(a) ) : [n:pos] async_tcp_pool_impl(a,n)
extern
castfn async_tcp_pool_conceal{a:vtype}{n:pos}( async_tcp_pool_impl(a,n) ) : async_tcp_pool(a)
symintr reveal conceal
overload reveal with async_tcp_pool_reveal
overload conceal with async_tcp_pool_conceal

absimpl
async_tcp_params = @{
    maxconn   = sizeGt(0)
  }

absimpl
async_tcp_event = poll_status
  
implement {a}
async_tcp_pool_create( pool, params ) =
    let
      val [n:int] maxconn = params.maxconn
      val fds = arrayptr_make_elt<pollfd>(maxconn, pollfd_empty())
      val data = arrayptr_make_elt<ptr>(maxconn, the_null_ptr)
      var pimpl : async_tcp_pool_impl(a,n)
        = @{
            maxconn   = maxconn
          , clients   = (list_vt_nil() : List0_vt(a))
          , fds       = fds
          , data      = data
          , nfds      = i2sz(0)
          , fdcurr    = i2sz(0)
          , compress  = false
        }
      val p0 : async_tcp_pool( a ) = conceal( pimpl ) 
      val () = pool := p0
      prval () = opt_some(pool) 
    in true 
   end

implement {a}
async_tcp_pool_close_exn( pool ) =
  let
    val pool : async_tcp_pool_impl(a) = reveal( pool )
    val () =
      ( free( pool.fds );
        free( pool.data ); 
        list_vt_freelin<a>( pool.clients ) where {
          implement list_vt_freelin$clear<a>( x ) 
            = $effmask_all( sockenv$free<a>( x ) )
        } 
      )
  in 
  end

fun {sockenv:vtype} 
  async_tcp_pool_clear_disposed
  ( pool0: &async_tcp_pool(sockenv) )
  : void = {
      var pool : async_tcp_pool_impl(sockenv) 
        = reveal(pool0)
      val () = pool.clients := list_vt_filterlin<sockenv>(  pool.clients )
      val () = pool0 := conceal( pool )
    } where {
          implement list_vt_filterlin$clear<sockenv>( x ) 
            = $effmask_all( sockenv$free<sockenv>( x ) ) 
          implement list_vt_filterlin$pred<sockenv>( x ) 
            = $effmask_all( ~sockenv$isdisposed<sockenv>( x ) )
      }
  

implement {}
async_tcp_pool_add{sockenv}{fd}( pool0, cfd, evts, senv ) =
  if socketfd_set_nonblocking( cfd ) &&
     socketfd_set_cloexec( cfd ) 
  then 
   let
      (** Politicking with dependent types **)
      fn 
        async_tcp_pool_add{sockenv:vtype}{n:pos}{fd:int}{st:status}
        ( pool: &async_tcp_pool_impl(sockenv,n)
        , cfd: !socketfd(fd,st)
        , evts: async_tcp_event
        , senv: &sockenv >> opt(sockenv,~b) 
       ) : #[b:bool] bool b
        =  let
              val nfds = pool.nfds
              val maxconn = pool.maxconn
            in if nfds < maxconn
               then
                  let
                    val () = arrayptr_set_at<pollfd>( 
                          pool.fds
                        , nfds
                        , pollfd_init( socketfd_value(cfd), $UNSAFE.cast{poll_events}(evts) ) 
                    )
                    val () = arrayptr_set_at<ptr>( pool.data, nfds, $UNSAFE.castvwtp1{ptr}(senv) )
                    val () = pool.clients := list_vt_cons( senv, pool.clients )
                    val () = pool.nfds := nfds + 1
                    prval () = opt_none( senv )
                   in true 
                  end
              else false where {
                  prval () = opt_some( senv )
                }
           end 
      var pool : [n:pos] async_tcp_pool_impl(sockenv,n)
        = reveal( pool0 )
      val b = async_tcp_pool_add( pool, cfd, evts, senv )
      val () = pool0 := conceal( pool ) 
     in b
   end
  else false where {
    prval () = opt_some( senv )
  }

 
implement {}
async_tcp_pool_del{fd}( pool0, cfd ) =
    let 
        var pool : [a:vtype] async_tcp_pool_impl(a)
          = reveal( pool0 )
        val () = arrayptr_set_at<pollfd>( pool.fds, pool.fdcurr, pollfd_empty() )
        val () = pool.compress := true
        val () = pool0 := conceal( pool ) 
    in true
    end

implement {}
async_tcp_pool_mod{fd}( pool0, cfd, evts, senv ) =
    let 
        var pool : [a:vtype] async_tcp_pool_impl(a)
          = reveal( pool0 )

        val () = arrayptr_set_at<pollfd>( 
              pool.fds
            , pool.fdcurr
            , pollfd_init( socketfd_value(cfd), $UNSAFE.cast{poll_events}(evts) ) 
        )
        val () = arrayptr_set_at<ptr>( pool.data, pool.fdcurr, $UNSAFE.castvwtp1{ptr}(senv) )
        val () = pool0 := conceal( pool ) 
    in true
    end

implement {}
async_tcp_pool_add_exn{sockenv}{fd}( pool, cfd, evts, senv ) =
  let
    var senv = senv
    val () = assertloc( async_tcp_pool_add<>(pool,cfd,evts,senv) )
    prval () = opt_unnone(senv) 
  in
  end

implement {}
async_tcp_pool_del_exn{fd}( pool, cfd ) =
  let
    val () = assertloc( async_tcp_pool_del<>(pool,cfd) )
  in
  end

implement {}
async_tcp_pool_mod_exn{sockenv}{fd}( pool, cfd, evts, senv ) =
  let
    val () = assertloc( async_tcp_pool_mod<>(pool,cfd,evts,senv) )
  in
  end

implement {env}{senv}
async_tcp_pool_hup( pool, env, senv )  = (
  sockenv$setdisposed<senv>(senv);
  println!("HUP");
)

implement {env}{senv}
async_tcp_pool_error( pool, env, senv ) = (
    sockenv$setdisposed<senv>(senv);
    println!("ERR");
)

implement  {env}{sockenv}
async_tcp_pool_run( pool, env )  
  = let

      fun compress_pool{n:pos}(
        pool : &async_tcp_pool_impl(sockenv,n)
      ) : void = ( 
          let
            fun loop1{i,n,m:nat | i <= n; m > 0; n <= m } (
              pool : &async_tcp_pool_impl(sockenv,m)
            , i : size_t i
            , n : size_t n
            ) : void =
              if i < n
              then  
                let
                  val pfd = arrayptr_get_at<pollfd>( pool.fds, i )
                 in if pfd.fd = ~1
                    then loop2(pool,i,i,n)
                    else loop1(pool,i + 1, n)
                end
              else ()
 
            and loop2{i,j,n,m:nat | i < n; j <= n; m > 0; n <= m} (
              pool : &async_tcp_pool_impl(sockenv,m)
            , i : size_t i
            , j : size_t j
            , n : size_t n
            ) : void =
              if j + 1 < n
              then 
               let
                  val pfd1 = arrayptr_get_at<pollfd>( pool.fds, j + 1 )
                  val  ()  = arrayptr_set_at<pollfd>( pool.fds, j, pfd1 )
                  val p0   = arrayptr_get_at<ptr>( pool.data, j + 1 )
                  val ()   = arrayptr_set_at<ptr>( pool.data, j, p0 )
                in loop2(pool,i,j+1,n)
               end
              else 
                if j < n 
                then
                   let
                      val  ()  = arrayptr_set_at<pollfd>( pool.fds, j, pollfd_empty() )
                      val  ()  = arrayptr_set_at<ptr>( pool.data, j, the_null_ptr )
                    in loop2(pool,i,j+1,n)
                   end
                else      
                  let
                    val () = if n > 0 then pool.nfds := n - 1 else ()
                   in if i > 0
                      then loop1(pool,i-1,n-1)
                      else if n > 0
                           then loop1(pool,i2sz(0),n-1)
                           else ()
                  end
            
             val n = pool.nfds
           in (
              if pool.compress
              then (
                pool.compress := false;
                loop1( pool, i2sz(0), n);
              );
            )
          end
      ) 

      fun loop_evts
        {n,m:nat | m <= n}
      (
        pool : &async_tcp_pool_impl(sockenv,n)
      , nfds: size_t (m)
      , env  : &env >> _
      ) : void =
        if nfds > 0
        then
          let
            val pfd = arrayptr_get_at<pollfd>( pool.fds, nfds - 1)
            val  p  = arrayptr_get_at<ptr>( pool.data, nfds - 1)
            val sock = pfd.fd
            val status = pollfd_status(  pfd )
            val () = pool.fdcurr := nfds - 1

            var pool0 : async_tcp_pool(sockenv)
              = conceal( pool )
            val senv = $UNSAFE.castvwtp1{sockenv}(p)
            val () = ( 
              ifcase
              | poll_status_has( status, POLLHUP ) => 
                    async_tcp_pool_hup<env><sockenv>(pool0, env, senv )
              | poll_status_has( status, POLLERR ) =>
                    async_tcp_pool_error<env><sockenv>(pool0, env, senv )
              | poll_status_has( status, POLLNVAL ) =>
                    async_tcp_pool_error<env><sockenv>(pool0, env, senv )
              | _ => async_tcp_pool_process<sockenv>(pool0, status, senv )
             ) 

             prval () = $UNSAFE.cast2void( senv )
             val () = pool := reveal(pool0)
           in  
              loop_evts{n,m-1}(pool, nfds - 1, env) where {
                prval () = __assert( pool ) where {
                  extern prfn __assert{o:int}( !async_tcp_pool_impl(sockenv,o) ) : [o == n] void 
                }
              };
          end 
      else ()
 
      and loop_poll(
        pool0 : &async_tcp_pool(sockenv)
      , env  : &env >> _
      ) : void = 
        let
          val () = async_tcp_pool_clear_disposed<sockenv>( pool0 )

          var pool : async_tcp_pool_impl(sockenv)
            = reveal( pool0 )

          val nfds = pool.nfds
          val fds = pool.fds
          val (pf | par ) = arrayptr_takeout_viewptr( fds )
          val n  = poll( !par, sz2nfds( nfds ), ~1 ) 
          prval () = arrayptr_addback( pf | fds )
          val () = pool.fds := fds

          val () = 
            if n > 0 
            then ( 
                   loop_evts( pool, nfds,  env );  
                   compress_pool( pool ) 
                ) 
            else if n = ~1 then perror("poll")

          val () = pool0 := conceal(pool)

 
        in loop_poll( pool0,  env )
        end
    
    in 
      loop_poll( pool, env )
    end 

