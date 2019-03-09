
#include "share/atspre_staload.hats"

staload "libats/libc/SATS/sys/socket.sats"
staload "libats/libc/SATS/netinet/in.sats"
staload "libats/libc/SATS/unistd.sats"
staload "libats/SATS/athread.sats"
staload _ = "libats/DATS/athread.dats"
staload _ = "libats/DATS/athread_posix.dats"

staload "./../SATS/socketfd.sats"
staload "./../SATS/kqueue.sats"
staload "./../SATS/async_tcp_pool.sats"

(** FIXME: Replace assertloc with proper exceptions **)
(** FIXME: Make threading optional **)
(** FIXME: Make sure env is handled safely when threading is enabled **)

absimpl
async_tcp_pool = @{
   lfd = socketfd1(listen)
 , kfd = int
 , maxevents = sizeGt(0)
 , threads   = sizeGt(0) 
}

absimpl
async_tcp_params = @{
    port = int
  , address = in_addr_nbo_t
  , backlog = intGt(0)
  , maxevents = sizeGt(0)
  , threads   = sizeGt(0)
  , reuseaddr = bool 
  }

absimpl
async_tcp_event = kevent_action

  
implement {}
async_tcp_pool_create( pool, params ) =
  let
    var sp : socketfd_setup_params = @{
          af = AF_INET
        , st = SOCK_STREAM
        , nonblocking = true 
        , reuseaddr   = params.reuseaddr 
        , port = params.port
        , address = params.address
        , backlog = params.backlog
      }

    var sfd : socketfd0?
  
   in  if socketfd_setup( sfd, sp )
      then
          let 
            prval () = sockopt_unsome( sfd )
            val () =
              pool := (@{    
                  lfd = sfd
                , kfd = 0
                , maxevents = params.maxevents
                , threads   = params.threads
               })
            prval () = opt_some(pool) 
          in true 
         end
       else 
        let
            prval () = sockopt_unnone( sfd )
            prval () = opt_none(pool)
         in false 
        end
  end

implement {}
async_tcp_pool_close_exn( pool ) =
  let
    val () =
      (  socketfd_close_exn( pool.lfd );
      )
  in 
  end


implement {}
async_tcp_pool_add{fd}( pool, cfd, evts ) =
  if socketfd_set_nonblocking( cfd )
  then
  let
    val kfd = $UNSAFE.castvwtp1{kqueuefd}(pool.kfd)
    val (pf | err) = kqueuefd_add1( kfd, cfd, EVFILT_READ, evts  (*lor $UNSAFE.cast{kevent_action}(EV_DISPATCH) *) ) 
  in if err = 0
     then 
        let
          prval Some_v( pfadd ) = pf 
          prval () = kqueue_add_sfd_elim( pfadd , cfd )
          prval () = sockopt_none( cfd )
          prval ()= $UNSAFE.cast2void(kfd)
        in true
        end
      else
        let
          prval None_v( ) = pf 
          prval () = sockopt_some( cfd )
          prval ()= $UNSAFE.cast2void(kfd)
        in false
        end
  end 
  else false where {
    prval () = sockopt_some( cfd )
  }

 
implement {}
async_tcp_pool_del{fd}( pool, cfd ) =
  let
    var empt = kevent_empty()
    val kfd = $UNSAFE.castvwtp1{kqueuefd}(pool.kfd)
    val () = EV_SET(empt, cfd, EVFILT_READ, EV_DELETE, kevent_fflag_empty, kevent_data_empty, the_null_ptr  )
    val err =  kevent( kfd, empt, 1, the_null_ptr, 0, the_null_ptr )
  in if err = 0
     then (if socketfd_close( cfd ) 
          then true
          else false ) where { 
            prval ()= $UNSAFE.cast2void(kfd)
          }
     else
      let
        prval () = sockopt_some(cfd)
        prval ()= $UNSAFE.cast2void(kfd)
      in false
      end 
  end

implement {}
async_tcp_pool_add_exn{fd}( pool, cfd, evts ) =
  let
    var cfd = cfd
    val () = assertloc( async_tcp_pool_add<>(pool,cfd,evts) )
    prval () = sockopt_unnone(cfd) 
  in
  end

implement {}
async_tcp_pool_del_exn{fd}( pool, cfd ) =
  let
    var cfd = cfd
    val () = assertloc( async_tcp_pool_del<>(pool,cfd) )
    prval () = sockopt_unnone(cfd) 
  in
  end



implement {env}
async_tcp_pool_hup( pool, cfd, env ) =
  async_tcp_pool_del_exn<>( pool, cfd )
  (* socketfd_close_exn( cfd ) *)

implement {env}
async_tcp_pool_error( pool, cfd, env ) =
  ( if cfd = pool.lfd 
    then exit_errmsg_void(1, "Error on listening socket");
    socketfd_close_exn( cfd )
  )

implement {env}
async_tcp_pool_accept{fd}( pool, cfd, env ) =
  let
    var cfd = cfd
    val () = assertloc( async_tcp_pool_add<>{fd}(pool,cfd, EV_ADD ) )
    prval () = sockopt_unnone{conn}{fd}( cfd )
  in
  end


implement  {env}
async_tcp_pool_run( pool, env )  
  = let
      fun loop_evts
        {n,m:nat | m <= n}
      (
        pool : &async_tcp_pool
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
            
            macdef client_sock = 
              $UNSAFE.castvwtp1{socketfd1(conn)}( fd )

            val () =
              ifcase
               | kevent_status_has(flags2status(flags), EV_EOF ) => 
                    async_tcp_pool_error<env>(pool, client_sock, env ) 
               | kevent_status_has(flags2status(flags), EV_ERROR ) => 
                    async_tcp_pool_hup<env>(pool, client_sock, env )
               | pool.lfd = g1ofg0(fd) =>
                  {
                    vtypedef accept_state = @{
                       pool = async_tcp_pool
                     , env = env
                    }

                    val lfd = $UNSAFE.castvwtp1{socketfd1(listen)}(pool.lfd)

                    var accs = (@{
                        pool = pool
                      , env = env 
                      }: accept_state)

                    implement
                    socketfd_accept_all$withfd<accept_state>(cfd,accs) = 
                      async_tcp_pool_accept<env>(accs.pool, cfd, accs.env )

                    val ()   = socketfd_accept_all<accept_state>(lfd, accs)

                    val () = 
                      ( pool := accs.pool;
                        env := accs.env
                      )

                    prval () = $UNSAFE.cast2void(lfd)
                  }
               | _ => async_tcp_pool_process<env>(pool, $UNSAFE.cast{kevent_action}(flags), client_sock, env )  

             in loop_evts(pool,ebuf,nevts-1,env)
            end
          else ()
 
      and loop_kqueue{n,m:nat | m <= n}(
        pool : &async_tcp_pool
      , ebuf : &(@[kevent][n])
      , ebsz : size_t m
      , env  : &env >> _
      ) : void = 
        let

          val kfd = $UNSAFE.castvwtp1{kqueuefd}(pool.kfd)

          val n = kevent(kfd, the_null_ptr, 0,ebuf, sz2i(ebsz), the_null_ptr)
          
          val () = assertloc( n >= 0 )
          
          var i : [i:nat] int i
  
          val () = loop_evts(pool,ebuf,i2sz(n),env)
          prval () = $UNSAFE.cast2void(kfd)
          
        in loop_kqueue( pool,ebuf,ebsz, env )
        end

      fun spawn_threads{n:nat} .<n>. (
            pool: &async_tcp_pool
          , env: &env >> _ 
          , n_threads : size_t n
        ): void =
        if n_threads > 0
        then
          let
            (** This cast should be benign **)
            val p = $UNSAFE.castvwtp1{async_tcp_pool}(pool)

            (** FIXME: This cast is unsafe **)
            val e = $UNSAFE.castvwtp1{env}(env)

            val _ = athread_create_cloptr_exn<>(
              llam() => 
                let 
                  var rpool = p
                  val kfd = kqueue_exn()
                  val () = assertloc( kqueuefd_add0( kfd, rpool.lfd, EVFILT_READ, EV_ADD ) = 0 )
                  val () = rpool.kfd := $UNSAFE.castvwtp0{int}(kfd)
                  var renv = e   
                  val maxevts = rpool.maxevents 
                  val ebuf = arrayptr_make_elt<kevent>( maxevts, kevent_empty())
                  val (pf | par ) = arrayptr_takeout_viewptr( ebuf ) 
                in 
                  loop_kqueue( rpool, !par, maxevts, renv );
                  () where { prval () = arrayptr_addback( pf | ebuf ) };
                  free( ebuf );
                  () where { 
                       prval () = $UNSAFE.cast2void(rpool)
                       prval () = $UNSAFE.cast2void(renv)
                     };
                end
             );
          in  
            spawn_threads( pool, env, n_threads - 1)  
          end
        else ()
     
    in spawn_threads( pool, env, pool.threads);
      while (true) (ignoret(sleep(1000)));
    (*
      Either do pthread join or some sort of performance watchdog routine here...
    in 
      loop_kqueue( pool, env )
    *)
    end 

