/*-<ECON HEADER>-------------------------------------------------------------
Recon - A tool for finding and understanding concurrency errors.

Written by Brandon Lucia   2009-2011
           Benjamin Wood   2010-2011
           Julian Knutsen  2010

Recon was written at the University of Washington.  If you are using this
software, you must agree to the terms in our license, which is available at:

http://cs.washington.edu/homes/blucia0a/recon.html
-</RECON HEADER>------------------------------------------------------------*/

#ifndef THREAD_TRACKER_H

#define THREAD_TRACKER_H



#include "bug_types.h"

#include "communication_graph.h"

#include "Context.h"

class thread_t{

public:



    thread_t(int thread_id);

    ~thread_t();

    Context *threadContext;

    int get_thread_id();

    bool instrumenting;    

    int thread_id;

    int count;

    unsigned int perturb_cnt;    



    //this thread's piece of the communication graph

    graph_edge **cg;

  

};



#endif



