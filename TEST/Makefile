PATSHOMEQ="$(PATSHOME)"
PATSCONTRIBQ="$(PATSCONTRIB)"

RMF=rm -f

PATSCC=$(PATSHOMEQ)/bin/patscc

PATSFLAGS=-DATS_MEMALLOC_LIBC
CFLAGS=-O2

all:: test00
test00: test00.dats ; $(PATSCC) $(PATSFLAGS) $(CFLAGS) -o $@ $< 
cleanall:: ; $(RMF) test00

all:: test01
test01: test01.dats ; $(PATSCC) $(PATSFLAGS) $(CFLAGS) -o $@ $< 
cleanall:: ; $(RMF) test01

all:: test02
test02: test02.dats ; $(PATSCC) -DATS ASYNCNET_EPOLL $(PATSFLAGS) $(CFLAGS) -o $@ $< 
cleanall:: ; $(RMF) test02

all:: test03
test03: test03.dats ; $(PATSCC) -DATS ASYNCNET_EPOLL $(PATSFLAGS) $(CFLAGS) -o $@ $< -lpthread 
cleanall:: ; $(RMF) test03

all:: test04
test04: test04.dats ; $(PATSCC) -DATS ASYNCNET_SELECT $(PATSFLAGS) $(CFLAGS) -o $@ $< -lpthread 
cleanall:: ; $(RMF) test04


cleanall:: ; $(RMF) *_*ats.c
cleanall:: ; $(RMF) *.o

clean:: cleanall
