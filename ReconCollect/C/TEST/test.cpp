#include <stdlib.h>
#include <pthread.h>
#include <stdio.h>
#include <ctime>
#include <unistd.h>

#define NUM_THREADS 4

unsigned long *bigArray;
pthread_mutex_t lock;
unsigned long doneCount;

void *concurrent_accesses(void*np){  
  unsigned long tid = *((unsigned long*)(np));
  unsigned long *count = (unsigned long *)malloc(sizeof(unsigned long));
  for(int i = 0; i < 1000; i++){
    unsigned long addr = rand() % 1000; 
    unsigned long pc = rand() % 0xdeadbeff + 0xdeadbeef; 
    unsigned long type = rand() % 2;
    if(type == 0){
      pthread_mutex_lock(&lock);
      unsigned long t = bigArray[addr];
      pthread_mutex_unlock(&lock);
      *count += (t == tid);
    }else{
      pthread_mutex_lock(&lock);
      bigArray[addr] = tid;
      pthread_mutex_unlock(&lock);
    }
  }
  pthread_exit((void*) count);
  return 0;
}


int main(int argc, char** argv){
  srand(time(NULL));

  bigArray = (unsigned long *)malloc(1000*sizeof(unsigned long));

  pthread_t tasks[NUM_THREADS];
  pthread_mutex_init(&lock,NULL);

  for(int i = 0; i < NUM_THREADS; i++){
    pthread_create(&(tasks[i]), NULL, concurrent_accesses, (void*)(new int(i)));
  }
  
  for(int i = 0; i < NUM_THREADS; i++){
    unsigned long *res;
    pthread_join(tasks[i], (void**)&res);
    fprintf(stderr,"Thread %d got %lu\n",i,*res); 
  }

}


