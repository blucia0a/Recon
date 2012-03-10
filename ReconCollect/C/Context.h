/*-<ECON HEADER>-------------------------------------------------------------
Recon - A tool for finding and understanding concurrency errors.

Written by Brandon Lucia   2009-2011
           Benjamin Wood   2010-2011
           Julian Knutsen  2010

Recon was written at the University of Washington.  If you are using this
software, you must agree to the terms in our license, which is available at:

http://cs.washington.edu/homes/blucia0a/recon.html
-</RECON HEADER>------------------------------------------------------------*/

#ifndef _CONTEXT_H_
#define _CONTEXT_H_
#include "pthread.h"
#include "bug_types.h"
#include "pin.H"

#define CONTEXT_EVENT_BITS 2

class Context{
private:
public:
  context_t context;
  PIN_LOCK lock;

  Context(){
    InitLock(&lock);
    context = 0;
  }

  context_t getContext(){
    /*HARD CODED FOR 5 CONTEXT ENTRIES*/
    return context & CONTEXT_MASK;
  }

  virtual void push(operation_t ev){

    context <<= CONTEXT_EVENT_BITS; 
    context |= ev;

  }

};
#endif
