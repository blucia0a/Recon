#!/bin/bash

source ../.reconrc

#The program to run and args to run with
PROGRAM=../Tests/Crasher/Crasher
PROGRAMARGS=""

#The directory to put graphs.  Relative paths only work if you stay in this dir
GRAPHDIR=../Tests/Crasher/graphs

#The failure detection script.  This command should print a "1" if the program
#has succeeded, and anything else, if it failed.
FAILURETEST=../Tests/Crasher/Crasher_FailureTest.sh

#Export these to the environment so json is loaded, and the graph goes
#where we tell it to.
export RECONGRAPHFILE=$GRAPHDIR/graph

echo $PIN
echo $RECON
echo $PROGRAM
echo $PROGRAMARGS
#Run the ReconCollect command.  Redirect output to .workout/err
$PIN -t $RECON -- $PROGRAM $PROGRAMARGS 2> .workerr > .workout &

#Wait for the command to end
wait

#If $X ends up being "1", the program did not fail.  If $X is anything else, then the program failed
FAILURESTATE=`$FAILURETEST`

#If the program failed, put the graph that was produced in $GRAPHDIR/buggy
#Otherwise put the graph in $GRAPHDIR/nonbuggy
if [ $FAILURESTATE -ne 1 ];
then
  mv "${GRAPHDIR}/${GRAPH}graphE_`basename ${PROGRAM}`0P$!" ${GRAPHDIR}/buggy;
else
  mv "${GRAPHDIR}/${GRAPH}graphE_`basename ${PROGRAM}`0P$!" ${GRAPHDIR}/nonbuggy;
fi
