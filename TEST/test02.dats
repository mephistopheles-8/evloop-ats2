
#include "share/atspre_staload.hats"
#include "./../mylibies_link.hats"

implement
epoll_event_kind_lor( e1, e2 ) =
  $UNSAFE.cast{epoll_event_kind}( eek2ui(e1) lor eek2ui(e2) ) 

fn eek_has( e1: epoll_event_kind, e2: epoll_event_kind ) 
  :<> bool
  = $UNSAFE.cast{int}(eek2ui(e1) land eek2ui(e2)) != 0 

fn epollfd_listen( efd: !epollfd, sfd: !socketfd0 ) 
  : intBtwe(~1,0)
  = let
      var event = (@{
          events = EPOLLIN lor EPOLLET
        , data = epoll_data_socketfd( sfd )   
        }): epoll_event
     in epoll_ctl( efd, EPOLL_CTL_ADD, sfd, event )
    end 


(** If we add an sfd to epoll, we are likely managing the connection
    via another process.  socketfd can be "free'd" without beeing closed. 
  
    These processes are the same as epollfd_listen except they provide
    a proof, which lets us defer management of the sfd to another process
**)
absprop epoll_add_v(fd:int, st:status)

extern
fn epollfd_add{efd,fd:int}{st:status}( efd: !epollfd(efd), sfd: !socketfd(fd,st) ) 
  : [err: int | err >= ~1; err <= 0]
    (option_v(epoll_add_v(fd,st), err == 0) | int err )

extern
prfn epollfd_add_elim{fd:int}{st:status}( epoll_add_v(fd,st) ) : void

extern
prfn epol_add_sfd_free{fd:int}{st:status}( epoll_add_v(fd,st), socketfd(fd,st) ) : void


fn epollfd_create_exn () : epollfd
  = let
      val (pf | fd ) = epoll_create1(EP0)
      val () = assertloc( fd > 0 ) 
      prval Some_v( pfep ) = pf
    in epollfd_encode( pfep | fd )
    end

fn epollfd_close_exn{fd:int}(efd: epollfd(fd)) 
  : void
  = let
      val (pfep | fd ) = epollfd_decode( efd )  
      val ( pf | err ) = epollfd_close( pfep | fd )
      val () = assertloc( err = 0 )
      prval None_v() = pf  
     in ()
    end

fn epoll_event_empty () : epoll_event =
      @{events = $UNSAFE.cast{epoll_event_kind}(0), data = epoll_data_ptr(the_null_ptr) }

fn eq_socketfd_int {fd,n:int}{st:status}( sfd : !socketfd(fd,st), n: int n) 
  :<> [b:bool | b == (fd == n)] bool b 
  = $UNSAFE.castvwtp1{int fd}(sfd) = n

fn eq_socketfd_socketfd {fd,fd1:int}{st,st1:status}( sfd : !socketfd(fd,st), sfd1 : !socketfd(fd1,st1)) 
  :<> [b:bool | b == (fd == fd1)] bool b 
  = $UNSAFE.castvwtp1{int fd}(sfd) = $UNSAFE.castvwtp1{int fd1}(sfd1)

overload = with eq_socketfd_int
overload = with eq_socketfd_socketfd

extern
fun {env: vt@ype+} socketfd_accept_all$withfd( cfd: socketfd1(conn), &env >> _ )
  : void 


fun {env: vt@ype+} 
socketfd_accept_all{fd:int}( sfd: !socketfd(fd,listen), env: &env >> _ ) 
  : void =
  let
      var cfd : socketfd0?
   in if socketfd_accept( sfd, cfd ) 
      then
        let
          prval () = sockopt_unsome(cfd)
          val () = socketfd_accept_all$withfd<env>(cfd,env)
        in socketfd_accept_all<env>( sfd, env )
        end
      else 
        let
          prval () = sockopt_unnone(cfd)
        in ()
        end
  end

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
                  socketfd_close_exn( $UNSAFE.castvwtp1{socketfd0}(evts[esz-1].data.fd) )
                )
              else
                if sfd = g1ofg0(evts[esz - 1].data.fd)
                then println!("Is listening socket")
                  where {
                    implement(efd)
                    socketfd_accept_all$withfd<epollfd(efd)>(cfd,efd) =
                      let
                        extern // replace this with add interface
                        prfn sfd_free( socketfd0 ) : void
                        val () = assertloc( epollfd_listen( efd, cfd ) = 0 ) 
                        prval () = sfd_free( cfd )
                      in ()
                      end 

                    var efd0 = efd
                    val ()   = socketfd_accept_all<epollfd(efd)>(sfd,efd0)
                    prval ()   =  $effmask_all(
                          efd := efd0
                        )
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


      val () = assertloc( epollfd_listen( efd, sfd ) = 0 )
    
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
