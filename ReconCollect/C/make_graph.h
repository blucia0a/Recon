/*-<ECON HEADER>-------------------------------------------------------------
Recon - A tool for finding and understanding concurrency errors.

Written by Brandon Lucia   2009-2011
           Benjamin Wood   2010-2011
           Julian Knutsen  2010

Recon was written at the University of Washington.  If you are using this
software, you must agree to the terms in our license, which is available at:

http://cs.washington.edu/homes/blucia0a/recon.html
-</RECON HEADER>------------------------------------------------------------*/

#if defined(BBBE)

#include "reconCollector.h"

#include "thread_tracker.h"

#include "bug_types.h"

enum MemOpType { MemRead = 0, MemWrite = 1 };



extern "C" {

  VOID HandleMemoryAccess(unsigned long tls_ptr, unsigned long addr, unsigned long pc, MemOpType t, bool isStackRef, bool isAtomic);

  VOID ThreadEnd(thread_t* tls_ptr);

  unsigned long ThreadStart(THREADID thread_id);

  VOID BugabooInit();

  VOID BugabooShutdown();

}

#endif



