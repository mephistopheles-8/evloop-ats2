
#include "share/atspre_staload.hats"

staload "libats/libc/SATS/sys/socket.sats"
staload "libats/libc/SATS/netinet/in.sats"
staload "libats/libc/SATS/unistd.sats"
staload "libats/libc/SATS/stdio.sats"

staload "./../SATS/sockfd.sats"
staload "./../SATS/poll.sats"
staload "./../SATS/evloop.sats"

infixl lhas 

vtypedef poll_client_info = @{
    polling_state = sock_polling_state
  , socket_index = size_t
  }

absimpl sockenv_evloop_data = poll_client_info

vtypedef evloop_impl(a:vt@ype+,n:int) = @{
   maxconn   = size_t n
 , clients   = List0_vt(sockenv(a)) 

 , fds       = arrayptr(pollfd,n)
 , data      = arrayptr(ptr,n)
 , nfds      = sizeLte(n)
 , compress  = bool

}
vtypedef evloop_impl(a:vt@ype+) = [n:pos] evloop_impl(a,n)

local
absimpl
evloop(a) = [n:pos] evloop_impl(a,n)
in end
extern
castfn evloop_reveal{a:vt@ype+}( evloop(a) ) : [n:pos] evloop_impl(a,n)
extern
castfn evloop_conceal{a:vt@ype+}{n:pos}( evloop_impl(a,n) ) : evloop(a)
symintr reveal conceal
overload reveal with evloop_reveal
overload conceal with evloop_conceal

absimpl
evloop_params = @{
    maxconn   = sizeGt(0)
  }

absimpl
evloop_event = poll_status
  
implement {a}
evloop_create( pool, params ) =
    let
      val [n:int] maxconn = params.maxconn
      val fds = arrayptr_make_elt<pollfd>(maxconn, pollfd_empty())
      val data = arrayptr_make_elt<ptr>(maxconn, the_null_ptr)
      var pimpl : evloop_impl(a,n)
        = @{
            maxconn   = maxconn
          , clients   = list_vt_nil()
          , fds       = fds
          , data      = data
          , nfds      = i2sz(0)
          , compress  = false
        }
      val p0 : evloop( a ) = conceal( pimpl ) 
      val () = pool := p0
      prval () = opt_some(pool) 
    in true 
   end

fun {senv:vt@ype+} 
  evloop_clear_disposed
  ( pool0: &evloop(senv) )
  : void =  {
          implement list_vt_filterlin$clear<sockenv(senv)>( x ) 
            = {
              val ~CLIENT(sock,info,env) = x
              val () = 
                $effmask_all( 
                     sockfd_close_exn(sock);
                     sockenv$free<senv>( env ) 
                  ) 
            } 
          implement list_vt_filterlin$pred<sockenv(senv)>( x ) = ( 
             case+ info.polling_state of
              | Disposed() => false
              | _ => true
              ) where {
                val CLIENT(_,info,_) = x
              }

          var pool : evloop_impl(senv)
            = reveal( pool0 )
          val () = 
            pool.clients := list_vt_filterlin<sockenv(senv)>(  pool.clients )
          val () = pool0 := conceal( pool ) 

      }
  
implement {a}
evloop_close_exn( pool0 ) =
  let
    var pool : evloop_impl(a) = reveal( pool0 )
    val () =
      ( free(pool.fds);
        free(pool.data); 
        list_vt_freelin<sockenv(a)>( pool.clients ) where {
          implement (a:vt@ype+) 
            list_vt_freelin$clear<sockenv(a)>( x ) 
            = $effmask_all( 
                sockfd_close_exn(sock); 
                sockenv$free<a>( env ) 
              ) where {
                val ~CLIENT(sock,info,env) = x
              }
        } 
      )
    prval () = $UNSAFE.cast2void( pool )
  in 
  end
  
implement {env}{senv}
evloop_hup( pool, env, senv )  = (
  assert_errmsg( evloop_events_dispose( pool, senv )
    , "[evloop_hup] Could not dispose of socket");
)

implement {env}{senv}
evloop_error( pool, env, senv ) = (
    assert_errmsg( evloop_events_dispose( pool, senv )
     , "[evloop_error] Could not dispose of socket");
)

implement  {env}{senv}
evloop_run( pool, env )  
  = let

      fun compress_pool{n:pos}(
        pool : &evloop_impl(senv,n)
      ) : void = ( 
          let
            fun loop1{i,n,m:nat | i <= n; m > 0; n <= m } (
              pool : &evloop_impl(senv,m)
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
              pool : &evloop_impl(senv,m)
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
        pool : &evloop_impl(senv,n)
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

            var pool0 : evloop(senv)
              = conceal( pool )
            val senv = $UNSAFE.castvwtp1{sockenv(senv)}(p)
            val () = ( 
              ifcase
              | status lhas POLLHUP => 
                    evloop_hup<env><senv>(pool0, env, senv )
              | status lhas POLLERR =>
                    evloop_error<env><senv>(pool0, env, senv )
              | status lhas POLLNVAL =>
                    evloop_error<env><senv>(pool0, env, senv )
              | _ => evloop_process<senv>(pool0, status, senv )
             ) 

             prval () = $UNSAFE.cast2void( senv )
             val () = ptr_set<evloop_impl(senv)>( view@pool | addr@pool,  reveal(pool0) )
           in  
              loop_evts{n,m-1}(pool, nfds - 1, env) where {
                prval () = __assert( pool ) where {
                  extern prfn __assert{o:int}( !evloop_impl(senv,o) ) : [o == n] void 
                }
              };
          end 
      else ()
 
      and loop_poll(
        pool0 : &evloop(senv)
      , env  : &env >> _
      ) : void = 
        let
          val () = evloop_clear_disposed<senv>( pool0 )

          var pool : evloop_impl(senv)
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


implement (env:vt@ype+)
evloop_process<env>( pool, evts, env ) 
  = let
      val evt : sockevt = ( 
         ifcase
          | (evts lhas POLLIN) && (evts lhas POLLOUT) => EvtRW() 
          | evts lhas POLLIN => EvtR()
          | evts lhas POLLOUT => EvtW()
          | _ => EvtOther()  
      )
      val () = evloop$process<env>( pool, evt, env )
    in end

implement {a}
sockenv_create( cfd, env ) = 
  CLIENT(cfd,@{
    polling_state = NotPolled()
  , socket_index = i2sz(0)
  }, env)

implement {a}
sockenv_decompose( senv ) =
  case+ senv of
  | ~CLIENT(sock,info,env) => @(sock,env) 

implement {}
evloop_events_add{a}( pool0, evt, env ) 
   = let
        extern praxi to_opt{b:bool}{a:vt@ype+}( !sockenv(a) >> opt(sockenv(a),b) ) : void
        extern castfn to_opt0{a:vt@ype+}( !sockenv(a) >> opt(sockenv(a),false) ) : sockenv(a)
        val @CLIENT(sock,info,_) = env

      in if sockfd_set_nonblocking( sock ) &&
            sockfd_set_cloexec( sock )
         then 
          let
              (** Politicking with dependent types **)
              fn 
                evloop_add{senv:vt@ype+}{n:pos}{fd:int}{st:status}
                ( pool: &evloop_impl(senv,n)
                , evts: evloop_event
                , senv: !sockenv(senv) >> opt(sockenv(senv),~b) 
               ) : #[b:bool] bool b
                =  let
                      val nfds = pool.nfds
                      val maxconn = pool.maxconn
                    in if nfds < maxconn
                       then
                          let
                            val @CLIENT(sock,info,_) = senv
 
                            val () = arrayptr_set_at<pollfd>( 
                                  pool.fds
                                , nfds
                                , pollfd_init( sockfd_value(sock), $UNSAFE.cast{poll_events}(evts) ) 
                            )

                            val () = info.socket_index := nfds

                            prval () = fold@senv

                            val () = arrayptr_set_at<ptr>( pool.data, nfds, $UNSAFE.castvwtp1{ptr}(senv) )

                            val senv = to_opt0{senv}( senv )

                            val () = pool.clients := list_vt_cons( senv, pool.clients )

                            val () = pool.nfds := nfds + 1
                           in true 
                          end
                      else false where {
                          prval () = to_opt{true}( senv )  
                        }
                   end
 
              val ep : poll_status = (
                case- evt of 
                | EvtR() => (info.polling_state := PolledR(); POLLIN)
                | EvtW() => (info.polling_state := PolledW(); POLLOUT)
                | EvtRW() => (info.polling_state := PolledRW(); POLLIN lor POLLOUT)
              )
              prval () = fold@env
              var pool : [n:pos] evloop_impl(sockenv,n)
                = reveal( pool0 )
              val b = evloop_add( pool, ep, env )
              val () = pool0 := conceal( pool ) 
           in b
          end
         else false where {
                prval () = fold@env
                prval () = to_opt{true}( env )  
            }
      end 

implement {}
evloop_events_del{a}( pool0, env ) 
  = let
      val @CLIENT(_,info,_) = env

      var pool : evloop_impl(a)
        = reveal( pool0 )

      val ind = g1ofg0( info.socket_index )
      val maxconn = pool.maxconn
      val () = assert_errmsg( ind < maxconn
        , "[evloop_events_del] Invalid socket index" )

      val () = arrayptr_set_at<pollfd>( pool.fds, ind, pollfd_empty() )
      val () = pool.compress := true
      val () = pool0 := conceal( pool ) 

      val () = info.polling_state := NotPolled()
      prval () = fold@env
    in true
   end

implement {}
evloop_events_mod{a}( pool0, evts, env ) 
  = let
      val @CLIENT(sock,info,_) = env

      var pool :  evloop_impl(a)
        = reveal( pool0 )

      val ind = g1ofg0( info.socket_index )
      val maxconn = pool.maxconn

      val () = assert_errmsg( ind < maxconn
        , "[evloop_events_mod] Invalid socket index" )

      val ep : poll_status = (
        case- evts of 
        | EvtR() => (info.polling_state := PolledR(); POLLIN)
        | EvtW() => (info.polling_state := PolledW(); POLLOUT)
        | EvtRW() => (info.polling_state := PolledRW(); POLLIN lor POLLOUT)
      )

      val () = arrayptr_set_at<pollfd>( 
              pool.fds
            , ind
            , pollfd_init( sockfd_value(sock), $UNSAFE.cast{poll_events}(ep) ) 
        )
      val () = arrayptr_set_at<ptr>( pool.data, ind, $UNSAFE.castvwtp1{ptr}(env) )
      
      val () = pool0 := conceal( pool ) 

      val () = info.polling_state := NotPolled()
      prval () = fold@env
    in true
   end

implement {}
evloop_events_dispose( pool, env ) 
  = let
      val b = evloop_events_del( pool, env )

      val @CLIENT(_,info,_) = env

      val () = if b then {
            val () = info.polling_state := Disposed()
        }
      prval () = fold@env
    in b
    end





