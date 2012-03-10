#!/bin/bash

#these are configurable

#Pin installation
PIN=/sampa/share/pin/PIN/pin

#The program to run (probably don't want to change this)
PROGRAM=Crasher

#The directory to put graphs.  Relative paths only work if you stay in this dir
GRAPHDIR=./graphs

#Export these to the environment so json is loaded, and the graph goes
#where we tell it to.
export LD_LIBRARY_PATH=../../ReconCollect/libs/libjson/inst/lib 
export RECONGRAPHFILE=$GRAPHDIR/graph

#Run the ReconCollect command.  Redirect output to .workout/err
echo "Running $PROGRAM"
$PIN -t ../../ReconCollect/C/recon.so -- ./Crasher 2> .workerr > .workout &
echo "Done Running $PROGRAM"

#Wait for the command to end
wait

#If "Final value was xyz" was printed by the program, it didn't fail.
X=`grep -i Final .workerr .workout | wc -l`

#If the program failed, put the graph that was produced in $GRAPHDIR/buggy
#Otherwise put the graph in $GRAPHDIR/nonbuggy
if [ $X -ne 1 ];
then
  mv "${GRAPHDIR}/${GRAPH}graphE_${PROGRAM}0P$!" ${GRAPHDIR}/buggy;
else
  mv "${GRAPHDIR}/${GRAPH}graphE_${PROGRAM}0P$!" ${GRAPHDIR}/nonbuggy;
fi
