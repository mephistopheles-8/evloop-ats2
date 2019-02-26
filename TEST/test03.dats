
#include "share/atspre_staload.hats"
#include "./../mylibies_link.hats"

#define BUFSZ 1024

absreimpl async_tcp_params

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
                      val ssz = socketfd_write_string( cfd, "HTTP/2.0 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 10\r\n\r\nHello guys", i2sz(75) ) 
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
