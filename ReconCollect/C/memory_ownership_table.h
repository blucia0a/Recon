/*-<ECON HEADER>-------------------------------------------------------------
Recon - A tool for finding and understanding concurrency errors.

Written by Brandon Lucia   2009-2011
           Benjamin Wood   2010-2011
           Julian Knutsen  2010

Recon was written at the University of Washington.  If you are using this
software, you must agree to the terms in our license, which is available at:

http://cs.washington.edu/homes/blucia0a/recon.html
-</RECON HEADER>------------------------------------------------------------*/

#ifndef MEMORY_OWNER_H

#define MEMORY_OWNER_H



#include "bug_types.h"

#include "thread_tracker.h"

#include "Context.h"

#include <ext/hash_map>

#include <set>

#include <tr1/unordered_set>

#include "pin.H"



using std::set;



#define NUM_SEGMENTS 8 

#define SEGMENT_SIZE 8388608//2^23 entries in the table to map the 2^61 possible words



#define SEGMENT_HASH 0xffffffffff800000//41 bits

#define ENTRY_HASH 0x7fffff//23 bits



//Makes 7.7GB total storage

#define BLOCK_BITS 3

#define BLOCK_MASK 0x0000000000000007

#define TABLE_SIZE 33554432//67108864//64MegaEntries //8388608//134217728

#define tableentry(addr) (((addr >> BLOCK_BITS ) % TABLE_SIZE) + (addr & BLOCK_MASK))

//#define tableentry(addr) ((addr >> 25) ^ addr) & 0x0000000001FFFFFF





struct eqint

{

  bool operator()(int s1, int s2) const

  {

    return s1 == s2;

  }

};



class memory_index {

public:

	Context *last_writer;

	Context *users[MAX_SHR];



	Context *context;

	unsigned long instruction_address;

	long long timestamp;//TODO: unsigned?

        PIN_LOCK lock;

         

        void Lock();

        void Unlock();

	memory_index();

	~memory_index();

};



class memory_ownership_table {

public:

        memory_index *memory_maps;

	memory_ownership_table();

	memory_index *get_memory_index(unsigned long memory_address);	

};



#endif

