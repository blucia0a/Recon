/*-<ECON HEADER>-------------------------------------------------------------
Recon - A tool for finding and understanding concurrency errors.

Written by Brandon Lucia   2009-2011
           Benjamin Wood   2010-2011
           Julian Knutsen  2010

Recon was written at the University of Washington.  If you are using this
software, you must agree to the terms in our license, which is available at:

http://cs.washington.edu/homes/blucia0a/recon.html
-</RECON HEADER>------------------------------------------------------------*/

#ifndef _BUGABOO_H_

#define _BUGABOO_H_

#include "bug_types.h"

#include "memory_ownership_table.h"

#include "communication_graph.h"

#include <string.h>

class reconCollector{

public:

	memory_ownership_table *mot;



	reconCollector();

	void mem_write(unsigned long memory_address, thread_t *thread, unsigned long instruction_address);

	void mem_read(unsigned long memory_address, thread_t *thread, unsigned long instruction_address);

};

#endif

