
#include "share/atspre_staload.hats"

staload "libats/libc/SATS/sys/socket.sats"
staload "libats/libc/SATS/netinet/in.sats"
staload "libats/libc/SATS/unistd.sats"
staload "libats/libc/SATS/stdio.sats"
staload "libats/SATS/athread.sats"
staload _ = "libats/DATS/athread.dats"
staload _ = "libats/DATS/athread_posix.dats"

staload "./../SATS/socketfd.sats"
staload "./../SATS/select.sats"
staload "./../SATS/async_tcp_pool.sats"

(** FIXME: Replace assertloc with proper exceptions **)
(** FIXME: Make threading optional **)
(** FIXME: Make sure env is handled safely when threading is enabled **)

absimpl
async_tcp_pool = @{
   lfd = socketfd1(listen)
 , threads   = sizeGt(0)
 , timeout   = intGte(~1) 
 , active_set = fd_set
 , read_set = fd_set
}

absimpl
async_tcp_params = @{
    port = int
  , address = in_addr_nbo_t
  , backlog = intGt(0)
  , threads   = sizeGt(0)
  , timeout   = intGte(~1)
  , reuseaddr = bool 
  }

absimpl
async_tcp_event = int

  
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
            var active_set : fd_set
            val () = FD_ZERO( active_set )
            val () =
              pool := (@{    
                  lfd = sfd
                , threads   = params.threads
                , timeout   = params.timeout
                , active_set = active_set
                , read_set   = active_set
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
    val () = FD_SET( socketfd_value( cfd ), pool.active_set )
    prval () = $UNSAFE.cast2void( cfd )
    prval () = sockopt_none( cfd )
   in true 
  end 
  else false where {
    prval () = sockopt_some( cfd )
  }

 
implement {}
async_tcp_pool_del{fd}( pool, cfd ) =
    let 
      val () = FD_CLR( socketfd_value( cfd ), pool.active_set ) 
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
   // var cfd = cfd
    val () = assertloc( async_tcp_pool_del<>(pool,cfd) )
   // prval () = sockopt_unnone(cfd) 
  in
  end



implement {env}
async_tcp_pool_hup( pool, cfd, env ) =
   socketfd_close_exn( cfd )

implement {env}
async_tcp_pool_error( pool, cfd, env ) =
  ( if cfd = pool.lfd 
    then exit_errmsg_void(1, "Error on listening socket");
    perror("async_tcp_pool:select:local");
    socketfd_close_exn( cfd )
  )

implement {env}
async_tcp_pool_accept{fd}( pool, cfd, env ) =
  let
    var cfd = cfd
    val () = assertloc( async_tcp_pool_add<>{fd}(pool,cfd, 0 ) )
    prval () = sockopt_unnone{conn}{fd}( cfd )
  in
  end


implement  {env}
async_tcp_pool_run( pool, env )  
  = let
      fun loop_evts
        {n:nat | n <= FD_SETSIZE}
      (
        pool : &async_tcp_pool
      , env  : &env >> _
      , i : int n 
      ) : void =
        if i > 0
        then 
          if FD_ISSET( i, pool.read_set ) 
          then 
            if pool.lfd = i
            then
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
              val () = loop_evts(pool, env, i-1)
            }
            else
              let 
                 (** Keep the oneshot semantics of epoll / kqueue versions
                    by removing the fd from the pool.  They must 
                    remove or re-add the socket manually.
                    FIXME: replace with something less hackish.
                 **)
                val clisock = $UNSAFE.castvwtp0{socketfd1(conn)}(i)
               in
                async_tcp_pool_del_exn<>( pool, clisock ); 
                async_tcp_pool_process<env>(pool, 0, clisock, env );
                loop_evts(pool, env, i-1) 
              end 
          else loop_evts(pool, env, i-1)
      else () 

 
      and loop_select(
        pool : &async_tcp_pool
      , env  : &env >> _
      ) : void = 
        let

          prval () = FD_SETSIZE_is_pos()

          val () = pool.read_set := pool.active_set

          val err = select( FD_SETSIZE, pool.read_set, the_null_ptr, the_null_ptr, the_null_ptr ) 
          
          val () = assertloc( err >= 0 )
          val () = loop_evts( pool, env, FD_SETSIZE ) 
          
        in loop_select( pool, env )
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
                  val () = FD_ZERO( rpool.active_set )
                  val () = FD_SET( socketfd_value( rpool.lfd ), rpool.active_set )
                in 
                  loop_select( rpool, renv );
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
      loop_select( pool, env )
    *)
    end 

