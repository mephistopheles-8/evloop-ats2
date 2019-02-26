
#include "share/atspre_staload.hats"
#include "./../mylibies_link.hats"

#define MAXEVENTS 64
#define BUFSZ 1024

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


fun test_bufptr () =
  let

    var ints = @[int][1024](0)
    var buf = @[byte][1024](i2byte(0))

    vtypedef mystate = @{
      buf = bufptr(byte,buf,1024)
    }


  
    implement
    array_foreach$fwork<int><mystate>(x,env) =
      let
      in
      end

    
    var ms = (@{
      buf = bufptr_encode( view@buf | addr@buf )
    }) : mystate

    val _ = array_foreach_env<int><mystate>(ints,i2sz(1024),ms)

    val ( pf | p0 ) = bufptr_decode( ms.buf )
    prval () = view@buf := pf 

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
    
    in
       loop_epoll( pool, env ); 
    end 


#define BUFSZ 1024

implement main0 () = println!("Hello [test03]")
  where {
    var p : async_tcp_pool?
    var params = (@{
        port = 8888
      , address = in_addr_hbo2nbo (INADDR_ANY)
      , backlog = 24
      } : async_tcp_params)

    var buf = @[byte][BUFSZ](i2byte(0))
    var bp = bufptr_encode( view@buf | addr@buf ) 
    prval v = view@bp
    val () =
      if async_tcp_pool_create( p, params ) 
      then
        let
          prval () = opt_unsome( p )

          implement
          async_tcp_pool_process<bufptr(byte,buf,BUFSZ)>( pool, evts, cfd, bp ) =
            let
              val (pf | p) = bufptr_decode( bp )
             
              val () =
                if  socketfd_read( cfd, !p, i2sz(BUFSZ) ) >= 0
                then
                    let
                      val () =  println!("Serving client")
                      val ssz = socketfd_write_string( cfd, "Hello guys", i2sz(10) ) 
                      val () = println!("Closing");
                     in async_tcp_pool_del_exn<>( pool, cfd )
                    end
                else async_tcp_pool_del_exn<>( pool, cfd )
                 
              val () = bp := bufptr_encode( pf | p )
            in
            end

          val () = println!("Created TCP pool")
          var x : int = 0
          val () = async_tcp_pool_run<bufptr(byte,buf,BUFSZ)>(p, bp)
        in async_tcp_pool_close_exn( p ) 
        end
      else 
        let
          prval () = opt_unnone( p ) 
        in println!("Failed to create TCP pool")
        end
    prval () = view@bp := v

    val (pf | _) = bufptr_decode( bp ) 
    prval () = view@buf := pf
  }
