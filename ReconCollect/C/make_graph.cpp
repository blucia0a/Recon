/*-<RECON HEADER>-------------------------------------------------------------
Recon - A tool for finding and understanding concurrency errors.

Written by Brandon Lucia   2009-2011
           Benjamin Wood   2010-2011
           Julian Knutsen  2010

Recon was written at the University of Washington.  If you are using this
software, you must agree to the terms in our license, which is available at:

http://cs.washington.edu/homes/blucia0a/recon.html
-</RECON HEADER>------------------------------------------------------------*/

#include <stdio.h>

#include <stdlib.h>

#include <string.h>

#include <tr1/unordered_set>

#include <time.h>

#include <iostream>

#include <fstream>

#include "pin.H"

#include "reconCollector.h"

#include "bug_types.h"

#include "Context.h"

reconCollector *b;

PIN_LOCK globalLock;

static TLS_KEY tls_key;

KNOB<string> FuncProf(KNOB_MODE_WRITEONCE, "pintool", "p", "", "Specify a file containing a list of functions to instrument");

KNOB<bool> Stack(KNOB_MODE_WRITEONCE, "pintool", "stack", "false", "Use this flag if you want to instrument accesses to stack data");

enum MemOpType { MemRead = 0, MemWrite = 1 };

// function to access thread-specific data
thread_t* get_tls(THREADID thread_id) {

    thread_t* tdata = 
          static_cast<thread_t*>(PIN_GetThreadData(tls_key, thread_id));

    return tdata;

}

/*Analysis Routines------------------------------------------------------*/

static void inst_off(int thread_id){

  thread_t* t = get_tls(thread_id);

  t->instrumenting = false; 

}



static void inst_on(int thread_id){

  thread_t* t = get_tls(thread_id);

  t->instrumenting = true; 

}



#define PERTURBATION_CONSTANT 1024
static void schedPerturb(int tid){

  thread_t* current_thread = get_tls(tid);

  if(++(current_thread->perturb_cnt) == PERTURBATION_CONSTANT){

    fprintf(stderr,".");

    current_thread->perturb_cnt = rand() % (PERTURBATION_CONSTANT / 4);

    usleep(10);

  }

}

VOID HandleMemoryAccess(THREADID tid, ADDRINT addr, ADDRINT pc, MemOpType t)

{

  thread_t* current_thread = get_tls(tid);

  if(current_thread->instrumenting == false){

    return;

  }



  bool isRead = (t == MemRead);



  if(isRead){

    b->mem_read(addr, current_thread, pc);

  }else{

    b->mem_write(addr, current_thread, pc);

  }

}



/*Instrumentation Routines-----------------------------------------------*/

VOID instrumentRoutine(RTN rtn, VOID *v){

  if(!RTN_Valid(rtn)){

    return;

  }

  RTN_Open(rtn);

  if(!IMG_IsMainExecutable(IMG_FindByAddress(RTN_Address(rtn)))){

    #if defined(RANDPERTURB)

    if(strstr(RTN_Name(rtn).c_str(),"pthread_mutex_lock")){

      RTN_InsertCall(rtn, 

                     IPOINT_BEFORE, 

                     (AFUNPTR)schedPerturb,  

                     IARG_THREAD_ID,

                     IARG_END);



    } 

    #endif

    RTN_Close(rtn);

    return;

  }



  if(strstr(RTN_Name(rtn).c_str(),"INSTRUMENT_ON")){

    RTN_InsertCall(rtn, 

                   IPOINT_BEFORE, 

                   (AFUNPTR)inst_on,  

                   IARG_THREAD_ID,

                   IARG_END);

  } 



  if(strstr(RTN_Name(rtn).c_str(),"INSTRUMENT_OFF")){

    RTN_InsertCall(rtn, 

                   IPOINT_BEFORE, 

                   (AFUNPTR)inst_off,  

                   IARG_THREAD_ID,

                   IARG_END);

  } 

  bool ignore = false; 

  LEVEL_CORE::IMG_TYPE imgType = IMG_Type(SEC_Img(RTN_Sec(rtn)));

  /*Ignore this image if it is a SHAREDLIB (.so) or RELOCATABLE (.o)*/
  ignore = !((imgType == IMG_TYPE_STATIC) || (imgType == IMG_TYPE_SHARED));
  if( ignore ){
    return;
  }

  for (INS ins = RTN_InsHead(rtn); INS_Valid(ins); ins = INS_Next(ins)){	

    if(!INS_Valid(ins)){

      continue;

    }

    if(INS_IsMemoryRead(ins)) {

      bool stack = INS_IsStackRead(ins);

      if( (stack && !Stack.Value()) ||
          INS_IsAtomicUpdate(ins) ){

        continue;

      }

      INS_InsertCall(ins, 

                     IPOINT_BEFORE, 

		     (AFUNPTR)HandleMemoryAccess, 

		     IARG_THREAD_ID,

		     IARG_MEMORYREAD_EA,

		     IARG_INST_PTR,

		     IARG_UINT32, MemRead,

		     IARG_END);


      

    } else if(INS_IsMemoryWrite(ins)) {



      bool stack = INS_IsStackWrite(ins);
      if( (stack && !Stack.Value()) ||
          INS_IsAtomicUpdate(ins) ){

        continue;

      }


      INS_InsertCall(ins, 

                     IPOINT_BEFORE, 

                     (AFUNPTR)HandleMemoryAccess, 

                     IARG_THREAD_ID,

                     IARG_MEMORYWRITE_EA,

                     IARG_INST_PTR,

                     IARG_UINT32, MemWrite,

                     IARG_END);


    }

  }

  RTN_Close(rtn);

}

/*When a thread ends, it dumps its part of the communication graph to
 *the graph output file
*/
VOID ThreadEnd(THREADID thread_id, const CONTEXT *c, INT32 flags, VOID *v){

    //Find the thread
    thread_t *thread = get_tls(thread_id);


    GetLock(&globalLock, thread_id + 1);
    

    FILE *graphFile = NULL;

    pid_t thepid = getpid();

    char buf[1024];

    char name[128];

    char exe[1024];

    sprintf(buf,"/proc/%d/stat",thepid);

    FILE *exeinfo = fopen(buf,"r");

    fscanf(exeinfo,"%s %s",name,exe);

    fclose(exeinfo);

    exe[ 0 ]='_';

    exe[ strlen(exe) - 1 ]='0';

    char *graphFileName = NULL;

    if((graphFileName = getenv("RECONGRAPHFILE")) != NULL){

      sprintf(buf,"%sE%sP%d",graphFileName,exe,thepid);

      graphFile = fopen(buf,"a");

      if(graphFile == NULL){

        graphFile = stderr;

      }

    } else {

	graphFile = stderr;

    }

    communicationGraphDump(thread->cg,thread_id,graphFile);

    fflush(graphFile);

    fclose(graphFile);

    ReleaseLock(&globalLock);

    delete thread;

}


/*When a thread starts, set up a new thread_tracker data structure
 *and associate it with the tls_key to make it accessible
*/
VOID ThreadStart(THREADID thread_id, CONTEXT *ctxt, INT32 flags, VOID *v){

    thread_t *tdata = new thread_t(thread_id);

    PIN_SetThreadData(tls_key, tdata, thread_id);

}



// This function is called when the application exits
// Currently there is nothing that needs to be done at this point.
VOID Fini(INT32 code, VOID *v)

{

/*Add Recon Shutdown Actions Here*/

}







int main(int argc, char *argv[])

{

    srand(time(NULL));    


    // Initialize pin

    PIN_InitSymbols();

    PIN_Init(argc, argv);



    // Initialize the lock

    InitLock(&globalLock);

    

    // Obtain a key for TLS storage.

    tls_key = PIN_CreateThreadDataKey(0);



    // Register ThreadStart to be called when a thread starts.

    PIN_AddThreadStartFunction(ThreadStart, 0);



    //Register ThreadEnd to be called when a thread ends.

    PIN_AddThreadFiniFunction(ThreadEnd, 0);



    // Register Instruction to be called to instrument instructions.

    RTN_AddInstrumentFunction(instrumentRoutine, 0);



    // Register Fini to be called when the application exits.

    PIN_AddFiniFunction(Fini, 0);


    //Make a graph collector

    b = new reconCollector();
  
    PIN_StartProgram();

    return 0;

}

