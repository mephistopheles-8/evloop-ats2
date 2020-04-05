
#include "share/atspre_staload.hats"

staload "libats/libc/SATS/sys/socket.sats"
staload "libats/libc/SATS/netinet/in.sats"
staload "libats/libc/SATS/unistd.sats"
staload "libats/libc/SATS/stdio.sats"
staload "libats/libc/SATS/errno.sats"

staload "./../SATS/socketfd.sats"
staload "./../SATS/kqueue.sats"
staload "./../SATS/evloop.sats"

(** FIXME: Replace assertloc with proper exceptions **)
(** FIXME: Make threading optional **)
(** FIXME: Make sure env is handled safely when threading is enabled **)

vtypedef kqueue_client_info = @{
    sock = socketfd0
  , polling_state = sock_polling_state
  }

datavtype kqueue_client(env:vt@ype+) =
  | CLIENT of (kqueue_client_info, env)

absimpl sockenv(a) = kqueue_client(a)

absimpl
evloop(a) = @{
   kfd = kqueuefd
 , maxevents = sizeGt(0)
 , clients   = List0_vt(kqueue_client(a)) 
}

absimpl
evloop_params = @{
    maxevents = sizeGt(0)
  }

absimpl
evloop_event = evfilt

implement {a}
evloop_create( pool, params ) =
    let 
      val (pep | kfd) = kqueue() 
    in if kfd > ~1
       then
          let
              prval Some_v(pep) =  pep
              val kfd = kqueuefd_encode( pep | kfd )
              val () = ptr_set(view@pool | addr@pool, @{    
                    kfd = kfd
                  , maxevents = params.maxevents
                  , clients = list_vt_nil()
                 })
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

fun {sockenv:vt@ype+} 
  evloop_clear_disposed
  ( pool: &evloop(sockenv) )
  : void = pool.clients := list_vt_filterlin<kqueue_client(sockenv)>(  pool.clients )
      where {
          implement list_vt_filterlin$clear<kqueue_client(sockenv)>( x ) 
            = {
              val ~CLIENT(info,env) = x
              val () = 
                $effmask_all( 
                     socketfd_close_exn(info.sock);
                     sockenv$free<sockenv>( env ) 
                  ) 
            } 
          implement list_vt_filterlin$pred<kqueue_client(sockenv)>( x ) = ( 
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
      ( kqueuefd_close_exn( pool.kfd ); 
       list_vt_freelin<kqueue_client(a)>( pool.clients ) where {
          implement (a:vt@ype+) 
            list_vt_freelin$clear<kqueue_client(a)>( x ) 
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
evloop_hup( pool, env, senv )  = (
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
      , ebuf : &(@[kevent][n])
      , nevts : size_t m
      , env  : &env >> _
      ) : void =  
        if nevts > 0
        then
          let
            val evt = ebuf[ nevts-1 ] 
            val fd = $UNSAFE.cast{int}(evt.ident)
            val flags = evt.flags
            
            var senv = 
              $UNSAFE.castvwtp1{kqueue_client(sockenv)}( evt.udata )

            val () =
              ifcase
               | kevent_status_has(flags2status(flags), EV_EOF ) => { 
                    val () =  evloop_hup<env><sockenv>(pool,  env, senv )
                    prval () = $UNSAFE.cast2void(senv)
                  }
               | kevent_status_has(flags2status(flags), EV_ERROR ) => { 
                    val () = evloop_error<env><sockenv>(pool, env, senv )
                    prval () = $UNSAFE.cast2void(senv)
                  }
               | _ => {
                  val () = evloop_process<sockenv>(pool, $UNSAFE.cast{evloop_event}(flags), senv ) 
                  prval () = $UNSAFE.cast2void(senv)
                }

             in loop_evts(pool,ebuf,nevts-1,env)
            end
          else ()
 
      and loop_kqueue{n,m:nat | m <= n}(
        pool : &evloop(sockenv)
      , ebuf : &(@[kevent][n])
      , ebsz : size_t m
      , env  : &env >> _
      ) : void = 
        let
          val () = evloop_clear_disposed<sockenv>(pool)
          val n = kevent(pool.kfd, the_null_ptr, 0,ebuf, sz2i(ebsz), the_null_ptr)
          
          val () = (
                  if n >= 0 then loop_evts(pool,ebuf,i2sz(n),env) 
                  else if ~the_errno_test(EINTR) && ~the_errno_test(EAGAIN) 
                       then perror("kqueue")
              ) 
  
        in loop_kqueue( pool,ebuf,ebsz, env )
        end

      val maxevts = pool.maxevents 
      val ebuf = arrayptr_make_elt<kevent>( maxevts, kevent_empty())
      val (pf | par ) = arrayptr_takeout_viewptr( ebuf ) 
    in 
      loop_kqueue( pool, !par, maxevts, env );
      free( ebuf )  where { prval () = arrayptr_addback( pf | ebuf ) };
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
          | evfilt_has(evts,EVFILT_READ) && evfilt_has(evts,EVFILT_WRITE) => EvtRW() 
          | evfilt_has(evts,EVFILT_READ) => EvtR()
          | evfilt_has(evts,EVFILT_WRITE) => EvtW()
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

(** TODO: see if we need to add RW flags seperately **)
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
            val ep : evfilt = (
              case- evt of 
              | EvtR() => EVFILT_READ
              | EvtW() => EVFILT_WRITE
              | EvtRW() => EVFILT_READ lor EVFILT_WRITE
            )
            val b = loop(pool, info.sock, ep, $UNSAFE.castvwtp1{ptr}(env)) where {
              (** ignore EINTR **) 
              fun loop{fd:int}{st:status} 
              ( pool: &evloop, cfd: !socketfd(fd,st), evts : evfilt,  senv : ptr )
              : bool =
                 let
                    var empt = kevent_empty()
                    val () = EV_SET(empt, cfd, evts, EV_ADD, kevent_fflag_empty, kevent_data_empty, the_null_ptr  )
                    val err =  kevent( pool.kfd, empt, 1, the_null_ptr, 0, the_null_ptr )
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
evloop_events_mod( pool, evt, env ) 
  = let
      (** ignore EINTR **) 
      fun loop{fd:int}{st:status}{a:vt@ype+} 
      ( pool: &evloop(a), evt : evfilt, action: kevent_action, cfd: !socketfd(fd,st) )
      : bool =
         let
            var empt = kevent_empty()
            val () = EV_SET(empt, cfd, evt , action, kevent_fflag_empty, kevent_data_empty, the_null_ptr  )
            val err =  kevent( pool.kfd, empt, 1, the_null_ptr, 0, the_null_ptr )
          in ifcase 
              | err = 0 => true
              | the_errno_test(EINTR) => loop( pool, evt, action, cfd )
              | _ => false 
         end 

      val @CLIENT(info,_) = env

      val b : bool = (
        case+ info.polling_state of
        | PolledR() => b where { 
             val b = loop( pool, EVFILT_READ, EV_DELETE, info.sock )
             val () = if b then info.polling_state := NotPolled()
          }
        | PolledW() => b where { 
            val b = loop( pool, EVFILT_WRITE, EV_DELETE, info.sock )
            val () = if b then info.polling_state := NotPolled()

          }
        | PolledRW() => b0 && b1 where {
             val b0 = loop( pool, EVFILT_READ, EV_DELETE, info.sock )
             val b1 = loop( pool, EVFILT_WRITE, EV_DELETE, info.sock )
             val () = (
                ifcase 
                 | b0 && b1 => info.polling_state := NotPolled() 
                 | b0 && ~b1 => info.polling_state := PolledW()
                 | ~b0 && b1 => info.polling_state := PolledR()
                 | _ => info.polling_state := PolledRW()
              )
          } 
        | NotPolled() => true
        | _ => false 
      ) : bool

      val b = (
        if b 
        then (
          case+ evt of
          | EvtR() => (
             if loop( pool, EVFILT_READ, EV_ADD, info.sock )
             then ( info.polling_state := PolledR(); true)
             else false
            ) 
          | EvtW() => (
             if loop( pool, EVFILT_WRITE, EV_ADD, info.sock )
             then ( info.polling_state := PolledW(); true)
             else false
            ) 
          | EvtRW() => (
             if b0 && b1
             then ( info.polling_state := PolledRW(); true)
             else false
           ) where {
             val b0 = loop( pool, EVFILT_READ, EV_ADD, info.sock )
             val b1 = loop( pool, EVFILT_WRITE, EV_ADD, info.sock )
             val () = (
                ifcase 
                 | b0 && b1 => info.polling_state := PolledRW() 
                 | b0 && ~b1 => info.polling_state := PolledR()
                 | ~b0 && b1 => info.polling_state := PolledW()
                 | _ => info.polling_state := NotPolled()
              )
            } 
          | _ => false 
        ) else false
      )
      prval () = fold@env
    in b
    end
 
implement {}
evloop_events_del( pool, env ) 
  = let
      (** ignore EINTR **) 
      fun loop{fd:int}{st:status}{a:vt@ype+} 
      ( pool: &evloop(a), evt : evfilt, action: kevent_action, cfd: !socketfd(fd,st) )
      : bool =
         let
            var empt = kevent_empty()
            val () = EV_SET(empt, cfd, evt , action, kevent_fflag_empty, kevent_data_empty, the_null_ptr  )
            val err =  kevent( pool.kfd, empt, 1, the_null_ptr, 0, the_null_ptr )
          in ifcase 
              | err = 0 => true
              | the_errno_test(EINTR) => loop( pool, evt, action, cfd )
              | _ => false 
         end 

      val @CLIENT(info,_) = env

      val b : bool = (
        case+ info.polling_state of
        | PolledR() => 
             loop( pool, EVFILT_READ, EV_DELETE, info.sock )
        | PolledW() =>  
             loop( pool, EVFILT_WRITE, EV_DELETE, info.sock )
        | PolledRW() => b0 && b1 where {
             val b0 = loop( pool, EVFILT_READ, EV_DELETE, info.sock )
             val b1 = loop( pool, EVFILT_WRITE, EV_DELETE, info.sock )
             val () = (
                ifcase 
                 | b0 && b1 => info.polling_state := NotPolled() 
                 | b0 && ~b1 => info.polling_state := PolledW()
                 | ~b0 && b1 => info.polling_state := PolledR()
                 | _ => info.polling_state := PolledRW()
              )
          } 
        | NotPolled() => true
        | _ => false 
      ) : bool
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
