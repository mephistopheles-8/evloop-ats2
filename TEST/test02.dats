%{#
#include <pthread.h>
%}
#define ASYNCNET_EPOLL
#include "share/atspre_staload.hats"
#include "./../mylibies.hats"
staload "libats/libc/SATS/sys/socket.sats"
staload "libats/libc/SATS/sys/socket_in.sats"
staload "libats/libc/SATS/netinet/in.sats"
staload "libats/libc/SATS/errno.sats"
staload "libats/libc/SATS/fcntl.sats"
staload "libats/libc/SATS/unistd.sats"
staload "libats/SATS/athread.sats"
staload _ = "libats/DATS/athread.dats"

#define BUFSZ 1024

absreimpl evloop_params

datatype conn_status = 
  | Listen
  | Read
  | Write

datatype parse_status = 
  | psnil
  | ps0
  | ps1
  | ps2
  | pssuccess
  | psfailure
    
vtypedef client_state = @{
    status = conn_status
  , bytes_read = size_t
  , parse_status = parse_status
  , reqs_served = int
  }

implement 
sockenv$free<client_state>( x ) = ()

macdef SOMAXCONN = $extval(intGt(0), "SOMAXCONN")

implement
evloop$process<client_state>( pool, evts, env ) = (
  case+ info.status of
  | Listen() =>
      let
          implement
          sockfd_accept_all$withfd<evloop(client_state)>(cfd,pool) = (
            if evloop_events_add{client_state}( pool, EvtR(), senv )
            then true where {
                prval () = opt_unnone( senv )
              }
            else false where {
              prval () = opt_unsome( senv )
              val @(cfd,_) = sockenv_decompose<client_state>( senv )
              val () = sockfd_close_exn( cfd )
            }
          ) where {
            var cfd = cfd
            var cinfo : client_state = @{
                  status = Read()
                , bytes_read = i2sz(0)
                , parse_status = psnil
                , reqs_served = 0
              }
            var senv = sockenv_create<client_state>( cfd, cinfo )
          }
          extern praxi socket_is_listening{fd:int}{st:status}( !sockfd(fd,st) >> sockfd(fd,listen) ) : void
          prval () = socket_is_listening( sock )

          val ()   = sockfd_accept_all<evloop(client_state)>(sock, pool)
          prval () = fold@env
       in
      end
  | Read() =>
      let
        var buf = @[byte][BUFSZ](i2byte(0))

        (** The ol' fast-forward to the \r\n\r\n trick
            a real HTTP (or whatever) parser should go here.
            this also caps the size of the request at 4096 **)

        datatype l_action =
          | keep_open
          | close_sock
          | arm_write

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
                              = if info.bytes_read >= 4096 
                                then (info.parse_status := psfailure(); false)
                                else case+ info.parse_status of
                                     | pssuccess() => false
                                     | psfailure() => false
                                     | _         => true

                          implement array_foreach$fwork<byte><client_state>( b, info ) = ( 
                               case+ info.parse_status of
                                | psnil() when byte2int0(b) = 13 => info.parse_status := ps0()
                                | ps0() when byte2int0(b) = 10 => info.parse_status := ps1()
                                | ps1() when byte2int0(b) = 13 => info.parse_status := ps2()
                                | ps2() when byte2int0(b) = 10 => info.parse_status := pssuccess()
                                | _ => info.parse_status := psnil() 
                            ) where {
                                val () = info.bytes_read := info.bytes_read + 1
                              }
                        }
                  prval () = view@buf := array_v_unsplit( pf1, pf2 )

                in case+ info.parse_status of
                   | pssuccess() => arm_write()
                   | psfailure() => close_sock()
                   | _         => loop(info,sock,buf,sz)
                end
              else  ifcase
                    | ssz = 0 => close_sock() 
                    | the_errno_test(EAGAIN) => keep_open()
                    | _ => close_sock() 
           end

          extern praxi socket_is_conn{fd:int}{st:status}( !sockfd(fd,st) >> sockfd(fd,conn) ) : void
         prval () = socket_is_conn( sock )
         val b = loop(info, sock, buf, i2sz(BUFSZ) ) 

      in case+ b of
         | arm_write() => {
              val () = info.status := Write()
              prval () = fold@env 
              val () = assertloc( evloop_events_mod{client_state}( pool, EvtW(), env) )
           }
         | close_sock() => {
              prval () = fold@env 
              val () = assertloc( evloop_events_dispose{client_state}( pool, env ) )
          }
         | keep_open() => {
              prval () = fold@env 
          } 
      end
  | Write() =>
      let
        extern praxi socket_is_conn{fd:int}{st:status}( !sockfd(fd,st) >> sockfd(fd,conn) ) : void
        prval () = socket_is_conn( sock )
        val ssz = sockfd_write_string( 
          sock, "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 10\r\n\r\nHello guys", i2sz(75) )
        val () = info.status := Read()
        prval () = fold@env

        val () = assertloc( evloop_events_mod( pool, EvtR(), env) )
       in  
      end

) where {
  val @CLIENT(sock,data,info) = env
}

implement main0 () = println!("Hello [test01]")
  where {
    var lfd : sockfd0?

    var lsock_params : sockfd_setup_params = (@{
        af = AF_INET
      , st = SOCK_STREAM 
      , nonblocking = true // handled by evloop
      , reuseaddr = true
      , nodelay = true
      , cloexec = false
      , port = 8888
      , address = in_addr_hbo2nbo (INADDR_ANY)
      , backlog = SOMAXCONN
    })

    val () =
      if sockfd_setup( lfd, lsock_params )
      then 
       let
          prval () = sockopt_unsome( lfd )
          val () = println!("Listening at port ", lsock_params.port )
          fun spawn_threads{fd:int}( lfd0: sockfd(fd,listen), i: intGte(0) )
            : void =
             if i > 0 
             then 
              let
                  extern
                  fn dup{fd:int}{st:status}( sfd: !sockfd(fd,st) )
                      : [fd0:int | fd >= ~1] (option_v(socket_v(fd0,st),fd0 > ~1) | int fd0) = "mac#dup"

                  val (pf | fd0) = dup( lfd0 )
                  val () = assertloc( fd0 > ~1 )
                  prval Some_v(pf) = pf
                  val lfd = sockfd_encode( pf | fd0)
 
                  val _ = athread_create_cloptr_exn(llam() =>
                     let
                         var p : evloop(client_state)?
                         var evloop_params : evloop_params = (@{
                             maxevents = i2sz(256)
                           } : evloop_params)
                      in if evloop_create<client_state>( p, evloop_params ) 
                          then
                           let
                             prval () = opt_unsome( p )
                             var linfo : client_state = @{
                                   status = Listen()
                                 , bytes_read = i2sz(0)
                                 , parse_status = psnil
                                 , reqs_served = 0
                               }

                             var senv = sockenv_create<client_state>( lfd, linfo )
                             
                             val () = assertloc( evloop_events_add{client_state}( p,  EvtR(), senv) )
                             
                             prval () = opt_unnone( senv )
                             
                             var x : int = 0
                             val () = evloop_run<int><client_state>(p, x)

                           in 
                             evloop_close_exn<client_state>( p ); 
                           end
                         else 
                           let
                             prval () = opt_unnone( p ) 
                           in
                             println!("Failed to create TCP pool");
                             sockfd_close_exn( lfd )  
                           end
                     end
                  )
               in spawn_threads(lfd0,i-1)
              end
             else sockfd_close_exn( lfd0 ) // is this valid?
 
        in spawn_threads( lfd, 4 );
           while ( true ) ( ignoret(sleep(100)) )
       end
      else println!("Failed to creatte listening socket") where {
          prval () = sockopt_unnone( lfd ) 
        } 

  }
