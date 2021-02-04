
#include "share/atspre_staload.hats"

staload "libats/libc/SATS/sys/socket.sats"
staload "libats/libc/SATS/netinet/in.sats"
staload "libats/libc/SATS/unistd.sats"
staload "libats/libc/SATS/stdio.sats"
staload "libats/libc/SATS/errno.sats"

staload "./../SATS/sockfd.sats"
staload "./../SATS/epoll.sats"
staload "./../SATS/evloop.sats"

infixl lhas

vtypedef epoll_client_info = @{
    polling_state = sock_polling_state
  }

absimpl sockenv_evloop_data = epoll_client_info

vtypedef pool_impl(a:vt@ype+) = @{
     efd = epollfd
   , maxevents = sizeGt(0)
   , clients   = List0_vt(sockenv(a)) 
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

fun {senv:vt@ype+} 
  evloop_clear_disposed
  ( pool: &evloop(senv) )
  : void = pool.clients := list_vt_filterlin<sockenv(senv)>(  pool.clients )
      where {
          implement list_vt_filterlin$clear<sockenv(senv)>( x ) 
            = {
              val ~CLIENT(sock,info,env) = x
              val () = 
                $effmask_all( 
                     sockfd_close_ign(sock);
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
      }
  
implement {a}
evloop_close_exn( pool ) =
  let
    val () =
      ( epollfd_close_exn( pool.efd ); 
       list_vt_freelin<sockenv(a)>( pool.clients ) where {
          implement (a:vt@ype+) 
            list_vt_freelin$clear<sockenv(a)>( x ) 
            = $effmask_all( 
                sockfd_close_ign(sock); 
                sockenv$free<a>( env ) 
              ) where {
                val ~CLIENT(sock,info,env) = x
              }
        } 
      )
  in 
  end


implement {env}{senv}
evloop_hup( pool, env, senv ) = {
  val _ = evloop_events_dispose( pool, senv )
  (** Log if this fails? **)
}

implement {env}{senv}
evloop_error( pool, env, senv ) = {
  val _ =  evloop_events_dispose( pool, senv )
  (** Log if this fails? **)
}

implement  {env}{senv}
evloop_run( pool, env )  
  = let
      fun loop_evts
        {n,m:nat | m <= n}
      (
        pool : &evloop(senv)
      , ebuf : &(@[epoll_event][n])
      , nevts : size_t m
      , env  : &env >> _
      ) : void =  
        if nevts > 0
        then
          let
            val evt = ebuf[ nevts-1 ] 
            val events = evt.events
            
            var senv0 = 
              $UNSAFE.castvwtp1{sockenv(senv)}( evt.data.ptr )

            val () =
              ifcase
               | events lhas EPOLLHUP => { 
                    val () =  evloop_hup<env><senv>(pool, env, senv0 )
                    prval () = $UNSAFE.cast2void(senv0)
                  }
               | events lhas EPOLLERR => { 
                  val () = evloop_error<env><senv>(pool, env, senv0 )
                  prval () = $UNSAFE.cast2void(senv0)
                } 
               | _ => {
                   val () = evloop_process<senv>(pool, events, senv0 ) 
                   prval () = $UNSAFE.cast2void(senv0)
                }

             in loop_evts(pool,ebuf,nevts-1,env)
            end
          else ()
 
      and loop_epoll{n,m:nat | m <= n}(
        pool : &evloop(senv)
      , ebuf : &(@[epoll_event][n])
      , ebsz : size_t m
      , env  : &env >> _
      ) : void = 
        let
          val () = evloop_clear_disposed<senv>( pool )
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
  CLIENT(cfd, @{
    polling_state = NotPolled()
  }, env)

implement {a}
sockenv_decompose( senv ) =
  case+ senv of
  | ~CLIENT(sock,info,env) => @(sock,env) 

implement (env:vt@ype+)
evloop_process<env>( pool, evts, env ) 
  = let
      val evt : sockevt = ( 
         ifcase
          | (evts lhas EPOLLIN) && (evts lhas EPOLLOUT) => EvtRW() 
          | evts lhas EPOLLIN => EvtR()
          | evts lhas EPOLLOUT => EvtW()
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
      val @CLIENT(sock,info,_) = env
      val ep : epoll_event_kind = (
        case- evt of 
        | EvtR() => EPOLLIN
        | EvtW() => EPOLLOUT
        | EvtRW() => EPOLLIN lor EPOLLOUT
      )
      val b = loop(pool, sock, ep, $UNSAFE.castvwtp1{ptr}(env)) where {
        (** ignore EINTR **) 
        fun loop{fd:int}{st:status} 
        ( pool: &evloop, cfd: !sockfd(fd,st), evts : epoll_event_kind,  senv : ptr )
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
       val @CLIENT(sock, info,_) = env
     in if sockfd_set_nonblocking( sock ) &&
           sockfd_set_cloexec( sock )
        then
          let
            val ep : epoll_event_kind = (
              case- evt of 
              | EvtR() => EPOLLIN
              | EvtW() => EPOLLOUT
              | EvtRW() => EPOLLIN lor EPOLLOUT
            )
            val b = loop(pool, sock, ep, $UNSAFE.castvwtp1{ptr}(env)) where {
              (** ignore EINTR **) 
              fun loop{fd:int}{st:status} 
              ( pool: &evloop, cfd: !sockfd(fd,st), evts : epoll_event_kind,  senv : ptr )
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
      val @CLIENT(sock,info,_) = env
      
      val b = loop( pool, sock ) where {
        (** ignore EINTR **) 
        fun loop{fd:int}{st:status} 
        ( pool: &evloop, cfd: !sockfd(fd,st) )
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

      val @CLIENT(_,info,_) = env

      val () = if b then {
            val () = info.polling_state := Disposed()
        }
      prval () = fold@env
    in b
    end
