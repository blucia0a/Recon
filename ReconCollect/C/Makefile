PLATFORM := $(shell uname)
CXX=g++
CC=gcc
PIN_HOME = $(HOME)/cvsandbox/pin-PANGO/pin-2.8-37300-gcc.3.4.6-ia32_intel64-linux
JSON_LIB = $(PWD)/../libs/libjson/inst/lib

FR ?= 1
FW ?= 0
RACY ?= 1

SIG = sig
RECON = recon

OBJS = make_graph.o reconCollector.o memory_ownership_table.o thread_tracker.o communication_graph.o timer.o

DBG= -g -DVERBOSE
OPT= -O3
CONTEXT_SIZE ?= 5
CONTEXT_MASK ?= 0x3FF 

CXXFLAGS= -Wall -Wno-unknown-pragmas -Wno-deprecated $(DBG) $(OPT) -MMD -I/sampa/home/blucia/cvsandbox/Apps/libjson/inst/include

BUILD ?= pintool
ifeq ($(BUILD),pintool)
  PIN_KIT=$(PIN_HOME)
  KIT=1
  include $(PIN_HOME)/source/tools/makefile.gnu.config
  TARGET = recon
  CXXFLAGS += -UBBBE -USIG_GEN
  LIBNAME = recon 
endif

ifeq ($(FR),1)
	CXXFLAGS += -DFIRSTREAD
	FRNAME = FR
else
	CXXFLAGS += -UFIRSTREAD
	FRNAME = NOFR
endif

ifeq ($(FW),1)
	CXXFLAGS += -DFIRSTWRITE
	FWNAME = FW
else
	CXXFLAGS += -UFIRSTWRITE
	FWNAME = NOFW
endif

ifeq ($(RACY),1)
	CXXFLAGS += -DRACY
	RACYNAME = RACY
else
	CXXFLAGS += -URACY
	RACYNAME = NORACY
endif

all: $(TARGET)
%.o : %.cpp
	$(CXX) $(OPT) $(DBG) -c -DCONTEXT_MASK=$(CONTEXT_MASK) -DCONTEXT_SIZE=$(CONTEXT_SIZE) $(CXXFLAGS) $(PIN_CXXFLAGS) -o $@ $<

$(SIG): $(OBJS)
	$(CXX) $(LDFLAGS) -o $@ $(OBJS) $(DBG)

$(RECON): $(OBJS)
	$(CXX) -L$(JSON_LIB) $(PIN_LDFLAGS) -lrt -ljson $(LDFLAGS) -o $@.$(FRNAME).$(FWNAME).$(RACYNAME) $+ $(PIN_LIBS) $(DBG) $(OPT)
	ln -s $(RECON).$(FRNAME).$(FWNAME).$(RACYNAME) $(RECON).so

test:
	cd TEST; make
	cd ..
	LD_LIBRARY_PATH=$(LD_LIBRARY_PATH):$(JSON_LIB) RECONGRAPHFILE=./TEST/graph $(PIN_HOME)/pin -t $(COLL) -stack -- ./TEST/test
	cat TEST/graph*

clean:
	-rm -f *.o $(BBBE) $(SIG) recon.*.*.*  *.out *.tested *.failed *.d

-include *.d
