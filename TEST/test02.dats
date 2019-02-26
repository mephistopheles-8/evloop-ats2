
#include "share/atspre_staload.hats"
#include "./../mylibies_link.hats"

absvt@ype
epollfd_out(fd:int)

extern castfn 
epollfd_take{fd:int}( !epollfd(fd) >> epollfd_out(fd) ) : epollfd(fd)

extern prfn
epollfd_put{fd:int}( !epollfd_out(fd) >> epollfd(fd), epollfd(fd) ) : void


fun 
server_loop
  ( sfd: !socketfd1(listen) )
  : void 
  = let
      #define BUFSZ 1024
      #define MAXEVTS 64
      var buf = @[byte][BUFSZ](i2byte(0))
      var ebuf = @[epoll_event][MAXEVTS](epoll_event_empty())
      val efd = epollfd_create_exn()


      fun loop_evts
        {en,em:nat | em <= en}
        {n,m:nat | m <= n }{fd,efd:int}(
          sfd  : !socketfd(fd,listen)
        , efd  : !epollfd(efd)
        , evts : &(@[epoll_event][en]) 
        , esz : size_t em
        , buf : &(@[byte][n]) 
        , bsz  : size_t m
      ) : void =  
        if esz > 0
        then
          let
            val events = evts[esz-1].events 
            val () =
              if eek_has(events, EPOLLERR ) ||
                 eek_has(events, EPOLLHUP )
              then (
                  println!("Err, HUP");
                  socketfd_close_exn( $UNSAFE.castvwtp1{socketfd0}(evts[esz-1].data.fd) )
                )
              else
                if sfd = g1ofg0(evts[esz - 1].data.fd)
                then println!("Is listening socket")
                  where {
                    implement(efd)
                    socketfd_accept_all$withfd<epollfd(efd)>(cfd,efd) =
                      let
                        val (pf | err) = epollfd_add1( efd, cfd, EPOLLIN lor EPOLLET ) 
                        val () = assertloc( err = 0 )
                        prval Some_v( pfadd ) = pf 
                        prval () = epoll_add_sfd_elim( pfadd , cfd )
                      in ()
                      end 

                    var efd0 = epollfd_take(efd)

                    val ()   = socketfd_accept_all<epollfd(efd)>(sfd,efd0)

                    prval () = epollfd_put(efd,efd0)
                  }
                else 
                  let
                    val cfd = $UNSAFE.castvwtp1{socketfd1(conn)}(evts[esz-1].data.fd)
                    val ssz = socketfd_read( cfd, buf, bsz ) 
                    
                   in if ssz >= 0
                       then 
                          let
                            val ssz = socketfd_write_string( cfd, "Hello guys", i2sz(10) ) 
                            val () =  println!("Serving client")
                            var ev = epoll_event_empty()
                            val _ =  epoll_ctl( efd, EPOLL_CTL_DEL, cfd, ev )

                            val () = println!("Closing");
                           in socketfd_close_exn( cfd )
                          end
                       else ( println!("Error, read."); 
                              socketfd_close_exn( cfd )
                            )
                  end 

             in loop_evts(sfd,efd,evts,esz-1,buf,bsz)
            end
          else ()
 
      and loop_epoll
        {en,em:nat | em <= en}
        {n,m:nat | m <= n }(
          sfd  : !socketfd1(listen)
        , efd  : !epollfd
        , evts : &(@[epoll_event][en]) 
        , esz : size_t em
        , buf : &(@[byte][n]) 
        , bsz  : size_t m
      ) : void = 
        let
          val n = epoll_wait(efd, evts, sz2i(esz), ~1)
          val () = assertloc( n >= 0 )
          
          var i : [i:nat] int i
  
          val () = loop_evts(sfd,efd,evts,i2sz(n),buf,bsz)
          
        in loop_epoll( sfd, efd, evts, esz, buf, bsz )
        end


      val () = assertloc( epollfd_add0( efd, sfd, EPOLLIN lor EPOLLET ) = 0 )
    
    in
       loop_epoll( sfd, efd, ebuf, i2sz(MAXEVTS), buf, i2sz(BUFSZ) ); 
       epollfd_close_exn(efd)
    end 


implement main0 () = 
  println!("Hello [test02]")
  where {
    #define PORT  8888
    #define BACKLOG 24

    (** We could use socket_AF_type_exn here,
        but using the proofs as reference
    **)
    var sp : socketfd_setup_params = @{
          af = AF_INET
        , st = SOCK_STREAM
        , nonblocking = true 
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
          in
            server_loop( sfd ); 
            socketfd_close_exn( sfd ) 
         end
       else 
        let
            prval () = sockopt_unnone( sfd )    
         in (  exit_errmsg_void(1, "Socket setup failed") )
        end
      
  }
