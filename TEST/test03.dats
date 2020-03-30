
#include "share/atspre_staload.hats"
#include "./../mylibies_link.hats"
staload "libats/libc/SATS/sys/socket.sats"
staload "libats/libc/SATS/sys/socket_in.sats"
staload "libats/libc/SATS/netinet/in.sats"
staload "libats/libc/SATS/fcntl.sats"

#define BUFSZ 1024

absreimpl async_tcp_params
absreimpl async_tcp_event

datatype conn_status(status) = 
  | Read(conn)
  | Write(conn)
  | Listen(listen)
  | {st:status} 
    Dispose(st)

vtypedef client_info(st:status) = @{
    status = conn_status(st)
  , sock = socketfd1(st)
  , bytes_read = size_t
  }

datavtype client_state =
  | {st:status} CLIENT of client_info(st)


implement 
sockenv$free<client_state>( x ) =
  case+ x of
   | ~CLIENT(info) => socketfd_close_exn(info.sock)

implement 
sockenv$isdisposed<client_state>( x ) = (
  case+ info.status of 
  | Dispose() => true
  | _ => false 
) where {
    val CLIENT(info) = x 
  } 
 

implement main0 () = println!("Hello [test03]")
  where {
    var p : async_tcp_pool(client_state)?
    var lfd : socketfd0?

    var evloop_params : async_tcp_params = (@{
      , threads = i2sz(1)
      , maxevents = i2sz(256)
      } : async_tcp_params)

    var lsock_params : socketfd_setup_params = (@{
        af = AF_INET
      , st = SOCK_STREAM 
      , nonblocking = false // handled by async_tcp_pool
      , reuseaddr = true
      , port = 8888
      , address = in_addr_hbo2nbo (INADDR_ANY)
      , backlog = 24
    })

    val () =
      if socketfd_setup( lfd, lsock_params )
      then 
       let
            prval () = sockopt_unsome( lfd )
        in if async_tcp_pool_create<client_state>( p, evloop_params ) 
           then
            let
              prval () = opt_unsome( p )
              var linfo = CLIENT(@{
                    status = Listen()
                  , sock = $UNSAFE.castvwtp1{socketfd1(listen)}( lfd )
                  , bytes_read = i2sz(0)
                })

              val () = assertloc( async_tcp_pool_add{client_state}( p, lfd , EPOLLIN, linfo) )
              prval () = opt_unnone( linfo )
              
              implement
              async_tcp_pool_process<client_state>( pool, evts, env ) = (
                case+ info.status of
                | Listen() =>
                    let
                        implement
                        socketfd_accept_all$withfd<async_tcp_pool(client_state)>(cfd,pool) = {
                          var cfd = cfd
                          var cinfo = CLIENT(@{
                                status = Read()
                              , sock = $UNSAFE.castvwtp1{socketfd1(conn)}( cfd )
                              , bytes_read = i2sz(0)
                            })
                          val () = assertloc( async_tcp_pool_add{client_state}( pool, cfd , EPOLLIN, cinfo) )
                          prval () = opt_unnone( cinfo )
                          prval () = $UNSAFE.cast2void( cfd )
                        } 
                        val ()   = socketfd_accept_all<async_tcp_pool(client_state)>(info.sock, pool)
                        prval () = fold@env
                     in
                    end
                | Read() =>
                    let
                      var buf = @[byte][BUFSZ](i2byte(0))
                      fun loop( info: &client_info(conn) >> _,  buf:  &array(byte,BUFSZ) >> _ )
                        : void = ()

                      val () =
                        if  socketfd_read( info.sock, buf, i2sz(BUFSZ) ) >= 0 then ()
                      
                      val () = info.status := Write()
                      prval () = fold@env 
                    in
                    end
                | Write() =>
                    let
                      val ssz = socketfd_write_string( 
                        info.sock, "HTTP/2.0 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 10\r\n\r\nHello guys", i2sz(75) )

                      val () = info.status := Read()
                      prval () = fold@env
                     in  
                    end
                | Dispose() => () where { prval () = fold@env }

              ) where {
                val @CLIENT(info) = env
              }

              val () = println!("Created TCP pool on port ", lsock_params.port )
              var x : int = 0
              val () = async_tcp_pool_run<int><client_state>(p, x)

            in 
              async_tcp_pool_close_exn<client_state>( p ); 
              socketfd_close_exn( lfd )  
            end
          else 
            let
              prval () = opt_unnone( p ) 
            in
              println!("Failed to create TCP pool");
              socketfd_close_exn( lfd )  
            end
       end
      else println!("Failed to creatte listening socket") where {
          prval () = sockopt_unnone( lfd ) 
        } 

  }
