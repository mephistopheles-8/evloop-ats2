
#ifndef _ASYNCNET_LINK
#define _ASYNCNET_LINK

%{#
#include <pthread.h>
%}

local
#include "./DATS/socketfd.dats"
in end


#ifdef ASYNCNET_EPOLL
local
#include "./DATS/epoll.dats"
in end
#elifdef ASYNCNET_KQUEUE
local
#include "./DATS/kqueue.dats"
in end
#elifdef ASYNCNET_POLL
local
#include "./DATS/poll.dats"
in end
#endif

#include "./mylibies.hats"

#endif
