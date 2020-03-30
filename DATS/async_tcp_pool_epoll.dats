
#include "share/atspre_staload.hats"

staload "libats/libc/SATS/sys/socket.sats"
staload "libats/libc/SATS/netinet/in.sats"
staload "libats/libc/SATS/unistd.sats"
staload "libats/libc/SATS/stdio.sats"
staload "libats/libc/SATS/errno.sats"
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

vtypedef pool_impl(a:vtype) = @{
     efd = epollfd
   , maxevents = sizeGt(0)
   , threads   = sizeGt(0)
  (** FIXMME: Each thread needs a variant of this **)
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

              var pool0 : pool_impl(a) = (@{
                    efd = efd
                  , maxevents = params.maxevents
                  , threads   = params.threads
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
  if socketfd_set_nonblocking( cfd )
  then
    let
      (** Ignore EINTR **)
      fun loop{fd:int}{st:status}
        ( pool: &async_tcp_pool(socketenv)
        , cfd: &socketfd(fd,st)
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
            
            var senv = 
              $UNSAFE.castvwtp1{sockenv}( evt.data.ptr )

            val () =
              ifcase
               | eek_has(events, EPOLLERR ) => 
                    async_tcp_pool_error<env><sockenv>(pool, env, senv ) 
               | eek_has(events, EPOLLHUP ) => 
                    async_tcp_pool_hup<env><sockenv>(pool, env, senv )
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
                  var rpool : async_tcp_pool(sockenv) = p
                  var renv : env = e   
                  val maxevts = rpool.maxevents 
                  val ebuf = arrayptr_make_elt<epoll_event>( maxevts, epoll_event_empty())
                  val (pf | par ) = arrayptr_takeout_viewptr( ebuf ) 
                  val () = (
                    loop_epoll( rpool, !par, maxevts, renv );
                    () where { prval () = arrayptr_addback( pf | ebuf ) };
                    free( ebuf );
                  )
                  prval () = (
                    $UNSAFE.cast2void(rpool);
                    $UNSAFE.cast2void(renv);
                  )
                in 
                end
             );
          in  
            spawn_threads( pool, env, n_threads - 1)  
          end
        else ()
     
    in spawn_threads( pool, env, i2sz(1)(*pool.threads*));
      while (true) (ignoret(sleep(1000)));
    (*
    in 
      loop_epoll( pool, env )
    *)
    end 

