#!/usr/bin/perl
############################
#Recon  
#
#Written by Brandon Lucia 2010-2011
#at the University of Washington 
##############################################

use warnings;
use strict;
use Getopt::Long;
use Recon;

my %GlobalOptions;
$GlobalOptions{'help'} = 0;

$GlobalOptions{'numgraphs'} = 100;
$GlobalOptions{'numbuggygraphs'} = undef;
$GlobalOptions{'numnonbuggygraphs'} = undef;
$GlobalOptions{'graphsdir'} = '';
$GlobalOptions{'executable'} = '';
$GlobalOptions{'usenonbuggy'} = 1;
$GlobalOptions{'loadcode'} = 1;

$GlobalOptions{'rank'} = 'kitchensink';
$GlobalOptions{'rankthreshold'} = 0;
$GlobalOptions{'removeintersection'} = 0;
$GlobalOptions{'removecoldcontext'} = 0;
$GlobalOptions{'onlyshowmaxforcodepoint'} = 0;

$GlobalOptions{'multidist'} = '';
$GlobalOptions{'numdist'} = 0;
$GlobalOptions{'output'} = 'recons';
$GlobalOptions{'gnuplot'} = '';
$GlobalOptions{'dot'} = '';


$GlobalOptions{'numbuggy'} = 0; 
$GlobalOptions{'numnonbuggy'} = 0; 



&GetOptions( 'graphsdir=s' => \$GlobalOptions{'graphsdir'},
             'executable=s' => \$GlobalOptions{'executable'},
             'numgraphs=i' => \$GlobalOptions{'numgraphs'},
             'rank=s' => \$GlobalOptions{'rank'},
             'output=s' => \$GlobalOptions{'output'},
             'gnuplot=s' => \$GlobalOptions{'gnuplot'},
             'dot=s' => \$GlobalOptions{'dot'},
             'loadcode=i' => \$GlobalOptions{'loadcode'},
             'numbuggy=i' => \$GlobalOptions{'numbuggy'},
             'numnonbuggy=i' => \$GlobalOptions{'numnonbuggy'},
             'help' => \$GlobalOptions{'help'});

if($GlobalOptions{'help'} == 1){
  print 
"
----------------------------------
Recon: The Reconstruction Debugger

by Brandon Lucia 2010-2011
University of Washington

----------------------------------

--------General Options--------
-numgraphs (the maximum number of graphs of each type to load -- this overrides numbuggy and numnonbuggy)

-numbuggy (the maximum number of buggy graphs to load)

-numnonbuggy (the maximum number of buggy graphs to load)

-rank (frequency, or kitchensink.  default is kitchensink.  frequency ranks by buggy run frequency only)

-graphsdir=s (the location of the graphs -- directory should contain a 'buggy' and 'nonbuggy' sub-directory)

-executable=s (the binary used to create the graphs, which hopefully has debug symbols)

-loadcode (should Recon load debug information?)

-help (this message)


--------Output Options--------
-output (graph, recons, featurevectors, dot [requires -dot])

-gnuplot=s (gnuplot output directory [useless without -output=gnuplot])

-dot=s (dot output directory [useless without -output=dot])

\n\n";
exit(0);
}

if(defined $GlobalOptions{'numgraphs'}){
  $GlobalOptions{'numbuggy'} = $GlobalOptions{'numgraphs'}; 
  $GlobalOptions{'numnonbuggy'} = $GlobalOptions{'numgraphs'}; 
}

my $buggy_graphs;
$buggy_graphs = Recon->new();
$buggy_graphs->Executable($GlobalOptions{'executable'});
$buggy_graphs->LoadGraphs($GlobalOptions{'graphsdir'}."/buggy",$GlobalOptions{'numbuggy'},0);

my $nonbuggy_graphs;
$nonbuggy_graphs = Recon->new();
$nonbuggy_graphs->Executable($GlobalOptions{'executable'});
$nonbuggy_graphs->LoadGraphs($GlobalOptions{'graphsdir'}."/nonbuggy",$GlobalOptions{'numnonbuggy'},0);

#Compute All Graph Stats Requested
$buggy_graphs->ComputeEdgesCorrectRunCtxVar($nonbuggy_graphs);
$buggy_graphs->ComputeOtherGraphFrequency($nonbuggy_graphs);
$buggy_graphs->ComputeRank(\&Recon::frequencyRank);
$buggy_graphs->ComputeReconstructions();


#Rank!  You can implement your own if you want to, and call ComputeRank(\&yourFunc);
if($GlobalOptions{'rank'} eq 'frequency'){
  $buggy_graphs->ComputeRank(\&Recon::frequencyRank);
}elsif($GlobalOptions{'rank'} eq 'kitchensink'){
  $buggy_graphs->ComputeRank(\&Recon::kitchenSink);
}

#Post-Rank Pruning
if($GlobalOptions{'onlyshowmaxforcodepoint'} == 1){
  $buggy_graphs->RemoveAllButMaxForCodePoint();
}

if($GlobalOptions{'rankthreshold'} != 0){
  $buggy_graphs->RemoveEdgesBelowThreshold($GlobalOptions{'rankthreshold'}/100);
}

#OUTPUT TECHNIQUES
if($GlobalOptions{'output'} =~ /graph/){
  $buggy_graphs->printGraphSorted('frequency','all');
}elsif($GlobalOptions{'output'} =~ /recons/){
  $buggy_graphs->PrintBuggyOrders();
  #$buggy_graphs->DotPrintBuggyOrders("orders.dot");
}elsif($GlobalOptions{'output'} =~ /featurevectors/){
  $buggy_graphs->PrintFeatureVectors('frequency','order consistency');
}else{
  die "Unknown Output Option! (".$GlobalOptions{'output'}.")\n";
}
