
#include "share/atspre_staload.hats"

staload "libats/libc/SATS/sys/socket.sats"
staload "libats/libc/SATS/netinet/in.sats"
staload "libats/libc/SATS/unistd.sats"
staload "libats/libc/SATS/stdio.sats"
staload "libats/libc/SATS/errno.sats"

staload "./../SATS/sockfd.sats"
staload "./../SATS/kqueue.sats"
staload "./../SATS/evloop.sats"

infixl lhas

vtypedef kqueue_client_info = @{
    polling_state = sock_polling_state
  }

absimpl sockenv_evloop_data = kqueue_client_info

absimpl
evloop(a) = @{
   kfd = kqueuefd
 , maxevents = sizeGt(0)
 , clients   = List0_vt(sockenv(a)) 
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
      }
  
implement {a}
evloop_close_exn( pool ) =
  let
    val () =
      ( kqueuefd_close_exn( pool.kfd ); 
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
      fun loop_evts
        {n,m:nat | m <= n}
      (
        pool : &evloop(senv)
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
            
            var senv0 = 
              $UNSAFE.castvwtp1{sockenv(senv)}( evt.udata )

            val () =
              ifcase
               | flags2status(flags) lhas EV_EOF => { 
                    val () =  evloop_hup<env><senv>(pool,  env, senv0 )
                    prval () = $UNSAFE.cast2void(senv0)
                  }
               | flags2status(flags) lhas EV_ERROR => { 
                    val () = evloop_error<env><senv>(pool, env, senv0 )
                    prval () = $UNSAFE.cast2void(senv0)
                  }
               | _ => {
                  val () = evloop_process<senv>(pool, $UNSAFE.cast{evloop_event}(flags), senv0 ) 
                  prval () = $UNSAFE.cast2void(senv0)
                }

             in loop_evts(pool,ebuf,nevts-1,env)
            end
          else ()
 
      and loop_kqueue{n,m:nat | m <= n}(
        pool : &evloop(senv)
      , ebuf : &(@[kevent][n])
      , ebsz : size_t m
      , env  : &env >> _
      ) : void = 
        let
          val () = evloop_clear_disposed<senv>(pool)
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
  CLIENT(cfd,@{
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
          | (evts lhas EVFILT_READ) && (evts lhas EVFILT_WRITE) => EvtRW() 
          | evts lhas EVFILT_READ => EvtR()
          | evts lhas EVFILT_WRITE => EvtW()
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
        val @CLIENT(sock,info,_) = env

      in if sockfd_set_nonblocking( sock ) &&
            sockfd_set_cloexec( sock )
         then
          let 
            val ep : evfilt = (
              case- evt of 
              | EvtR() => EVFILT_READ
              | EvtW() => EVFILT_WRITE
              | EvtRW() => EVFILT_READ lor EVFILT_WRITE
            )
            val b = loop(pool, sock, ep, $UNSAFE.castvwtp1{ptr}(env)) where {
              (** ignore EINTR **) 
              fun loop{fd:int}{st:status} 
              ( pool: &evloop, cfd: !sockfd(fd,st), evts : evfilt,  senv : ptr )
              : bool =
                 let
                    var empt = kevent_empty()
                    val () = EV_SET(empt, cfd, evts, EV_ADD, kevent_fflag_empty, kevent_data_empty, senv )
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
      ( pool: &evloop(a), evt : evfilt, action: kevent_action, cfd: !sockfd(fd,st), senv : ptr )
      : bool =
         let
            var empt = kevent_empty()
            val () = EV_SET(empt, cfd, evt , action, kevent_fflag_empty, kevent_data_empty, senv )
            val err =  kevent( pool.kfd, empt, 1, the_null_ptr, 0, the_null_ptr )
          in ifcase 
              | err = 0 => true
              | the_errno_test(EINTR) => loop( pool, evt, action, cfd, senv )
              | _ => false 
         end 

      val @CLIENT(sock,info,_) = env

      val b : bool = (
        case+ info.polling_state of
        | PolledR() => b where { 
             val b = loop( pool, EVFILT_READ, EV_DELETE, sock, the_null_ptr )
             val () = if b then info.polling_state := NotPolled()
          }
        | PolledW() => b where { 
            val b = loop( pool, EVFILT_WRITE, EV_DELETE, sock, the_null_ptr )
            val () = if b then info.polling_state := NotPolled()

          }
        | PolledRW() => b0 && b1 where {
             val b0 = loop( pool, EVFILT_READ, EV_DELETE, sock, the_null_ptr )
             val b1 = loop( pool, EVFILT_WRITE, EV_DELETE, sock, the_null_ptr )
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
             if loop( pool, EVFILT_READ, EV_ADD, sock, senv0 )
             then ( info.polling_state := PolledR(); true)
             else false
            ) 
          | EvtW() => (
             if loop( pool, EVFILT_WRITE, EV_ADD, sock, senv0 )
             then ( info.polling_state := PolledW(); true)
             else false
            ) 
          | EvtRW() => (
             if b0 && b1
             then ( info.polling_state := PolledRW(); true)
             else false
           ) where {
             val b0 = loop( pool, EVFILT_READ, EV_ADD, sock, senv0 )
             val b1 = loop( pool, EVFILT_WRITE, EV_ADD, sock, senv0 )
             val () = (
                ifcase 
                 | b0 && b1 => info.polling_state := PolledRW() 
                 | b0 && ~b1 => info.polling_state := PolledR()
                 | ~b0 && b1 => info.polling_state := PolledW()
                 | _ => info.polling_state := NotPolled()
              )
            } 
          | _ => false 
        ) where {
          val senv0 = $UNSAFE.castvwtp1{ptr}(env)
        } else false
      ) 
      prval () = fold@env
    in b
    end
 
implement {}
evloop_events_del( pool, env ) 
  = let
      (** ignore EINTR **) 
      fun loop{fd:int}{st:status}{a:vt@ype+} 
      ( pool: &evloop(a), evt : evfilt, action: kevent_action, cfd: !sockfd(fd,st) )
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

      val @CLIENT(sock,info,_) = env

      val b : bool = (
        case+ info.polling_state of
        | PolledR() => 
             loop( pool, EVFILT_READ, EV_DELETE, sock )
        | PolledW() =>  
             loop( pool, EVFILT_WRITE, EV_DELETE, sock )
        | PolledRW() => b0 && b1 where {
             val b0 = loop( pool, EVFILT_READ, EV_DELETE, sock )
             val b1 = loop( pool, EVFILT_WRITE, EV_DELETE, sock )
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

      val @CLIENT(_,info,_) = env

      val () = if b then {
            val () = info.polling_state := Disposed()
        }
      prval () = fold@env
    in b
    end
