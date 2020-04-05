
#include "share/atspre_staload.hats"

staload "libats/libc/SATS/sys/socket.sats"
staload "libats/libc/SATS/netinet/in.sats"
staload "libats/libc/SATS/unistd.sats"
staload "libats/libc/SATS/stdio.sats"
staload "libats/libc/SATS/errno.sats"

staload "./../SATS/socketfd.sats"
staload "./../SATS/epoll.sats"
staload "./../SATS/evloop.sats"

(** FIXME: Replace assertloc with proper exceptions **)
(** FIXME: Make threading optional **)
(** FIXME: Make sure env is handled safely when threading is enabled **)

vtypedef epoll_client_info = @{
    sock = socketfd0
  , polling_state = sock_polling_state
  }

datavtype epoll_client(env:vt@ype+) =
  | CLIENT of (epoll_client_info, env)

absimpl sockenv(a) = epoll_client(a)

vtypedef pool_impl(a:vt@ype+) = @{
     efd = epollfd
   , maxevents = sizeGt(0)
   , clients   = List0_vt(epoll_client(a)) 
  }

(** This was causing problems **)
local
absimpl
evloop(a) = pool_impl(a)
in end

absimpl
evloop_params = @{
    maxevents = sizeGt(0)
  }

absimpl
evloop_event = epoll_event_kind

implement {a}
evloop_create( pool, params ) =
  let 
      val (pep | efd) = epoll_create1(EPOLL_CLOEXEC) 
    in if efd > 0
       then
          let
              prval Some_v(pep) =  pep
              val efd = epollfd_encode( pep | efd )

              var pool0 : pool_impl(a) = (@{
                    efd = efd
                  , maxevents = params.maxevents
                  , clients   = list_vt_nil()
                } : pool_impl(a))

              (** Here, just casting to the actual implementation **)
              val () =
                pool := $UNSAFE.castvwtp0{evloop(a)}(pool0) 
              prval () = opt_some(pool) 
           in true
          end
       else 
          let
              prval None_v() =  pep
              prval () = opt_none(pool)
           in false 
          end
   end

(** Now, reimplement **)
absreimpl evloop

fun {sockenv:vt@ype+} 
  evloop_clear_disposed
  ( pool: &evloop(sockenv) )
  : void = pool.clients := list_vt_filterlin<epoll_client(sockenv)>(  pool.clients )
      where {
          implement list_vt_filterlin$clear<epoll_client(sockenv)>( x ) 
            = {
              val ~CLIENT(info,env) = x
              val () = 
                $effmask_all( 
                     socketfd_close_exn(info.sock);
                     sockenv$free<sockenv>( env ) 
                  ) 
            } 
          implement list_vt_filterlin$pred<epoll_client(sockenv)>( x ) = ( 
             case+ info.polling_state of
              | Disposed() => false
              | _ => true
              ) where {
                val CLIENT(info,_) = x
              }
      }
  
implement {a}
evloop_close_exn( pool ) =
  let
    val () =
      ( epollfd_close_exn( pool.efd ); 
       list_vt_freelin<epoll_client(a)>( pool.clients ) where {
          implement (a:vt@ype+) 
            list_vt_freelin$clear<epoll_client(a)>( x ) 
            = $effmask_all( 
                socketfd_close_exn(info.sock); 
                sockenv$free<a>( env ) 
              ) where {
                val ~CLIENT(info,env) = x
              }
        } 
      )
  in 
  end


implement {env}{senv}
evloop_hup( pool, env, senv ) = (
  assert_errmsg( evloop_events_dispose( pool, senv )
    , "[evloop_hup] Could not dispose of socket");
  println!("HUP");
)

implement {env}{senv}
evloop_error( pool, env, senv ) = (
    assert_errmsg( evloop_events_dispose( pool, senv )
     , "[evloop_error] Could not dispose of socket");
    println!("ERR");
  )

implement  {env}{sockenv}
evloop_run( pool, env )  
  = let
      fun loop_evts
        {n,m:nat | m <= n}
      (
        pool : &evloop(sockenv)
      , ebuf : &(@[epoll_event][n])
      , nevts : size_t m
      , env  : &env >> _
      ) : void =  
        if nevts > 0
        then
          let
            val evt = ebuf[ nevts-1 ] 
            val events = evt.events
            
            var senv = 
              $UNSAFE.castvwtp1{epoll_client(sockenv)}( evt.data.ptr )

            val () =
              ifcase
               | eek_has(events, EPOLLHUP ) => { 
                    val () =  evloop_hup<env><sockenv>(pool, env, senv )
                    prval () = $UNSAFE.cast2void(senv)
                  }
               | eek_has(events, EPOLLERR ) => { 
                  val () = evloop_error<env><sockenv>(pool, env, senv )
                  prval () = $UNSAFE.cast2void(senv)
                } 
               | _ => {
                   val () = evloop_process<sockenv>(pool, events, senv ) 
                   prval () = $UNSAFE.cast2void(senv)
                }

             in loop_evts(pool,ebuf,nevts-1,env)
            end
          else ()
 
      and loop_epoll{n,m:nat | m <= n}(
        pool : &evloop(sockenv)
      , ebuf : &(@[epoll_event][n])
      , ebsz : size_t m
      , env  : &env >> _
      ) : void = 
        let
          val () = evloop_clear_disposed<sockenv>( pool )
          val n = epoll_wait(pool.efd, ebuf, sz2i(ebsz), ~1)
         
          val () = (
                  if n >= 0 then loop_evts(pool,ebuf,i2sz(n),env) 
                  else if ~the_errno_test(EINTR) && ~the_errno_test(EAGAIN) 
                       then perror("epoll")
              ) 
          
        in loop_epoll( pool,ebuf,ebsz, env )
        end

    val maxevts = pool.maxevents 
    val ebuf = arrayptr_make_elt<epoll_event>( maxevts, epoll_event_empty())
    val (pf | par ) = arrayptr_takeout_viewptr( ebuf )

  in
    loop_epoll( pool, !par, maxevts, env ); 
    free(ebuf)
        where { prval () = arrayptr_addback( pf | ebuf ) };
  end 



implement {a}
sockenv_create( cfd, env ) = 
  CLIENT(@{
    sock = cfd
  , polling_state = NotPolled()
  }, env)

implement {a}
sockenv_decompose( senv ) =
  case+ senv of
  | ~CLIENT(info,env) => @(info.sock,env) 

implement (env:vt@ype+)
evloop_process<env>( pool, evts, env ) 
  = let
      val evt : sockevt = ( 
         ifcase
          | eek_has(evts,EPOLLIN) && eek_has(evts,EPOLLOUT) => EvtRW() 
          | eek_has(evts,EPOLLIN) => EvtR()
          | eek_has(evts,EPOLLOUT) => EvtW()
          | _ => EvtOther()  
      )
      val () = evloop$process<env>( pool, evt, env )
    in end

fun {} polling_state_upd( ev: sockevt, ps: sock_polling_state ) : sock_polling_state 
  = case+ ev of
    | EvtR() => (
        case+ ps of
        | PolledW() => PolledRW()
        | NotPolled() => PolledR()
        | _ => ps
      ) 
    | EvtW() => (
        case+ ps of
        | PolledR() => PolledRW()
        | NotPolled() => PolledW()
        | _ => ps
      ) 
    | EvtRW() => (
        case+ ps of
        | PolledR() => PolledRW()
        | PolledW() => PolledRW()
        | NotPolled() => PolledRW()
        | _ => ps
      )
    | _ => ps 
   

macdef epoll_no_evt  = $extval(epoll_event_kind,"0")

implement {}
evloop_events_mod( pool, evt, env ) 
  = let
      val @CLIENT(info,_) = env
      val ep : epoll_event_kind = (
        case- evt of 
        | EvtR() => EPOLLIN
        | EvtW() => EPOLLOUT
        | EvtRW() => EPOLLIN lor EPOLLOUT
      )
      val b = loop(pool, info.sock, ep, $UNSAFE.castvwtp1{ptr}(env)) where {
        (** ignore EINTR **) 
        fun loop{fd:int}{st:status} 
        ( pool: &evloop, cfd: !socketfd(fd,st), evts : epoll_event_kind,  senv : ptr )
        : bool =
           let
              var evt = epoll_event_empty()
              val () = evt.data.ptr := senv
              val () = evt.events := evts
              val err =  epoll_ctl( pool.efd, EPOLL_CTL_MOD, cfd, evt )
            in ifcase 
                | err = 0 => true
                | the_errno_test(EINTR)  => loop( pool, cfd, evts, senv )
                | _ => false 
           end
      }
      val () = if b then {
            val ps = info.polling_state
            val () = info.polling_state := polling_state_upd(evt,ps)
        }
      prval () = fold@env
    in b
    end

implement {}
evloop_events_add{a}( pool, evt, env ) 
  = let
       extern praxi to_opt{b:bool}{a:vt@ype+}( !sockenv(a) >> opt(sockenv(a),b) ) : void
       extern castfn to_opt0{a:vt@ype+}( !sockenv(a) >> opt(sockenv(a),false) ) : sockenv(a)
       val @CLIENT(info,_) = env
     in if socketfd_set_nonblocking( info.sock ) &&
           socketfd_set_cloexec( info.sock )
        then
          let
            val ep : epoll_event_kind = (
              case- evt of 
              | EvtR() => EPOLLIN
              | EvtW() => EPOLLOUT
              | EvtRW() => EPOLLIN lor EPOLLOUT
            )
            val b = loop(pool, info.sock, ep, $UNSAFE.castvwtp1{ptr}(env)) where {
              (** ignore EINTR **) 
              fun loop{fd:int}{st:status} 
              ( pool: &evloop, cfd: !socketfd(fd,st), evts : epoll_event_kind,  senv : ptr )
              : bool =
                 let
                    var evt = epoll_event_empty()
                    val () = evt.data.ptr := senv
                    val () = evt.events := evts
                    val err =  epoll_ctl( pool.efd, EPOLL_CTL_ADD, cfd, evt )
                  in ifcase 
                      | err = 0 => true
                      | the_errno_test(EINTR)  => loop( pool, cfd, evts, senv )
                      | _ => false 
                 end
            }
            val () = if b then {
                  val ps = info.polling_state
                  val () = info.polling_state := polling_state_upd(evt,ps)
              }
            prval () = fold@env

          in if b
             then true where {
                val env = to_opt0{a}( env )
                val () = pool.clients := list_vt_cons(env,pool.clients)
               
              }
             else false where {
                prval () = to_opt{true}( env )  
              }
          end
      else false where {
            prval () = fold@env
            prval () = to_opt{true}( env )  
        }
  end

implement {}
evloop_events_del( pool, env ) 
  = let
      val @CLIENT(info,_) = env
      
      val b = loop( pool, info.sock ) where {
        (** ignore EINTR **) 
        fun loop{fd:int}{st:status} 
        ( pool: &evloop, cfd: !socketfd(fd,st) )
        : bool =
           let
              var evt = epoll_event_empty()
              val err =  epoll_ctl( pool.efd, EPOLL_CTL_DEL, cfd, evt )
            in ifcase 
                | err = 0 => true
                | the_errno_test(EINTR)  => loop( pool, cfd )
                | _ => false 
           end
      }
      val () = if b then {
            val () = info.polling_state := NotPolled()
        }
      prval () = fold@env
    in b
    end

implement {}
evloop_events_dispose( pool, env ) 
  = let
      val b = evloop_events_del( pool, env )

      val @CLIENT(info,_) = env

      val () = if b then {
            val () = info.polling_state := Disposed()
        }
      prval () = fold@env
    in b
    end
