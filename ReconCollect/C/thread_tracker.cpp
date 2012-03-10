/*-<ECON HEADER>-------------------------------------------------------------
Recon - A tool for finding and understanding concurrency errors.

Written by Brandon Lucia   2009-2011
           Benjamin Wood   2010-2011
           Julian Knutsen  2010

Recon was written at the University of Washington.  If you are using this
software, you must agree to the terms in our license, which is available at:

http://cs.washington.edu/homes/blucia0a/recon.html
-</RECON HEADER>------------------------------------------------------------*/

#include "thread_tracker.h"

#include <assert.h>

#include <stdio.h>



thread_t::thread_t(int thread_id){

        

  this->thread_id = thread_id;

  this->instrumenting = true;

  this->perturb_cnt = 0;

  this->cg = init_graph();

  this->threadContext = new Context();



}



thread_t::~thread_t(){

  delete_graph(this->cg);

}



int thread_t::get_thread_id(){

  return this->thread_id;

}





/*

main(){

	thread_t *t = new thread_t(1);

	(*t).add_context(RemRd); //3

	(*t).add_context(LocRd); //1

	(*t).add_context(RemRd); //3

	(*t).add_context(LocRd); //1

	(*t).add_context(RemRd); //3

	(*t).add_context(LocWr); //2

	context_t temp = (*t).get_context();

	printf("Context: [%d, %d, %d, %d, %d]\n", temp[0], temp[1], temp[2], temp[3], temp[4]);

}

*/



