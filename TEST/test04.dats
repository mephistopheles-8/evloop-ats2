
#include "share/atspre_staload.hats"
#include "./../mylibies_link.hats"

#define BUFSZ 1024

absreimpl async_tcp_params

implement main0 () = println!("Hello [test04]")
  where {
    var p : async_tcp_pool?
    var params = (@{
        port = 8888
      , address = in_addr_hbo2nbo (INADDR_ANY)
      , backlog = 24
      , threads = i2sz(4)
      , timeout = 0
      , reuseaddr = true
      } : async_tcp_params)

    val () =
      if async_tcp_pool_create( p, params ) 
      then
        let
          prval () = opt_unsome( p )

          implement
          async_tcp_pool_process<int>( pool, evts, cfd, env ) =
            let
              val () = println!("Serving client..")
              var buf = @[byte][BUFSZ](i2byte(0))
              val () =
                if  socketfd_read( cfd, buf, i2sz(BUFSZ) ) >= 0
                then
                    let
                      val ssz = socketfd_write_string( 
                        cfd, "HTTP/2.0 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 10\r\n\r\nHello guys", i2sz(75) ) 
                     in async_tcp_pool_del_exn<>( pool, cfd )
                    end
                else async_tcp_pool_del_exn<>( pool, cfd )
                 
            in
            end

          val () = println!("Created TCP pool on port ", params.port )
          var x : int = 0
          val () = async_tcp_pool_run<int>(p, x)

        in async_tcp_pool_close_exn( p ) 
        end
      else 
        let
          prval () = opt_unnone( p ) 
        in println!("Failed to create TCP pool")
        end

  }
