
#define ASYNCNET_EPOLL
#include "share/atspre_staload.hats"
#include "./../mylibies.hats"
staload "libats/libc/SATS/sys/socket.sats"
staload "libats/libc/SATS/sys/socket_in.sats"
staload "libats/libc/SATS/netinet/in.sats"
staload "libats/libc/SATS/errno.sats"
staload "libats/libc/SATS/fcntl.sats"

#define BUFSZ 1024

absreimpl evloop_params

datatype conn_status = 
  | Read

vtypedef client_state = @{
    status = conn_status
  }

implement 
sockenv$free<client_state>( x ) = ()

extern praxi sockfd_is_conn{fd:int}{st:status}( !sockfd(fd,st) >> sockfd(fd,conn) ) : void

implement
evloop$process<client_state>( pool, evts, env ) = (
  let
    var buf = @[byte][BUFSZ](i2byte(0))

    datatype l_action =
      | keep_open
      | close_sock

    fun loop{fd:int}{n:nat}(
           info: &client_state >> _ 
         , sock : &sockfd(fd,conn)
         , buf: &array(byte,n)
         , sz : size_t n
    ) : l_action 
     = let
          val ssz = sockfd_read(sock,buf,sz) 
        in if  ssz > 0 then 
            let
              prval (pf1,pf2) = array_v_split_at( view@buf | g1int2uint(ssz) )
              val  _ = array_foreach_env<byte><client_state>( buf, g1int2uint(ssz), info )
                    where {
                      implement array_foreach$cont<byte><client_state>( b, info )
                        = true 

                      implement array_foreach$fwork<byte><client_state>( b, info ) 
                        = print!($UNSAFE.cast{char}(b)) 
                    }

              val () = print_newline()

              prval () = view@buf := array_v_unsplit( pf1, pf2 )
             in keep_open()
            end
          else  ifcase
                | ssz = 0 => close_sock() 
                | the_errno_test(EAGAIN) => keep_open()
                | _ => close_sock() 
       end

    val b = loop(info, sock, buf, i2sz(BUFSZ) )

   in case+ b of
     | close_sock() => {
          prval () = fold@env 
          val () = assertloc( evloop_events_dispose{client_state}( pool, env ) )
      }
     | keep_open() => {
          prval () = fold@env 
      } 
 end
) where {
  val @CLIENT(sock,data,info) = env
  prval () = sockfd_is_conn( sock )
}

macdef SOMAXCONN = $extval(intGt(0), "SOMAXCONN")

implement main0 () = println!("Hello [test03]")
  where {
    var p : evloop(client_state)?
    var lfd : sockfd0?

    var evloop_params : evloop_params = (@{
        maxevents = i2sz(256)
      } : evloop_params)

    var lsock_params : sockfd_create_bind_params = (@{
        af = AF_INET
      , st = SOCK_DGRAM 
      , nonblocking = true // handled by evloop
      , reuseaddr = true
      , nodelay = false
      , cloexec = true
      , port = 3000
      , address = in_addr_hbo2nbo (INADDR_ANY)
    })

    val () =
      if sockfd_create_bind_port( lfd, lsock_params )
      then 
       let
            prval () = sockopt_unsome( lfd )
        in if evloop_create<client_state>( p, evloop_params ) 
           then
            let
              prval () = opt_unsome( p )
              var linfo : client_state = @{
                    status = Read()
                }

              var senv = sockenv_create<client_state>( lfd, linfo )
              
              val () = assertloc( evloop_events_add{client_state}( p,  EvtR(), senv) )
              
              prval () = opt_unnone( senv )
              

              val () = println!("Created UDP pool on port ", lsock_params.port )
              var x : int = 0
              val () = evloop_run<int><client_state>(p, x)

            in 
              evloop_close_exn<client_state>( p ); 
            end
          else 
            let
              prval () = opt_unnone( p ) 
            in
              println!("Failed to create UDP pool");
              sockfd_close_exn( lfd )  
            end
       end
      else println!("Failed to creatte listening socket") where {
          prval () = sockopt_unnone( lfd ) 
        } 

  }
