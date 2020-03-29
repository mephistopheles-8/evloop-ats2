
#include "share/atspre_staload.hats"

staload "libats/libc/SATS/sys/socket.sats"
staload "libats/libc/SATS/netinet/in.sats"
staload "libats/libc/SATS/unistd.sats"
staload "libats/libc/SATS/stdio.sats"
staload "libats/SATS/athread.sats"
staload _ = "libats/DATS/athread.dats"
staload _ = "libats/DATS/athread_posix.dats"

staload "./../SATS/socketfd.sats"
staload "./../SATS/epoll.sats"
staload "./../SATS/async_tcp_pool.sats"

(** FIXME: Replace assertloc with proper exceptions **)
(** FIXME: Make threading optional **)
(** FIXME: Make sure env is handled safely when threading is enabled **)

(** FIXME: This should only work in a single-threaded impl **)
absimpl
async_tcp_pool(a) = @{
//   lfd = socketfd1(listen)
   efd = epollfd
 , maxevents = sizeGt(0)
 , threads   = sizeGt(0)
(** FIXMME: Each thread needs a variant of this **)
 , clients   = List0_vt(a) 
}

absimpl
async_tcp_params = @{
    maxevents = sizeGt(0)
  , threads   = sizeGt(0)
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
              val () =
                pool := (@{    
                    efd = efd
                  , maxevents = params.maxevents
                  , threads   = params.threads
                  , clients   = list_vt_nil()
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

implement {a}
async_tcp_pool_close_exn( pool ) =
  let
    val () =
      ( epollfd_close_exn( pool.efd ); 
       list_vt_freelin<a>( pool.clients ) 
      )
  in 
  end

implement {}
async_tcp_pool_add{socketenv}{fd}( pool, cfd, evts, senv ) =
  if socketfd_set_nonblocking( cfd )
  then
    let
      (** FIXME: ignore EINTR **) 
      val p = $UNSAFE.castvwtp1{ptr}(senv)
      val (pf | err) = epollfd_add1( pool.efd, cfd, evts, epoll_data_ptr(p) ) 
    in if err = 0
       then 
          let
            prval Some_v( pfadd ) = pf 
            prval () = epoll_add_sfd_elim( pfadd , cfd )
            prval () = sockopt_none( cfd )
            val () = pool.clients := list_vt_cons( senv, pool.clients )
            prval () = opt_none( senv )
          in true
          end
        else
          let
            prval None_v( ) = pf 
            prval () = sockopt_some( cfd )
            prval () = opt_some( senv )
          in false
          end
    end 
  else false where {
    prval () = sockopt_some( cfd )
    prval () = opt_some( senv )
  }

implement {}
async_tcp_pool_del{fd}( pool, cfd ) =
  let
    (** FIXME: ignore EINTR **) 
    var empt = epoll_event_empty()
    val err =  epoll_ctl( pool.efd, EPOLL_CTL_DEL, cfd, empt )
  in err = 0
  end

implement {}
async_tcp_pool_add_exn{fd}( pool, cfd, evts, senv ) =
  let
    var cfd = cfd
    var senv = senv
    val () = assertloc( async_tcp_pool_add<>(pool,cfd,evts,senv) )
    prval () = sockopt_unnone(cfd) 
    prval () = opt_unnone(senv) 
  in
  end

implement {}
async_tcp_pool_del_exn{fd}( pool, cfd ) =
  let
    val () = assertloc( async_tcp_pool_del<>(pool,cfd) )
  in
  end



implement {env}{senv}
async_tcp_pool_hup( pool, env, senv ) = (
  sockenv$free<senv>(senv)
)

implement {env}{senv}
async_tcp_pool_error( pool, env, senv ) = (
    perror("async_tcp_pool:epoll");
    sockenv$free<senv>(senv)
  )
(*
implement {env}
async_tcp_pool_accept{fd}( pool, cfd, env ) =
  let
    var cfd = cfd
    val () = assertloc( async_tcp_pool_add<>{fd}(pool,cfd, EPOLLIN lor EPOLLET ) )
    prval () = sockopt_unnone{conn}{fd}( cfd )
  in
  end
*)

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
            
            macdef senv = 
              $UNSAFE.castvwtp1{sockenv}( evt.data.ptr )

            val () =
              ifcase
               | eek_has(events, EPOLLERR ) => 
                    async_tcp_pool_error<env><sockenv>(pool, env, senv ) 
               | eek_has(events, EPOLLHUP ) => 
                    async_tcp_pool_hup<env><sockenv>(pool, env, senv )
                (*
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
                *)
               | _ => (
//                   async_tcp_pool_del_exn<>(pool, clisock );
                   async_tcp_pool_process<sockenv>(pool, events, senv ) 
                )

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
          val n = epoll_wait(pool.efd, ebuf, sz2i(ebsz), ~1)
          
          val () = assertloc( n >= 0 )
          
          var i : [i:nat] int i
  
          val () = loop_evts(pool,ebuf,i2sz(n),env)
          
        in loop_epoll( pool,ebuf,ebsz, env )
        end

      fun spawn_threads{n:nat} .<n>. (
            pool: &async_tcp_pool(sockenv)
          , env: &env >> _ 
          , n_threads : size_t n
        ): void =
        if n_threads > 0
        then
          let
            (** FIXME: This cast is unsafe **)
            val p = $UNSAFE.castvwtp1{async_tcp_pool(sockenv)}(pool)

            (** FIXME: This cast is unsafe **)
            val e = $UNSAFE.castvwtp1{env}(env)

            val _ = athread_create_cloptr_exn<>(
              llam() => 
                let 
                  var rpool = p
                  var renv = e   
                  val maxevts = rpool.maxevents 
                  val ebuf = arrayptr_make_elt<epoll_event>( maxevts, epoll_event_empty())
                  val (pf | par ) = arrayptr_takeout_viewptr( ebuf ) 
                in 
                  loop_epoll( rpool, !par, maxevts, renv );
                  () where { prval () = arrayptr_addback( pf | ebuf ) };
                  free( ebuf );
                  $UNSAFE.cast2void(rpool);
                  $UNSAFE.cast2void(renv);
                end
             );
          in  
            spawn_threads( pool, env, n_threads - 1)  
          end
        else ()
     
    in spawn_threads( pool, env, pool.threads);
      while (true) (ignoret(sleep(1000)));
    (*
    in 
      loop_epoll( pool, env )
    *)
    end 

