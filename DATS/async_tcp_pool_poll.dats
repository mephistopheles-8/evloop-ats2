
#include "share/atspre_staload.hats"

staload "libats/libc/SATS/sys/socket.sats"
staload "libats/libc/SATS/netinet/in.sats"
staload "libats/libc/SATS/unistd.sats"
staload "libats/libc/SATS/stdio.sats"
staload "libats/SATS/athread.sats"
staload _ = "libats/DATS/athread.dats"
staload _ = "libats/DATS/athread_posix.dats"

staload "./../SATS/socketfd.sats"
staload "./../SATS/poll.sats"
staload "./../SATS/async_tcp_pool.sats"

(** FIXME: Replace assertloc with proper exceptions **)
(** FIXME: Make threading optional **)
(** FIXME: Make sure env is handled safely when threading is enabled **)

absimpl
async_tcp_pool = @{
   lfd = socketfd1(listen)
 , maxconn   = sizeGt(0)
 , threads   = sizeGt(0)
 , timeout   = intGte(~1)

 (* thread local / private *)
 , fds       = ptr
 , nfds      = size_t
 , fdcurr    = size_t
 , compress  = bool
}

absimpl
async_tcp_params = @{
    port = int
  , address = in_addr_nbo_t
  , backlog = intGt(0)
  , maxconn   = sizeGt(0)
  , threads   = sizeGt(0)
  , timeout   = intGte(~1)
  , reuseaddr = bool 
  }

absimpl
async_tcp_event = poll_status

  
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
                , maxconn   = params.maxconn
                , threads   = params.threads
                , timeout   = params.timeout
                , fds       = the_null_ptr
                , nfds      = i2sz(0)
                , fdcurr    = i2sz(0)
                , compress  = false
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
    if pool.nfds < pool.maxconn
     then
      let
        val () = $UNSAFE.ptr0_set_at<pollfd>( pool.fds, pool.nfds, pollfd_init( socketfd_value(cfd), $UNSAFE.cast{poll_events}(evts) ) )
        val () = pool.nfds := pool.nfds + 1
        prval () = $UNSAFE.cast2void( cfd )
        prval () = sockopt_none( cfd )
       in true 
      end
    else false where {
      prval () = sockopt_some( cfd )
    }
  else false where {
    prval () = sockopt_some( cfd )
  }

 
implement {}
async_tcp_pool_del{fd}( pool, cfd ) =
    let 
        val () = $UNSAFE.ptr0_set_at<pollfd>( pool.fds, pool.fdcurr, pollfd_empty() )
        val () = pool.compress := true
    in true
      (*if socketfd_close( cfd ) 
      then true
      else false *) 
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
  //  var cfd = cfd
    val () = assertloc( async_tcp_pool_del<>(pool,cfd) )
 //   prval () = sockopt_unnone(cfd) 
  in
  end


implement {env}
async_tcp_pool_hup( pool, cfd, env ) =
   socketfd_close_exn( cfd )

implement {env}
async_tcp_pool_error( pool, cfd, env ) =
  ( if cfd = pool.lfd 
    then exit_errmsg_void(1, "Error on listening socket");
    if pool.nfds < pool.maxconn
    then fprintln!(stderr_ref, "Max connections reached on thread.")
    else perror("async_tcp_pool:poll:local");
    socketfd_close_exn( cfd )
  )

implement {env}
async_tcp_pool_accept{fd}( pool, cfd, env ) =
  let
    var cfd = cfd
    val () = assertloc( async_tcp_pool_add<>{fd}(pool,cfd, pe2ps(POLLIN) ) )
    prval () = sockopt_unnone{conn}{fd}( cfd )
  in
  end


implement  {env}
async_tcp_pool_run( pool, env )  
  = let

      fun compress_pool(
        pool : &async_tcp_pool
      ) : void = ( 
        if pool.compress
        then
          let
            fun loop1{i,n:nat | i <= n} (
              pool : &async_tcp_pool
            , i : size_t i
            , n : size_t n
            ) : void =
              if i < n
              then  
                let
                  val pfd = $UNSAFE.ptr0_get_at<pollfd>( pool.fds, i )
                 in if pfd.fd = ~1
                    then loop2(pool,i,i,n)
                    else loop1(pool,i + 1, n)
                end
              else ()
 
            and loop2{i,j,n:nat | i <= n; j <= n} (
              pool : &async_tcp_pool
            , i : size_t i
            , j : size_t j
            , n : size_t n
            ) : void =
              if j < n
              then 
               let
                  val pfd1 = $UNSAFE.ptr0_get_at<pollfd>( pool.fds, j + 1 )
                  val  ()  = $UNSAFE.ptr0_set_at<pollfd>( pool.fds, j, pfd1 )
                in loop2(pool,i,j+1,n)
               end
              else 
                let
                  val () = if n > 0 then pool.nfds := n - 1 else ()
                 in if i > 0
                    then loop1(pool,i-1,n-1)
                    else if n > 0
                         then loop1(pool,i2sz(0),n-1)
                         else ()
                end
            val n = g1ofg0(pool.nfds)
            val () = assertloc( n >= 0 )
           in 
            pool.compress := false;
            loop1( pool, i2sz(0), n);
          end
        else () 
      ) 

      fun loop_evts
        {n,m:nat | m <= n}
      (
        pool : &async_tcp_pool
      , fds: &(@[pollfd][n])
      , nfds: size_t (m)
      , env  : &env >> _
      ) : void =
        if nfds > 0
        then
          let
            val pfd = fds[nfds - 1]
            val sock = pfd.fd
            val status = pollfd_status(  pfd )
            val () = pool.fdcurr := nfds - 1

            macdef client_sock = 
              $UNSAFE.castvwtp1{socketfd1(conn)}( sock )

          in ifcase
              | poll_status_has( status, POLLHUP ) => 
                    async_tcp_pool_hup<env>(pool, client_sock, env )
              | poll_status_has( status, POLLERR ) =>
                    async_tcp_pool_error<env>(pool, client_sock, env )
              | poll_status_has( status, POLLNVAL ) =>
                    async_tcp_pool_error<env>(pool, client_sock, env )
              (*
              | poll_status_has( status, POLLIN ) && pool.lfd = sock =>
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
                  socketfd_accept_all$withfd<accept_state>(cfd,accs) = (
                    async_tcp_pool_accept<env>(accs.pool, cfd, accs.env );
                  )

                  val ()   = socketfd_accept_all<accept_state>(lfd, accs)

                  val () = 
                    ( pool := accs.pool;
                      env := accs.env
                    )

                  prval () = $UNSAFE.cast2void(lfd)
                  val () = loop_evts(pool, fds, nfds-1, env)
                }
              *)
           | poll_status_has( status, POLLIN ) =>
              let
                  (** Keep the oneshot semantics of epoll / kqueue versions by removing the fd 
                      from the pool... accrues overhead of compression, unfortunately 
                      
                      If the user calls "_add" or "_add_exn", the socket will be re-added.
                      If the user calls "_del" or "_del_exn", the socket will be closed.
                     
                      The user must do one or the other from within the async_tcp_pool_process.

                      FIXME: replace with something less hackish, eventually. 
                  **)
                  val clisock = client_sock
                  
               in
               // async_tcp_pool_del_exn<>( pool, clisock );
                async_tcp_pool_process<env>(pool, status, clisock, env );
                loop_evts(pool, fds, nfds - 1, env);
              end
           | _ =>( 
                   loop_evts(pool, fds, nfds-1, env)
                  )
 
          end 
      else ()
 
      and loop_poll{n,m:nat | m <= n}(
        pool : &async_tcp_pool
      , fds: &(@[pollfd][n])
      , nfds: size_t (m)
      , env  : &env >> _
      ) : void = 
        let
          val n  = poll( fds, sz2nfds( nfds ), pool.timeout ) 
          val () = assertloc( n > ~1 )

          val () = 
            if n > 0 
            then ( 
                   loop_evts( pool, fds, nfds,  env );  
                   compress_pool( pool ) 
                ) 
            else ()
 
        in loop_poll( pool, fds, nfds, env )
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
                  var renv = e
                  val maxconn = rpool.maxconn 
                  var fds = arrayptr_make_elt<pollfd>( maxconn, pollfd_empty() )
 
                  val () = arrayptr_set_at<pollfd>(fds,i2sz(0), pollfd_init( socketfd_value(rpool.lfd), POLLIN ))
                  val (pf | par ) = arrayptr_takeout_viewptr( fds )

                  val () = ( rpool.fds := par; rpool.nfds := i2sz(1) ) 
                 
                in 
                  loop_poll( rpool, !par, maxconn, renv );
                  () where { 
                       prval () = $UNSAFE.cast2void(rpool)
                       prval () = $UNSAFE.cast2void(renv)
                       prval () = arrayptr_addback( pf | fds )
                       val ()   = free(fds)
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
      loop_poll( pool, env )
    *)
    end 

