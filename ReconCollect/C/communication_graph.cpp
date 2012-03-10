/*-<ECON HEADER>-------------------------------------------------------------
Recon - A tool for finding and understanding concurrency errors.

Written by Brandon Lucia   2009-2011
           Benjamin Wood   2010-2011
           Julian Knutsen  2010

Recon was written at the University of Washington.  If you are using this
software, you must agree to the terms in our license, which is available at:

http://cs.washington.edu/homes/blucia0a/recon.html
-</RECON HEADER>------------------------------------------------------------*/

#include <pthread.h>

#include <assert.h>

#include <stdlib.h>

#include <stdio.h>

#include "communication_graph.h"

graph_edge **init_graph(){



  graph_edge **graph = (graph_edge **)calloc( NUM_BINS, sizeof(graph_edge*) );

  for(int i = 0; i < NUM_BINS; i++){



    graph[i] = (graph_edge *)calloc( BIN_SIZE, sizeof(graph_edge) );



  }

  return graph;



}



void delete_graph(graph_edge **graph){



  for(int i = 0; i < NUM_BINS; i++){

    free(graph[i]);

  }

  free(graph);



}



void graph_insert(graph_edge**g,

                  unsigned long SrcIAddr, 

                  context_t SrcCtx, 

                  unsigned long SrcTS, 

                  unsigned long SinkIAddr, 

                  context_t SinkCtx, 

                  unsigned long SinkTS){



  unsigned long index = (SrcIAddr ^ SinkIAddr) & 0x1FFF;

  graph_edge *e = NULL;

  for(int i = 0; i < BIN_SIZE; i++){

    e = &(g[index][i]);

    if(e->srcIA != 0){/*not empty -- is it the same?*/

      /*The following conditions see if this edge is
       *the same as the one being added.  If not, keep
       *looking.
      */

      if(e->srcIA != SrcIAddr){

        continue;

      }

      if(e->sinkIA != SinkIAddr){

        continue;

      }

      if(e->srcCtx != SrcCtx){

        continue;

      }

      if(e->sinkCtx != SinkCtx){

        continue;

      }

      /*It was the same! update the time stamps*/
      e->srcTS = SrcTS;

      e->sinkTS = SinkTS;

      return;

    }else{

      /*empty -- means we need to add this one*/
  
      e->srcIA = SrcIAddr;
  
      e->sinkIA = SinkIAddr;
  
      e->srcCtx = SrcCtx;
  
      e->sinkCtx = SinkCtx;
  
      e->srcTS = SrcTS;
  
      e->sinkTS = SinkTS;

    }

    return;

  }

  /*If we reach here, there was not adequate space in the edge table to 
  * collect this edge.  We just give up, in the interest of performance
  */

}



void communicationGraphDump(graph_edge**g,unsigned int thread_id, FILE *f){

  int num = 0;

  json_object * graph_out = json_object_new_object();

  for(int i = 0; i < NUM_BINS; i++){

    for(int j = 0; j < BIN_SIZE; j++){

      if(g[i][j].srcIA != 0){

        graph_edge *e = &(g[i][j]);


        char srcIAC[20];

        char srcTSC[50];


        char sinkIAC[20];

        char sinkTSC[50];


        json_object * edge = json_object_new_object();

        json_object * src = json_object_new_object();

        sprintf(srcIAC,"%ld",e->srcIA);

        json_object * srcIA = json_object_new_string(srcIAC);//e->srcIA & 0xFFFFFFFF);

        json_object * srcCtx= json_object_new_int(e->srcCtx);

        json_object * srcTS;

        

        if(e->srcTS == 0){

          srcTS = json_object_new_string("0");

        }else{

          sprintf(srcTSC,"%lu",e->srcTS);

          srcTS = json_object_new_string(srcTSC);

        }



        json_object_object_add(src,"I", srcIA);

        json_object_object_add(src,"C", srcCtx);

        json_object_object_add(src,"T", srcTS);



        json_object * sink= json_object_new_object();

        sprintf(sinkIAC,"%ld",e->sinkIA);

        json_object * sinkIA = json_object_new_string(sinkIAC);

        json_object * sinkCtx= json_object_new_int(e->sinkCtx);

        json_object * sinkTS;



        if(e->sinkTS == 0){

          sinkTS = json_object_new_string("0");

        }else{

          sprintf(sinkTSC,"%lu",e->sinkTS);

          sinkTS = json_object_new_string(sinkTSC);

        }



        json_object_object_add(sink,"I", sinkIA);

        json_object_object_add(sink,"C", sinkCtx);

        json_object_object_add(sink,"T", sinkTS);



        json_object_object_add(edge,"src", src);

        json_object_object_add(edge,"sink", sink);



        char edn[20] = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};

        sprintf(edn,"e%d",num);

        json_object_object_add(graph_out,edn,edge);



        fprintf (f,"{ \"t%de%d\": %s }\n",thread_id,num,json_object_to_json_string(edge));

        num++;

      }

    }

  }

}

