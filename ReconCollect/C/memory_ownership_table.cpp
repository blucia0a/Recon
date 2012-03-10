/*-<ECON HEADER>-------------------------------------------------------------
Recon - A tool for finding and understanding concurrency errors.

Written by Brandon Lucia   2009-2011
           Benjamin Wood   2010-2011
           Julian Knutsen  2010

Recon was written at the University of Washington.  If you are using this
software, you must agree to the terms in our license, which is available at:

http://cs.washington.edu/homes/blucia0a/recon.html
-</RECON HEADER>------------------------------------------------------------*/

#include "memory_ownership_table.h"

#include <stdio.h>

#include <string.h>

#include <strings.h>

memory_index::memory_index(){

  memset(&this->users, 0, MAX_SHR * sizeof(Context *));

  this->last_writer = NULL;

  context = new Context();

  this->timestamp = 0;

  this->instruction_address = 0xdeadbeef;

  InitLock(&(this->lock));

}


void memory_index::Lock(){

  GetLock(&(this->lock),PIN_ThreadId() + 1);

}


void memory_index::Unlock(){

  ReleaseLock(&(this->lock));

}


memory_index::~memory_index(){

  delete this->context;

}


memory_ownership_table::memory_ownership_table(){

  memory_maps = new memory_index[TABLE_SIZE];

}

memory_index *memory_ownership_table::get_memory_index(unsigned long memory_address){

  return &(this->memory_maps[tableentry(memory_address)]);

}
