
local
#include "./DATS/socketfd.dats"
in end

#ifdef ASYNCNET_EPOLL
local
#include "./DATS/epoll.dats"
in end
#endif

#include "./mylibies.hats"
