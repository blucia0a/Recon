/*-<ECON HEADER>-------------------------------------------------------------
Recon - A tool for finding and understanding concurrency errors.

Written by Brandon Lucia   2009-2011
           Benjamin Wood   2010-2011
           Julian Knutsen  2010

Recon was written at the University of Washington.  If you are using this
software, you must agree to the terms in our license, which is available at:

http://cs.washington.edu/homes/blucia0a/recon.html
-</RECON HEADER>------------------------------------------------------------*/
#include <stdio.h>

#include <assert.h>

#include "timer.h"

#include "reconCollector.h"

#include "Context.h"


reconCollector::reconCollector(){

	this->mot = new memory_ownership_table();

}


void reconCollector::mem_read(unsigned long memory_address, thread_t *thread, unsigned long instruction_address){


  memory_index *current = 
    this->mot->get_memory_index(memory_address);


  #ifndef RACY
  current->Lock();//NON RACE VERSION
  #endif

  

  Context *last_writer = current->last_writer;

  Context *my_ctx = thread->threadContext;

  Context **users = current->users;



  if(last_writer != my_ctx){  //Last writer was not calling thread


    #ifdef FIRSTREAD 

    bool found = false;

    for(int i = 0; i < MAX_SHR; i++){

      if( users[i] == my_ctx ){

        found = true;

        break;

      }

    }

    if( found == true ){

      #ifndef RACY

      current->Unlock();//RACE VERSION

      #endif

      return;

    }

    #endif /*FIRST READ*/



    if(!current->context){

      #ifndef RACY
      current->Unlock();//RACE VERSION
      #endif

      return;

    }

    #ifdef RACY
    current->Lock();//RACE VERSION
    #endif


    GetLock(&(current->context->lock),1);

    GetLock(&(my_ctx->lock),1);

    //add edge to graph
    unsigned long srcIA = current->instruction_address; 

    context_t srcCtx = current->context->context;

    unsigned long srcTS = current->timestamp;



    unsigned long sinkIA = instruction_address; 

    context_t sinkCtx = my_ctx->context;

    unsigned long sinkTS = getticks();

    my_ctx->push(LocRd);

    /*This loop attempts to insert this thread into the
     *  users array.  If it is competed with during the
     *  insert, or there is no space, we give up, and
     *  forfeit the user information
     */
    int i = 0;
    for(i = 0; i < MAX_SHR; i++){

      if (users[i] == 0){

        CAS(&(users[i]),0,((unsigned long)my_ctx)); 

        break;

      }

    }


    ReleaseLock(&(my_ctx->lock));

    ReleaseLock(&(current->context->lock));


    //First access -- Context is initially NULL 
    if(last_writer != 0){

      last_writer->push(RemRd);

    }

    current->Unlock();



    /*perform the cg insert w/o holding locks for parallelism -- it's local*/

    graph_insert( thread->cg, srcIA,  srcCtx & CONTEXT_MASK,  srcTS, 

                              sinkIA, sinkCtx & CONTEXT_MASK, sinkTS);



  }else{

    //Calling thread was last write
    //Just return!
    #ifndef RACY
    current->Unlock(); 
    #endif

  } 



}



void reconCollector::mem_write(unsigned long memory_address, thread_t *thread, unsigned long instruction_address){

  memory_index *current = 
    this->mot->get_memory_index(memory_address);

  Context *my_ctx= thread->threadContext;

  #ifndef RACY
  current->Lock();
  #endif

  if(current->last_writer != my_ctx){ //Last writer wasn't calling thread


    #ifdef RACY
    current->Lock();
    #endif
    

    if(!current->context){

      current->Unlock();

      return;

    }

    long long t = getticks();

    Context **users = current->users;

    GetLock(&(current->context->lock),1);

    GetLock(&(my_ctx->lock),1);

    /*Get the source of the edge*/
    unsigned long srcIA = current->instruction_address; 

    context_t srcCtx = current->context->context & CONTEXT_MASK;

    unsigned long srcTS = current->timestamp;


    /*Get the sink of the edge*/
    unsigned long sinkIA = instruction_address; 

    context_t sinkCtx = my_ctx->context & CONTEXT_MASK;

    unsigned long sinkTS = getticks();


    /*Make the MOT entry's context the same as the current thread's context*/
    current->context->context = my_ctx->context & CONTEXT_MASK;

    my_ctx->push(LocWr);

    ReleaseLock(&(my_ctx->lock));

    ReleaseLock(&(current->context->lock));


    /*Need to update the Last Writer Table entry because this is a write*/
    current->instruction_address = instruction_address;  

    current->timestamp = t; 

    current->last_writer = my_ctx;

    /*Push a Remote Write to all the Read Sharers*/
    for(int i = 0; i < MAX_SHR; i++){

      if( users[i] ){

        users[i]->push(RemWr);

        users[i] = NULL;

      }

    }

    current->Unlock();

    /*perform the graph insert w/o holding locks for parallelism -- it's local*/
    graph_insert( thread->cg, srcIA,  srcCtx,  srcTS, 

                              sinkIA, sinkCtx, sinkTS);

    

  }
  #ifndef FIRSTWRITE
  else{

    /*When FIRSTWRITE is disabled, all writes by a thread update the Last
     *Writer Table, not just the first one.  This does the update
    */

    #ifdef RACY
    current->Lock();
    #endif

    long long t = getticks();

    current->instruction_address = instruction_address;

    current->timestamp = t;

    GetLock(&(current->context->lock),1);

    current->context->context = my_ctx->context & CONTEXT_MASK;

    ReleaseLock(&(current->context->lock));

    current->Unlock();

  }

  #endif

}

