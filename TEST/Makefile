PATSHOMEQ="$(PATSHOME)"
PATSCONTRIBQ="$(PATSCONTRIB)"

RMF=rm -f

PATSCC=$(PATSHOMEQ)/bin/patscc

PATSFLAGS=-DATS_MEMALLOC_LIBC
CFLAGS=-O3 -pg -D_GNU_SOURCE

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
test03: test03.dats ; $(PATSCC) $(PATSFLAGS) $(CFLAGS) -o $@ $< -lpthread 
cleanall:: ; $(RMF) test03

all:: test04
test04: test04.dats ; $(PATSCC) -DATS ASYNCNET_SELECT $(PATSFLAGS) $(CFLAGS) -o $@ $< -lpthread 
cleanall:: ; $(RMF) test04

all:: test05
test05: test05.dats ; $(PATSCC) --tlcalopt-disable -DATS ASYNCNET_POLL $(PATSFLAGS) $(CFLAGS) -o $@ $< -lpthread 
cleanall:: ; $(RMF) test05


cleanall:: ; $(RMF) *_*ats.c
cleanall:: ; $(RMF) *.o

clean:: cleanall
