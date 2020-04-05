
#include "share/atspre_staload.hats"

staload "libats/libc/SATS/sys/socket.sats"
staload "libats/libc/SATS/netinet/in.sats"
staload "libats/libc/SATS/unistd.sats"
staload "libats/libc/SATS/stdio.sats"
staload "libats/libc/SATS/errno.sats"

staload "./../SATS/socketfd.sats"
staload "./../SATS/epoll.sats"
staload "./../SATS/async_tcp_pool.sats"

(** FIXME: Replace assertloc with proper exceptions **)
(** FIXME: Make threading optional **)
(** FIXME: Make sure env is handled safely when threading is enabled **)

vtypedef pool_impl(a:vtype) = @{
     efd = epollfd
   , maxevents = sizeGt(0)
   , clients   = List0_vt(a) 
  }

(** This was causing problems **)
local
absimpl
async_tcp_pool(a) = pool_impl(a)
in end

absimpl
async_tcp_params = @{
    maxevents = sizeGt(0)
  }

absimpl
async_tcp_event = epoll_event_kind

implement {a}
async_tcp_pool_create( pool, params ) =
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
                pool := $UNSAFE.castvwtp0{async_tcp_pool(a)}(pool0) 
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
absreimpl async_tcp_pool

fun {sockenv:vtype} 
  async_tcp_pool_clear_disposed
  ( pool: &async_tcp_pool(sockenv) )
  : void = pool.clients := list_vt_filterlin<sockenv>(  pool.clients )
      where {
          implement list_vt_filterlin$clear<sockenv>( x ) 
            = $effmask_all( sockenv$free<sockenv>( x ) ) 
          implement list_vt_filterlin$pred<sockenv>( x ) 
            = $effmask_all( ~sockenv$isdisposed<sockenv>( x ) )
      }
  
implement {a}
async_tcp_pool_close_exn( pool ) =
  let
    val () =
      ( epollfd_close_exn( pool.efd ); 
       list_vt_freelin<a>( pool.clients ) where {
          implement list_vt_freelin$clear<a>( x ) 
            = $effmask_all( sockenv$free<a>( x ) )
        } 
      )
  in 
  end

implement {}
async_tcp_pool_add{socketenv}{fd}( pool, cfd, evts, senv ) =
  if socketfd_set_nonblocking( cfd ) &&
     socketfd_set_cloexec( cfd ) 
  then
    let
      (** Ignore EINTR **)
      fun loop{fd:int}{st:status}
        ( pool: &async_tcp_pool(socketenv)
        , cfd: !socketfd(fd,st)
        , evts: async_tcp_event
        , senv: &socketenv >> opt(socketenv,~b) 
      ): #[b:bool] bool b =
          let
              val p = $UNSAFE.castvwtp1{ptr}(senv)
              val err = epollfd_add0( pool.efd, cfd, evts, epoll_data_ptr(p) ) 
           in if err = 0
               then 
                  let
                    val () = pool.clients := list_vt_cons( senv, pool.clients )
                    prval () = opt_none( senv )
                  in true
                  end
                else
                  let
                  in if the_errno_test(EINTR) 
                     then loop( pool, cfd, evts, senv )
                     else false where {
                        prval () = opt_some( senv )
                      }
                  end
          end
     in loop(pool, cfd, evts, senv) 
    end 
  else false where {
    prval () = opt_some( senv )
  }

implement {}
async_tcp_pool_del{fd}( pool, cfd ) =
  let
    (** ignore EINTR **) 
    fun loop{fd:int}{st:status} 
    ( pool: &async_tcp_pool, cfd: !socketfd(fd,st) )
    : bool =
       let
          var empt = epoll_event_empty()
          val err =  epoll_ctl( pool.efd, EPOLL_CTL_DEL, cfd, empt )
        in ifcase 
            | err = 0 => true
            | the_errno_test(EINTR) => loop( pool, cfd )
            | _ => false 
       end 
  in loop( pool, cfd)
  end

implement {}
async_tcp_pool_mod{sockenv}{fd}( pool, cfd, evts, senv ) =
  let
    (** ignore EINTR **) 
    fun loop{fd:int}{st:status} 
    ( pool: &async_tcp_pool(sockenv), cfd: !socketfd(fd,st), evts :  async_tcp_event,  senv : !sockenv )
    : bool =
       let
          var evt = epoll_event_empty()
          val () = evt.data.ptr := $UNSAFE.castvwtp1{ptr}( senv )
          val () = evt.events := evts
          val err =  epoll_ctl( pool.efd, EPOLL_CTL_MOD, cfd, evt )
        in ifcase 
            | err = 0 => true
            | the_errno_test(EINTR)  => loop( pool, cfd, evts, senv )
            | _ => false 
       end 
  in loop( pool, cfd, evts, senv)
  end

implement {}
async_tcp_pool_add_exn{fd}( pool, cfd, evts, senv ) =
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
async_tcp_pool_mod_exn{fd}( pool, cfd, evts, senv ) =
  let
    val () = assertloc( async_tcp_pool_mod<>(pool,cfd,evts,senv) )
  in
  end

implement {env}{senv}
async_tcp_pool_hup( pool, env, senv ) = (
  sockenv$setdisposed<senv>(pool,senv);
  println!("HUP");
)

implement {env}{senv}
async_tcp_pool_error( pool, env, senv ) = (
    sockenv$setdisposed<senv>(pool,senv);
    println!("ERR");
  )

implement  {env}{sockenv}
async_tcp_pool_run( pool, env )  
  = let
      fun loop_evts
        {n,m:nat | m <= n}
      (
        pool : &async_tcp_pool(sockenv)
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
              $UNSAFE.castvwtp1{sockenv}( evt.data.ptr )

            val () =
              ifcase
               | eek_has(events, EPOLLHUP ) => { 
                    val () =  async_tcp_pool_hup<env><sockenv>(pool, env, senv )
                    prval () = $UNSAFE.cast2void(senv)
                  }
               | eek_has(events, EPOLLERR ) => { 
                  val () = async_tcp_pool_error<env><sockenv>(pool, env, senv )
                  prval () = $UNSAFE.cast2void(senv)
                } 
               | _ => {
                   val () = async_tcp_pool_process<sockenv>(pool, events, senv ) 
                   prval () = $UNSAFE.cast2void(senv)
                }

             in loop_evts(pool,ebuf,nevts-1,env)
            end
          else ()
 
      and loop_epoll{n,m:nat | m <= n}(
        pool : &async_tcp_pool(sockenv)
      , ebuf : &(@[epoll_event][n])
      , ebsz : size_t m
      , env  : &env >> _
      ) : void = 
        let
          val () = async_tcp_pool_clear_disposed<sockenv>( pool )
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


vtypedef epoll_client_info = @{
    sock = socketfd0
  , polling_state = sock_polling_state
  }

datavtype epoll_client(env:vt@ype+) =
  | CLIENT of (epoll_client_info, env)

absimpl sockenv(a) = epoll_client(a)

implement (env:vt@ype+)
async_tcp_pool_process<epoll_client(env)>( pool, evts, env ) 
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
        ( pool: &async_tcp_pool, cfd: !socketfd(fd,st), evts : epoll_event_kind,  senv : ptr )
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
evloop_events_add( pool, evt, env ) 
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
        ( pool: &async_tcp_pool, cfd: !socketfd(fd,st), evts : epoll_event_kind,  senv : ptr )
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

      extern praxi to_opt{b:bool}( !sockenv >> opt(sockenv,b) ) : void

    in if b
       then true where {
          prval () = to_opt{false}( env )  
        }
       else false where {
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
        ( pool: &async_tcp_pool, cfd: !socketfd(fd,st) )
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
