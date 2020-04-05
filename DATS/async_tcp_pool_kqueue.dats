
#include "share/atspre_staload.hats"

staload "libats/libc/SATS/sys/socket.sats"
staload "libats/libc/SATS/netinet/in.sats"
staload "libats/libc/SATS/unistd.sats"
staload "libats/libc/SATS/stdio.sats"
staload "libats/libc/SATS/errno.sats"

staload "./../SATS/socketfd.sats"
staload "./../SATS/kqueue.sats"
staload "./../SATS/async_tcp_pool.sats"

(** FIXME: Replace assertloc with proper exceptions **)
(** FIXME: Make threading optional **)
(** FIXME: Make sure env is handled safely when threading is enabled **)

absimpl
async_tcp_pool(a) = @{
   kfd = kqueuefd
 , maxevents = sizeGt(0)
 , clients   = List0_vt(a) 
}

absimpl
async_tcp_params = @{
    maxevents = sizeGt(0)
  }

absimpl
async_tcp_event = evfilt

implement {a}
async_tcp_pool_create( pool, params ) =
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
      ( kqueuefd_close_exn( pool.kfd ); 
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
              var empt = kevent_empty()
              val () = EV_SET(empt, cfd, evts, EV_ADD, kevent_fflag_empty, kevent_data_empty, p  )
              val err =  kevent( pool.kfd, empt, 1, the_null_ptr, 0, the_null_ptr )
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
          var empt = kevent_empty()
          val () = EV_SET(empt, cfd, EVFILT_READ lor EVFILT_WRITE , EV_DELETE, kevent_fflag_empty, kevent_data_empty, the_null_ptr  )
          val err =  kevent( pool.kfd, empt, 1, the_null_ptr, 0, the_null_ptr )
        in ifcase 
            | err = 0 => true
            | the_errno_test(EINTR) => loop( pool, cfd )
            | _ => false 
       end 
  in loop( pool, cfd)
  end

(** FIXME: this works, but is ugly **)
implement {}
async_tcp_pool_mod{sockenv}{fd}( pool, cfd, evts, senv ) =
(*  if async_tcp_pool_del( pool, cfd )
  then*) ( 
       if async_tcp_pool_add( pool, cfd, evts, senv )
       then true where {
            prval () = opt_unnone( senv )
          }
       else false where {
            prval () = opt_unsome( senv )
            prval () = $UNSAFE.cast2void( senv )
          }
    ) where {
      var senv = $UNSAFE.castvwtp1{sockenv}(senv)
    }
  //else false

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
async_tcp_pool_hup( pool, env, senv )  = (
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
              $UNSAFE.castvwtp1{sockenv}( evt.udata )

            val () =
              ifcase
               | kevent_status_has(flags2status(flags), EV_EOF ) => { 
                    val () =  async_tcp_pool_hup<env><sockenv>(pool,  env, senv )
                    prval () = $UNSAFE.cast2void(senv)
                  }
               | kevent_status_has(flags2status(flags), EV_ERROR ) => { 
                    val () = async_tcp_pool_error<env><sockenv>(pool, env, senv )
                    prval () = $UNSAFE.cast2void(senv)
                  }
               | _ => {
                  val () = async_tcp_pool_process<sockenv>(pool, $UNSAFE.cast{async_tcp_event}(flags), senv ) 
                  prval () = $UNSAFE.cast2void(senv)
                }

             in loop_evts(pool,ebuf,nevts-1,env)
            end
          else ()
 
      and loop_kqueue{n,m:nat | m <= n}(
        pool : &async_tcp_pool(sockenv)
      , ebuf : &(@[kevent][n])
      , ebsz : size_t m
      , env  : &env >> _
      ) : void = 
        let
          val () = async_tcp_pool_clear_disposed<sockenv>(pool)
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

vtypedef kqueue_client_info = @{
    sock = socketfd0
  , polling_state = sock_polling_state
  }

datavtype kqueue_client(env:vt@ype+) =
  | CLIENT of (kqueue_client_info, env)

absimpl sockenv(a) = kqueue_client(a)

implement (env:vt@ype+)
async_tcp_pool_process<kqueue_client(env)>( pool, evts, env ) 
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

implement {}
evloop_events_mod( pool, evt, env ) 
  = let
      (** ignore EINTR **) 
      fun loop{fd:int}{st:status}{a:vtype} 
      ( pool: &async_tcp_pool(a), evt : evfilt, action: kevent_action, cfd: !socketfd(fd,st) )
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
      fun loop{fd:int}{st:status}{a:vtype} 
      ( pool: &async_tcp_pool(a), evt : evfilt, action: kevent_action, cfd: !socketfd(fd,st) )
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
