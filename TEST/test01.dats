
#include "share/atspre_staload.hats"
#include "./../mylibies_link.hats"

(** We really don't want this throwing exceptions **)

fun server_loop
  {fd:int}{n,sz:nat | n <= sz}( 
   lfd:  &socketfd(fd,listen)
 , buf : &bytes(sz) 
 , sz : size_t n 
) : void =
    let
      var cfd : socketfd0?

      val () = 
        if socketfd_accept(lfd,cfd) 
        then 
          let
            prval () = sockopt_unsome( cfd )
            val ssz = socketfd_read( cfd, buf, sz ) 
          in if ssz >= 0
             then 
                let
                  val ssz = socketfd_write_string( cfd, "Hello guys", i2sz(10) ) 
                  val () =  println!("Serving client")

                 in socketfd_close_exn( cfd )
                end
             else ( println!("Error, read."); 
                    socketfd_close_exn( cfd )
                  )
          end 
        else
          let
            prval () = sockopt_unnone( cfd )
          in println!("Could not connect to client..")
          end
 
    in server_loop( lfd, buf, sz )
    end


implement main0 ()
 = println!("Hello [test01]")
 where {
  #define PORT  8888
  #define BACKLOG 24
  #define BUFSZ 1024

  var buf = @[byte][BUFSZ](i2byte(0))
  (** We could use socket_AF_type_exn here,
      but using the proofs as reference
  **)
  var sp : socketfd_setup_params = @{
        af = AF_INET
      , st = SOCK_STREAM
      , nonblocking = false 
      , port = PORT
      , address = in_addr_hbo2nbo (INADDR_ANY)
      , backlog = BACKLOG
    }

  var sfd : socketfd0?

  val () = 
    if socketfd_setup( sfd, sp )
    then
        let 
          prval () = sockopt_unsome( sfd )
          val () = println!("Listening to port ", PORT)
          val () = server_loop( sfd, buf, i2sz(BUFSZ ) )
        in socketfd_close_exn( sfd ) 
       end
     else 
      let
          prval () = sockopt_unnone( sfd )    
       in (  exit_errmsg_void(1, "Socket setup failed") )
      end
 }
