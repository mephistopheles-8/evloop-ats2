
#include "share/atspre_staload.hats"

staload "libats/libc/SATS/sys/socket.sats"
staload "libats/libc/SATS/netinet/in.sats"
staload "libats/libc/SATS/unistd.sats"
staload "libats/SATS/athread.sats"
staload _ = "libats/DATS/athread.dats"
staload _ = "libats/DATS/athread_posix.dats"

staload "./../SATS/socketfd.sats"
staload "./../SATS/epoll.sats"
staload "./../SATS/async_tcp_pool.sats"

(** FIXME: this should be a parameter **)
#define MAXEVENTS 64

(** FIXME: each thread needs a local ebuf... **)
(** FIXME: number of threads should be a parameter **)
absimpl
async_tcp_pool = @{
   lfd = socketfd1(listen)
 , efd = epollfd 
 , ebuf = arrayptr(epoll_event, MAXEVENTS)
}

absimpl
async_tcp_params = @{
    port = int
  , address = in_addr_nbo_t
  , backlog = intGt(0)
  }

absimpl
async_tcp_event = epoll_event_kind

  
implement {}
async_tcp_pool_create( pool, params ) =
  let
    var sp : socketfd_setup_params = @{
          af = AF_INET
        , st = SOCK_STREAM
        , nonblocking = true 
        , port = params.port
        , address = params.address
        , backlog = params.backlog
      }

    var sfd : socketfd0?
  
   in  if socketfd_setup( sfd, sp )
      then
          let 
            prval () = sockopt_unsome( sfd )
            val (pep | efd) = epoll_create1(EP0) 
          in if efd > 0
             then
                let
                    prval Some_v(pep) =  pep
                    val efd = epollfd_encode( pep | efd ) 
                    val () = assertloc( epollfd_add0( efd, sfd, EPOLLIN lor EPOLLET ) = 0 )
                    val () =
                      pool := (@{    
                          lfd = sfd
                        , efd = efd
                        , ebuf = arrayptr_make_elt( i2sz(MAXEVENTS), epoll_event_empty() )
                       })
                    prval () = opt_some(pool) 
                 in true
                end
             else 
                let
                    prval None_v() =  pep
                    prval () = opt_none(pool)
                    val () = socketfd_close_exn( sfd )
                 in false 
                end
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
      ( epollfd_close_exn( pool.efd ); 
        socketfd_close_exn( pool.lfd );
        free( pool.ebuf ) 
      )
  in 
  end


implement {}
async_tcp_pool_add{fd}( pool, cfd, evts ) =
  let
    val (pf | err) = epollfd_add1( pool.efd, cfd, evts lor EPOLLONESHOT ) 
  in if err = 0
     then 
        let
          prval Some_v( pfadd ) = pf 
          prval () = epoll_add_sfd_elim( pfadd , cfd )
          prval () = sockopt_none( cfd )
        in true
        end
      else
        let
          prval None_v( ) = pf 
          prval () = sockopt_some( cfd )
        in false
        end
  end 

 
implement {}
async_tcp_pool_del{fd}( pool, cfd ) =
  let
    var empt = epoll_event_empty()
    val err =  epoll_ctl( pool.efd, EPOLL_CTL_DEL, cfd, empt )
  in if err = 0
     then if socketfd_close( cfd ) 
          then true
          else false
     else
      let
        prval () = sockopt_some(cfd)
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
  socketfd_close_exn( cfd )

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
    val () = assertloc( async_tcp_pool_add<>{fd}(pool,cfd, EPOLLIN lor EPOLLET ) )
    prval () = sockopt_unnone{conn}{fd}( cfd )
  in
  end


implement  {env}
async_tcp_pool_run( pool, env )  
  = let
      fun loop_evts
        {em:nat | em <= MAXEVENTS}
      (
        pool : &async_tcp_pool
      , env  : &env >> _
      , esz : size_t em
      ) : void =  
        if esz > 0
        then
          let
            val evt = arrayptr_get_at<epoll_event>( pool.ebuf, esz-1 )
            val fd = evt.data.fd
            val events = evt.events
            
            macdef client_sock = 
              $UNSAFE.castvwtp1{socketfd1(conn)}( fd )

            val () =
              ifcase
               | eek_has(events, EPOLLERR ) => 
                    async_tcp_pool_error<env>(pool, client_sock, env ) 
               | eek_has(events, EPOLLHUP ) => 
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
               | _ => async_tcp_pool_process<env>(pool, events, client_sock, env )  

             in loop_evts(pool,env,esz-1)
            end
          else ()
 
      and loop_epoll(
        pool : &async_tcp_pool
      , env  : &env >> _
      ) : void = 
        let
          val (pf | p) = arrayptr_takeout_viewptr( pool.ebuf )
          val n = epoll_wait(pool.efd, !p, MAXEVENTS, ~1)
          prval () = arrayptr_addback( pf | pool.ebuf )
          

          val () = assertloc( n >= 0 )
          
          var i : [i:nat] int i
  
          val () = loop_evts(pool,env,i2sz(n))
          
        in loop_epoll( pool, env )
        end
      (*
      (** FIXME: Attempt at threading**) 
      fun spawn_threads{n:nat} .<n>. ( pool: &async_tcp_pool, env: &env >> _ , n_threads : size_t n) 
        : void =
        if n_threads > 0
        then
          let
            val p = $UNSAFE.castvwtp1{async_tcp_pool}(pool)
            val e = $UNSAFE.castvwtp1{env}(env)
            val _ = athread_create_cloptr_exn<>(
              llam() => 
                let 
                  var rpool = p
                  var renv = e    
                in 
                  loop_epoll( rpool, renv );
                  $UNSAFE.cast2void(rpool);
                  $UNSAFE.cast2void(renv);
                end
             );
          in  
            spawn_threads( pool, env, n_threads - 1)  
          end
        else ()
     
    in spawn_threads( pool, env, i2sz(4));
      while (true) (ignoret(sleep(1000)));
      *)
    in 
      loop_epoll( pool, env )
    end 

