/*-<ECON HEADER>-------------------------------------------------------------
Recon - A tool for finding and understanding concurrency errors.

Written by Brandon Lucia   2009-2011
           Benjamin Wood   2010-2011
           Julian Knutsen  2010

Recon was written at the University of Washington.  If you are using this
software, you must agree to the terms in our license, which is available at:

http://cs.washington.edu/homes/blucia0a/recon.html
-</RECON HEADER>------------------------------------------------------------*/

#ifndef COM_GRAPH_H

#define COM_GRAPH_H



#include "bug_types.h"

#include <set>

#include <tr1/unordered_set>

#include <json/json.h>

#include <stdio.h>



#define PERFORMANCE_GRAPH 0

#define TIMESTAMPS_ON 1



#define NUM_BINS 131073

#define BIN_SIZE 25 

using std::tr1::unordered_set;

using std::set;





typedef struct _graph_edge{



  context_t srcCtx;

  unsigned long srcIA;

  unsigned long srcTS;



  context_t sinkCtx;

  unsigned long sinkIA;

  unsigned long sinkTS;



} graph_edge;

graph_edge **init_graph();

void delete_graph(graph_edge **g);

void graph_insert(graph_edge**g,

                  unsigned long SrcIAddr, 

                  context_t SrcCtx, 

                  unsigned long SrcTS, 

                  unsigned long SinkIAddr, 

                  context_t SinkCtx, 

                  unsigned long SinkTS);

void communicationGraphDump(graph_edge**g,unsigned int thread_id,FILE *f);



#endif



/*

class graph_edge{

public:

  context_t srcCtx;

  unsigned long srcIA;

  long long srcTS;



  context_t sinkCtx;

  unsigned long sinkIA;

  long long sinkTS;



  graph_edge(unsigned long SrcIAddr, context_t SrcCtx, long long SrcTS, unsigned long SinkIAddr, context_t SinkCtx, long long SinkTS);

  graph_edge(const graph_edge& cop){

    this->srcIA = cop.srcIA;

    this->srcCtx = cop.srcCtx;

    this->srcTS = cop.srcTS;

    

    this->sinkIA = cop.sinkIA;

    this->sinkCtx = cop.sinkCtx;

    this->sinkTS = cop.sinkTS;

  }

       

};



class communication_graph{



struct edgeHash{

  size_t operator()(graph_edge *const & e ) const { 



    return e->srcIA  ^ e->srcCtx ^ 

           e->sinkIA ^ e->sinkCtx;



  }

};



struct edgeEq{



  bool operator()(const graph_edge *s1, const graph_edge *s2) const

  {

    if(s1->srcIA != s2->srcIA){

      return false;

    }



    if(s1->sinkIA != s2->sinkIA){

      return false;

    }



    if(s1->srcCtx != s2->srcCtx){

      return false;

    }



    if(s1->sinkCtx != s2->sinkCtx){

      return false;

    }



    return true;

  }



};



public:

        //DONE: Replace the graph's set implementation with an unordered_set

	long long num_communication_events;

	unordered_set<graph_edge*, edgeHash, edgeEq> graph;

	unordered_set<graph_edge*, edgeHash, edgeEq>::iterator it;

	communication_graph();



        //dump the contents of the communication graph

        //TODO: implement this so that it takes a file handle (from the environment?)

        void dump_set();

        void insert(unsigned long srcIAddr, context_t srcCtx, long long srcTS, unsigned long sinkIAddr, context_t sinkCtx, long long sinkTS);



        //insert each entry from the calling communication_graph into the communication_graph *aggregate

        void mergeInto(communication_graph *aggregate);

};



*/

