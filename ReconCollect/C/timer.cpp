/*-<ECON HEADER>-------------------------------------------------------------
Recon - A tool for finding and understanding concurrency errors.

Written by Brandon Lucia   2009-2011
           Benjamin Wood   2010-2011
           Julian Knutsen  2010

Recon was written at the University of Washington.  If you are using this
software, you must agree to the terms in our license, which is available at:

http://cs.washington.edu/homes/blucia0a/recon.html
-</RECON HEADER>------------------------------------------------------------*/

#include <time.h>
#include "timer.h"
unsigned long getticks(void)
{

  struct timespec t;
  clock_gettime(CLOCK_MONOTONIC, &t);
  
  return t.tv_sec * 1000000000 + t.tv_nsec;

}
