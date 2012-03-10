/*-<ECON HEADER>-------------------------------------------------------------
Recon - A tool for finding and understanding concurrency errors.

Written by Brandon Lucia   2009-2011
           Benjamin Wood   2010-2011
           Julian Knutsen  2010

Recon was written at the University of Washington.  If you are using this
software, you must agree to the terms in our license, which is available at:

http://cs.washington.edu/homes/blucia0a/recon.html
-</RECON HEADER>------------------------------------------------------------*/





#ifndef BUG_TYPES_H

#define BUG_TYPES_H



#define MAX_THREADS 128

#define MAX_SHR 8

#define CAS(a,b,c) __sync_bool_compare_and_swap(a, b, c)



#ifndef CONTEXT_SIZE

#define CONTEXT_SIZE 5

#endif



#ifndef CONTEXT_MASK

#define CONTEXT_MASK 0x3FF

#endif



enum operation_t { LocRd = 0, LocWr = 1, RemRd = 2, RemWr = 3 };

typedef unsigned context_t;



#endif

