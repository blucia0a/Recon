package Recon;

use warnings;
use strict;

use lib '/sampa/home/blucia/perl/share/perl/5.8.8/';
use utf8;
use ReconUtil;
use Statistics::Descriptive;
use Time::HiRes;
use Tk;
use JSON;

######Constructor
sub new {
  my $class = shift;
  my $self = {};

  $self->{'CPs'} = {};
  $self->{'number of graphs'} = 0;

  $self->{'Graph'} = {};#Src,Sink,SrcCtx,SinkCtx
  $self->{'Pair Graph'} = {};#Src,SrcCtx,Sink,SinkCtx

  $self->{'TS Graph By File'} = {};#->{src}->{sink}->{srcctx}->{sinkctx}->{filename} = (srcts, sinkts) 
                                #if the edge occurred in the graph in that file

  $self->{'Src Sink Context-Obliv Graph'} = {};
  $self->{'Sink Src Context-Obliv Graph'} = {};
  $self->{'Context Count'} = {};

  $self->{'TS Ordered'} = {};#Hash Bucket for each run; Bucket contains time stamp ordered List of All Nodes
  $self->{'Run Times'} = {};#Hash Bucket for each run; Bucket contains runtime (in ticks) of run 
  $self->{'Recons'} = {};#Reconstructions of the events that preceded the source and sink of a communication event

  $self->{'Intervening'} = {};#->{Edge}->{Node} = # of Runs in which Node happened between Edge.Src and Edge.Sink in Time
  
  $self->{'executable'} = '';
  bless($self);
  return $self;
}
#------------------------------

#***********************************************
#General Graph Stuff (setup, loading, accessors)
#***********************************************
######Set the executable field
sub Executable(){
  my $graph = shift;
  if($#_ >= 0){
    $graph->{'executable'} = $_[0];
  }
  return $graph->{'executable'};
}
#------------------------------


######Graph Creation/Loading stuff 
sub GetNextEdgeFromFile(){

  my $graph = shift;
  my $FILE = shift;
  my $java = shift;

#  if($java == 1){
#
#    my $srcLine = '';
#    $srcLine = readline($FILE);
#    
#    if(!defined $srcLine || ($java == 1 && $srcLine =~ /Size of Graph/)){
#      return undef;
#    }
#  
#  
#    
#    $srcLine =~ s/\]//;
#    $srcLine =~ s/\[//;
#    $srcLine =~ s/Source:/Source/;
#    $srcLine =~ s/\(//;
#    $srcLine =~ s/\)//;
#    my ($srcjunk,$srcpc,$srcts,@srccontext) = split /\s+/, $srcLine;
#    if($java == 1){
#      my $codepoint = pop @srccontext;
#      my ($file,$line) = split /:/, $codepoint;
#      $graph->{'code'}->{$srcpc}->{'file'} = $file;
#      $graph->{'code'}->{$srcpc}->{'line'} = $line;
#      $graph->{'code'}->{$srcpc}->{'func'} = "unknown";
#    }
#    my $srcctx = join '',@srccontext;
#    
#    
#    my $sinkLine = readline($FILE);
#    if(!defined $sinkLine){
#      return undef;
#    }
#  
#   
#    $sinkLine =~ s/\]//;
#    $sinkLine =~ s/\[//;
#    $sinkLine =~ s/Sink:/Sink/;
#    $sinkLine =~ s/\(//;
#    $sinkLine =~ s/\)//;
#    #$sinkLine =~ s/Sink :/Sink/;
#    my ($sinkjunk,$sinkpc,$sinkts,@sinkcontext) = split /\s+/, $sinkLine;
#    if($java == 1){
#      my $codepoint = pop @sinkcontext;
#      my ($file,$line) = split /:/, $codepoint;
#      $graph->{'code'}->{$sinkpc}->{'file'} = $file;
#      $graph->{'code'}->{$sinkpc}->{'line'} = $line;
#      $graph->{'code'}->{$sinkpc}->{'func'} = "unknown";
#    }
#    my $sinkctx = join '',@sinkcontext;
#   
#    my $edge = { 'src' => $srcpc,
#                 'sink' => $sinkpc,
#                 'srcctx' => $srcctx,
#                 'sinkctx' => $sinkctx,
#                 'srcts' => $srcts,
#                 'sinkts' => $sinkts
#               };
#    return $edge;
#  }else{

    #NOT JAVA
    my $line = readline($FILE);
    if(!defined $line || !($line =~ m/src/) ){
      return;
    }
    utf8::upgrade($line);
    
    my $eref = decode_json $line;
    my $edge;
    my $k;
    foreach $k(keys %{$eref}){
      my $hsrc  = sprintf("%x",$eref->{$k}->{"src"}->{"I"});
      my $hsink = sprintf("%x",$eref->{$k}->{"sink"}->{"I"});
      $edge = { 'src' => $hsrc,
                'sink' => $hsink,
                'srcctx' => $eref->{$k}->{"src"}->{"C"},
                'sinkctx' => $eref->{$k}->{"sink"}->{"C"},
                'srcts' => $eref->{$k}->{"src"}->{"T"},
                'sinkts' => $eref->{$k}->{"sink"}->{"T"}
              };

      if( defined $eref->{$k}->{"srcinfo"} ){

        my $thisid = $eref->{$k}->{"srcinfo"}->{"id"};
        my $thisfileline = $eref->{$k}->{"srcinfo"}->{"code"};

        my ($thisfile,$thisline) = split /:/, $thisfileline;
        $graph->{'code'}->{$thisid}->{'file'} = $thisfile;
        $graph->{'code'}->{$thisid}->{'line'} = $thisline;

      }

      if( defined $eref->{$k}->{"sinkinfo"} ){

        my $thisid = $eref->{$k}->{"sinkinfo"}->{"id"};
        my $thisfileline = $eref->{$k}->{"sinkinfo"}->{"code"};

        my ($thisfile,$thisline) = split /:/, $thisfileline;
        $graph->{'code'}->{$thisid}->{'file'} = $thisfile;
        $graph->{'code'}->{$thisid}->{'line'} = $thisline;

      }

    } 

    return $edge;
#  }

}

sub CheapLoadGraphs($$$$){
  my $graph = shift;
  my $dirname = shift;
  my $maxgraphs = shift;
  my $java = shift;

  #print "LOADING JAVA GRAPHS=$java\n";

  if(!defined $maxgraphs){
    $maxgraphs = 999999999;#infinitely many
  }

  if($maxgraphs == 999999999){
    warn ">>Reading All Graphs From $dirname<<\n";
  }else{
    warn ">>Reading $maxgraphs Graphs From $dirname<<\n";
  }
  my $DIR;
  my $err = 0;
  opendir $DIR,$dirname or $err = 1;
  if($err == 1){
    warn "Couldn't open directory \"$dirname\"\n";
    return;
  }
  my @files = readdir($DIR);
  closedir($DIR);
  my $file;
  my $count = 0;
  my $start = [Time::HiRes::gettimeofday()];
  foreach $file(@files){
    next if $file eq qw{.} or $file eq qw{..};
    #print "Loading Graph #$count";

    $graph->CheapLoadGraph("$dirname/$file",$java);

    #print " ($elapsed seconds)\n";
    $count++;
    last if $graph->{'number of graphs'} >= $maxgraphs;
  }
  my $elapsed = Time::HiRes::tv_interval($start);
  warn "Loaded $count graphs in $elapsed seconds\n";
}

sub LoadGraphs($$$$){
  my $graph = shift;
  my $dirname = shift;
  my $maxgraphs = shift;
  my $java = shift;


  if(!defined $maxgraphs){
    $maxgraphs = 999999999;#infinitely many
  }

  if($maxgraphs == 999999999){
    warn ">>Reading All Graphs From $dirname<<\n";
  }else{
    warn ">>Reading $maxgraphs Graphs From $dirname<<\n";
  }

  my $DIR;
  my $err = 0;
  opendir $DIR,$dirname or $err = 1;
  if($err == 1){
    warn "Couldn't open directory \"$dirname\"\n";
    return;
  }

  my @files = readdir($DIR);
  closedir($DIR);

  my $file;
  my $count = 0;
  my $start = [Time::HiRes::gettimeofday()];
  foreach $file(@files){
    next if $file eq qw{.} or $file eq qw{..};
    #print "Loading Graph #$count";

    $graph->LoadGraph("$dirname/$file",$java);

    #print " ($elapsed seconds)\n";
    $count++;
    last if $graph->{'number of graphs'} >= $maxgraphs;
  }
  my $elapsed = Time::HiRes::tv_interval($start);
  warn "Loaded $count graphs in $elapsed seconds\n";
}

sub CheapLoadGraph(){
  
  my $graph = shift;
  my $filename = shift;
  my $java = shift;


  my $FILE;
  my $err = 0;
  open($FILE,$filename) or $err = 1;
  if($err == 1){
    warn "$!: $filename\n";
    return;
  }

  #First line is like "Runtime 123456"
  #my $timelinelines = 0;
  my $timeLine = '';
  if($java == 0){
    $timeLine = readline($FILE);
    if(!defined $timeLine){
      warn "Bad Timestamp: $filename\n";
      return;
    }
  }else{
    $timeLine = "RUNTIME 10000000000000";
  }
  my ($junk,$time) = split /\s+/, $timeLine;
  $graph->{'Run Times'}->{$filename} = $time;
 
  my $edgesadded = 0; 
  warn $filename."\n";
  $graph->{'loading'} = {};
  while(my $edge = $graph->GetNextEdgeFromFile($FILE,$java)){
    if(defined $edge){
      $graph->CheapAddEdge($edge->{'src'},$edge->{'sink'},$edge->{'srcctx'},$edge->{'sinkctx'},undef);
    }

    $edgesadded++;
  }
  $graph->{'loading'} = undef;

  if($edgesadded > 0){ 
    if(defined $graph->{'number of graphs'}){
      $graph->{'number of graphs'}++;
    }else{
      $graph->{'number of graphs'} = 1;
    }
  }
}

sub LoadGraph(){
  
  my $graph = shift;
  my $filename = shift;
  my $java = shift;


  my $FILE;
  my $err = 0;
  open($FILE,$filename) or $err = 1;
  if($err == 1){
    warn "$!: $filename\n";
    return;
  }

  #First line is like "Runtime 123456"
  #my $timelinelines = 0;
  my $timeLine = '';
  if($java == 0){
    $timeLine = readline($FILE);
    if(!defined $timeLine){
      warn "Bad Timestamp: $filename\n";
      return;
    }
  }else{
    $timeLine = "RUNTIME 10000000000000";
  }

  my ($junk,$time) = split /\s+/, $timeLine;
  $graph->{'Run Times'}->{$filename} = $time;
 
  my $edgesadded = 0; 
  warn $filename."\n";
  $graph->{'loading'} = {};
  while(my $edge = $graph->GetNextEdgeFromFile($FILE,$java)){

    $graph->AddEdge($edge->{'src'},$edge->{'sink'},$edge->{'srcctx'},$edge->{'sinkctx'},undef);

    #The Timestamp indexed graph
    if(!defined $edge->{'srcts'}){$edge->{'srcts'} = 0;}
    if(!defined $edge->{'sinkts'}){$edge->{'sinkts'} = 0;}
    push @{$graph->{'TS Ordered'}->{$filename}}, $edge->{'src'}.":".$edge->{'srcctx'}.":".$edge->{'srcts'};
    push @{$graph->{'TS Ordered'}->{$filename}}, $edge->{'sink'}.":".$edge->{'sinkctx'}.":".$edge->{'sinkts'};

    #Edges indexed by filename 
    $graph->{'TS Graph By File'}->
            {$edge->{'src'}}->
            {$edge->{'sink'}}->
            {$edge->{'srcctx'}}->
            {$edge->{'sinkctx'}}->
            {$filename} = 
            $edge->{'srcts'}.":".$edge->{'sinkts'};

    $edgesadded++;
  }
  $graph->{'loading'} = undef;

  if($edgesadded > 0){ 
    if(defined $graph->{'number of graphs'}){
      $graph->{'number of graphs'}++;
    }else{
      $graph->{'number of graphs'} = 1;
    }
    #Gotta sort the TS Ordered Array
    my @s = sort { my ($pca,$ctxa,$tsa) = split /:/, $a; 
                   my ($pcb,$ctxb,$tsb) = split /:/, $b; 
                   return $tsa <=> $tsb;  
                 } @{$graph->{'TS Ordered'}->{$filename}};
    $graph->{'TS Ordered'}->{$filename} = [];
    push @{$graph->{'TS Ordered'}->{$filename}}, @s;
  }
}
#---------------------------------------



######Graph manipulation stuff
sub GetEdge(){
  my ($graph,$src,$sink,$srcctx,$sinkctx) = @_;
  if(defined $graph->{'Graph'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}){
    return $graph->{'Graph'}->{$src}->{$sink}->{$srcctx}->{$sinkctx};
  }else{
    return undef;
  }
}

sub RemoveEdge(){
  my ($graph,$src,$sink,$srcctx,$sinkctx) = @_;
  #Delete from the graph, and update all the indexing structures to reflect
  #the deletion
  delete $graph->{'EdgeKeys'}->{"$src:$sink:$srcctx:$sinkctx"};
  
  $graph->{'Context Count'}->{$src}->{$sink}--;
  delete $graph->{'Graph'}->{$src}->{$sink}->{$srcctx}->{$sinkctx};
  if(scalar keys %{$graph->{'Graph'}->{$src}->{$sink}->{$srcctx}} == 0){
    delete $graph->{'Graph'}->{$src}->{$sink}->{$srcctx};
  }

  if(scalar keys %{$graph->{'Graph'}->{$src}->{$sink}} == 0){
    delete $graph->{'Graph'}->{$src}->{$sink};
    delete $graph->{'Src Sink Context-Obliv Graph'}->{$src}->{$sink};
    delete $graph->{'Sink Src Context-Obliv Graph'}->{$sink}->{$src};
    delete $graph->{'Context Count'}->{$src}->{$sink};
  }
  
  if(scalar keys %{$graph->{'Graph'}->{$src}} == 0){
    delete $graph->{'Graph'}->{$src};
    delete $graph->{'Src Sink Context-Obliv Graph'}->{$src};
    delete $graph->{'Context Count'}->{$src};
    foreach(keys %{$graph->{'Sink Src Context-Obliv Graph'}}){
      if(exists $graph->{'Sink Src Context-Obliv Graph'}->{$sink}->{$src}){
        delete $graph->{'Sink Src Context-Obliv Graph'}->{$sink}->{$src};
      }
    }
  }

  return;
}

sub CheapAddEdge(){
  my ($graph,$src,$sink,$srcctx,$sinkctx,$val) = @_;
  if(!defined $graph->{'loading'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}){
    $graph->{'loading'}->{$src}->{$sink}->{$srcctx}->{$sinkctx} = 1;
  }else{
    return;#one instance per graph file
  }
  if(!defined $val){ $val = 1; }

  #The Graph
  if(defined $graph->{'Graph'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}){
    $graph->{'Graph'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'frequency'} += $val;
  }else{
    $graph->{'Graph'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'frequency'} = $val;
  }
}

sub AddEdge(){
  my ($graph,$src,$sink,$srcctx,$sinkctx,$val) = @_;
  if(!defined $graph->{'loading'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}){
    $graph->{'loading'}->{$src}->{$sink}->{$srcctx}->{$sinkctx} = 1;
  }else{
    return;#one instance per graph file
  }

  #Every code point we ever see
  $graph->{'CPs'}->{$sink} = undef;
  $graph->{'CPs'}->{$src} = undef;

  if(!defined $val){
    $val = 1;
  }

  #The Graph
  if(defined $graph->{'Graph'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}){
    $graph->{'Graph'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'frequency'} += $val;
  }else{
    $graph->{'Graph'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'frequency'} = $val;
    $graph->{'Graph'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'Avg Span'} = 0;#To be filled in later
    
    #the context count index -- for each unique edge, increment ctx count
    if(!defined $graph->{'Context Count'}->{$src}->{$sink}){
      $graph->{'Context Count'}->{$src}->{$sink} = 1;
    }else{
      $graph->{'Context Count'}->{$src}->{$sink} ++;
    }
  }

  #Keys are precomputed to make sorting faster (see applyFuncToSortedGraph)
  $graph->{'EdgeKeys'}->{"$src:$sink:$srcctx:$sinkctx"} = undef;

  #the forward indexed context oblivious graph
  if(!defined $graph->{'Src Sink Context-Obliv Graph'}->{$src}->{$sink}){
    $graph->{'Src Sink Context-Obliv Graph'}->{$src}->{$sink} = $val;
  }else{
    $graph->{'Src Sink Context-Obliv Graph'}->{$src}->{$sink} += $val;
  }

  #the backward indexed context oblivious graph
  if(!defined $graph->{'Sink Src Context-Obliv Graph'}->{$sink}->{$src}){
    $graph->{'Sink Src Context-Obliv Graph'}->{$sink}->{$src} = $val;
  }else{
    $graph->{'Sink Src Context-Obliv Graph'}->{$sink}->{$src} += $val;
  }

  #the src/srcctx ---> sink/sinkctx fwd indexed context-aware graph
  if(!defined $graph->{'Pair Graph'}->{$src}->{$srcctx}->{$sink}->{$sinkctx}){
    $graph->{'Pair Graph'}->{$src}->{$srcctx}->{$sink}->{$sinkctx} = $val;
  }else{
    $graph->{'Pair Graph'}->{$src}->{$srcctx}->{$sink}->{$sinkctx} += $val;
  }
}
#---------------------------------------


######Edge Properties
sub CorrectRunSinkCPVar(){
  my $graph = shift;
  my $src = shift;
  my $sink = shift;
  my $srcctx = shift;
  my $sinkctx = shift;
  my $newval;
  if($#_ >= 0){
    $newval = shift;
    $graph->GetEdge($src,$sink,$srcctx,$sinkctx)->{'correct run sinkcp var'} = $newval;
  }
  
  if($graph->GetEdge($src,$sink,$srcctx,$sinkctx)->{'correct run sinkcp var'}){
    return $graph->GetEdge($src,$sink,$srcctx,$sinkctx)->{'correct run sinkcp var'}
  }else{
    return undef;
  }
}
#--------------------------------

sub CorrectRunSrcCPVar(){
  my $graph = shift;
  my $src = shift;
  my $sink = shift;
  my $srcctx = shift;
  my $sinkctx = shift;
  my $newval;
  if($#_ >= 0){
    $newval = shift;
    $graph->GetEdge($src,$sink,$srcctx,$sinkctx)->{'correct run srccp var'} = $newval;
  }
  
  if($graph->GetEdge($src,$sink,$srcctx,$sinkctx)->{'correct run srccp var'}){
    return $graph->GetEdge($src,$sink,$srcctx,$sinkctx)->{'correct run srccp var'}
  }else{
    return undef;
  }
}
#--------------------------------

sub CorrectRunCtxVar(){
  my $graph = shift;
  my $src = shift;
  my $sink = shift;
  my $srcctx = shift;
  my $sinkctx = shift;
  my $newval;
  if($#_ >= 0){
    $newval = shift;
    $graph->GetEdge($src,$sink,$srcctx,$sinkctx)->{'correct run ctx var'} = $newval;
  }
  
  if($graph->GetEdge($src,$sink,$srcctx,$sinkctx)->{'correct run ctx var'}){
    return $graph->GetEdge($src,$sink,$srcctx,$sinkctx)->{'correct run ctx var'}
  }else{
    return undef;
  }
}
#--------------------------------


######Get Code related stuff
sub codeInfoIfAvailable_short(){
  my $graph = shift;
  my $pc = shift;

  if(!defined $graph->{'code'}->{$pc}->{'file'}){
    my ($func,$file,$line) = ReconUtil::addr2lineCall($graph->{'executable'},$pc); 
    $graph->{'code'}->{$pc}->{'func'} = $func;
    my $sfile = `basename $file`;
    chomp $sfile;
    $graph->{'code'}->{$pc}->{'file'} = $sfile;
    $graph->{'code'}->{$pc}->{'line'} = $line;
  }

  if($graph->{'code'}->{$pc}->{'file'} =~ /\?\?/){
    $pc =~ s/^0x0+//;
    return "P$pc";
  }

  my $base = `basename $graph->{'code'}->{$pc}->{'file'}`;
  chomp $base;
  $base =~ s/\.//g;
  $base =~ s/\]//g;
  $base =~ s/\[//g;
  $base =~ s/_//g;
  $base =~ s/-//g;
  return substr($base,0,10).$graph->{'code'}->{$pc}->{'line'}; 


}

sub codeInfoIfAvailable(){

  my $graph = shift;
  my $pc = shift;


  if(!defined $graph->{'code'}->{$pc}->{'file'}){

    if($graph->{'executable'} eq ""){

      $graph->{'code'}->{$pc}->{'file'} = "Unkown Location";
      $graph->{'code'}->{$pc}->{'line'} = 0;

    }else{

      my ($func,$file,$line) = ReconUtil::addr2lineCall($graph->{'executable'},$pc); 
      $graph->{'code'}->{$pc}->{'func'} = $func;
      my $sfile = `basename $file`;
      chomp $sfile;
      $graph->{'code'}->{$pc}->{'file'} = $sfile;
      $graph->{'code'}->{$pc}->{'line'} = $line;

    }

  }

  if($graph->{'code'}->{$pc}->{'file'} =~ /\?\?/){
    return $pc;
  }

  my $base = `basename $graph->{'code'}->{$pc}->{'file'}`;
  chomp $base;
  return "$base:".$graph->{'code'}->{$pc}->{'line'}; 
}

sub getCodeForEdge(){
  my $graph = shift;
  my $src = shift;
  my $sink = shift;
  my $srcctx = shift;
  my $sinkctx = shift;
  my $val = shift;

  if(!defined $graph->{'code'}->{$src}){
    my ($func,$file,$line) = ReconUtil::addr2lineCall($graph->{'executable'},$src); 
    $graph->{'code'}->{$src}->{'func'} = $func;
    my $sfile = `basename $file`;
    chomp $sfile;
    $graph->{'code'}->{$src}->{'file'} = $sfile;
    $graph->{'code'}->{$src}->{'line'} = $line;
  }

  if(!defined $graph->{'code'}->{$sink}){
    my ($func,$file,$line) = ReconUtil::addr2lineCall($graph->{'executable'},$sink); 
    $graph->{'code'}->{$sink}->{'func'} = $func;
    my $sfile = `basename $file`;
    chomp $sfile;
    $graph->{'code'}->{$sink}->{'file'} = $sfile;
    $graph->{'code'}->{$sink}->{'line'} = $line;
  }
}

sub LoadCode(){
  my $graph = shift;
  
  my $start = [Time::HiRes::gettimeofday()];
  warn "Loading Code...";

  $graph->applyFuncToGraph(\&getCodeForEdge);

  my $elapsed = Time::HiRes::tv_interval($start);
  warn " Done! ($elapsed seconds)\n";

  return;
}
#---------------------------------------


#*****************************************
#Non-Edge Traversal Passes
#*****************************************
#TODO:Make this function less ad hoc
sub printAnomalousInterventions(){
  my $graph = shift;
  my $otherGraph = shift;

  #ORDER ANOMALY DETECTION
  #This function takes a two graphs, and looks for big differences 
  #in the pattern of nodes that interleaves the src and sink
  #of each edge.
  #
  #Given two graphs, G and O: for each edge E=s,d in G:
  #  for each node n that intervenes between s and d in any run,
  #    if the number of runs in which n interleaves s and d in G
  #    is far more or far fewer than the number of runs in which 
  #    n interleaves s and d in O, then give (s,n,d) a high score

  my $res = {};
  my $gSrc;
  my $gSink;
  my $gInt;
  foreach $gSrc(keys %{$graph->{'Intervening'}}){
    foreach $gSink(keys %{$graph->{'Intervening'}->{$gSrc}}){
      foreach $gInt(keys %{$graph->{'Intervening'}->{$gSrc}->{$gSink}}){
        my $diff;
       
        #Need to normalize each count to make the numbers be between 0 and 1
        if(defined $otherGraph->{'Intervening'}->{$gSrc}->{$gSink}->{$gInt}){
          $diff = abs( ($otherGraph->{'Intervening'}->{$gSrc}->{$gSink}->{$gInt}/$otherGraph->{'number of graphs'}) - 
                       (     $graph->{'Intervening'}->{$gSrc}->{$gSink}->{$gInt}/     $graph->{'number of graphs'}) );
        }else{
          $diff = $graph->{'Intervening'}->{$gSrc}->{$gSink}->{$gInt}/$graph->{'number of graphs'};
        }
        $res->{"$gSrc:$gSink:$gInt"} = $diff;
      }
    }
  }

  
  #Hash from context oblivious edge to Stat::Desc object that will be the avg of 
  #the runtimes of the context-aware versions of the edge
  my $CO_EdgeTimeAvgs = {};
  $graph->applyFuncToGraph(\&addEdgeToStatsHash,$CO_EdgeTimeAvgs);

  #res has keys which are like "s:d:n" -- s is a src, d is a sink, and n is an
  #intervener.  The values in these keys are the differences in the number of
  #runs in which that intervention took place between graph and otherGraph
  my @sortedInterventionKeys = 
  sort {
         my ($asrc,$asink,$aint) = split /:/, $a;
         my ($bsrc,$bsink,$bint) = split /:/, $b;
         my $atime = $CO_EdgeTimeAvgs->{$asrc}->{$asink}->mean(); 
         my $btime = $CO_EdgeTimeAvgs->{$bsrc}->{$bsink}->mean(); 
          
         #Interleavings are ranked high if:
         #1)There is high occurrence of the interleaving in buggy runs, but low in nonbuggy
         #
         #2)The timespan between src and sink is small -- this is important; tiny windows
         #  are more typically buggy, so we square 1-timespan to give VERY high rank to
         #  interleavings that are unlikely to occur at all
         return (((1-$btime)**2)*$res->{$b}) <=> (((1-$atime)**2)*$res->{$a});

       } keys %{$res};
  
  foreach(@sortedInterventionKeys){
    my ($src,$sink,$int) = split /:/, $_;
    my $omt = 1-$CO_EdgeTimeAvgs->{$src}->{$sink}->mean();
    my $omt_sq = $omt**2;
    print "----Rank ((1-Span)^2) * Var:".($omt_sq)*$res->{$_}." Var: ".$res->{$_}." Span: ".$CO_EdgeTimeAvgs->{$src}->{$sink}->mean()."----\n";
    print "Src: ".$graph->codeInfoIfAvailable($src)."\n"; 
    print "Snk: ".$graph->codeInfoIfAvailable($sink)."\n"; 
    print "Int: ".$graph->codeInfoIfAvailable($int)."\n\n"; 
  }

}

sub addEdgeToStatsHash(){
  my ($graph,$src,$sink,$srcctx,$sinkctx,$val,$statshash) = @_;
  if(!defined $statshash->{$src}->{$sink}){
    $statshash->{$src}->{$sink} = Statistics::Descriptive::Full->new();
  }
  $statshash->{$src}->{$sink}->add_data($graph->{'Graph'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'Avg Span'});
}

#*****************************************
#Passes Over The Graph (actual traversals)
#*****************************************
######Print Graph/Print Graph Sorted Stuff
sub printEdge(){
  my $graph = shift;
  my $src = shift;
  my $sink = shift;
  my $srcctx = shift;
  my $sinkctx = shift;
  my $val = shift;


  printf "".($graph->codeInfoIfAvailable($src))."[$srcctx]--->".($graph->codeInfoIfAvailable($sink))."[$sinkctx]: %.4f\n", $val;

}

sub printGraph(){
  my $graph = shift;
  $graph->applyFuncToGraph(\&printEdge);
}

sub printGraphSorted(){
  my $graph = shift;
  my $sortParam = shift;
  $graph->applyFuncToSortedGraph(\&printEdge);
}
#---------------------------------------


######Compute buggy frequency ratio for each edge in the graph 
sub computeOtherGraphFrequencyForEdge(){
  my ($graph,$src,$sink,$srcctx,$sinkctx,$val,$otherGraph) = @_;
  if(defined $otherGraph->GetEdge($src,$sink,$srcctx,$sinkctx)){
    $graph->GetEdge($src,$sink,$srcctx,$sinkctx)->{'other freq'} =
      $otherGraph->GetEdge($src,$sink,$srcctx,$sinkctx)->{'frequency'};
  }else{
    $graph->GetEdge($src,$sink,$srcctx,$sinkctx)->{'other freq'} =
      1 / ($otherGraph->{'number of graphs'} + 1);#make it super tiny -- less than 1 run -- effectively 0
  }
}

sub ComputeOtherGraphFrequency(){
  my $graph = shift;
  my $otherGraph = shift;
  $graph->applyFuncToGraph(\&computeOtherGraphFrequencyForEdge,$otherGraph);
  return;
}
#---------------------------------------


######Remove all but max for code point stuff -- can't do this till 'rank' is defined for each edge
sub removeIfSeen(){
  my ($graph,$src,$sink,$srcctx,$sinkctx,$val,$seen) = @_;
  if(defined $seen->{$src}->{$sink}){
    $graph->RemoveEdge($src,$sink,$srcctx,$sinkctx);
  }
  $seen->{$src}->{$sink} = $val;
}

sub RemoveAllButMaxForCodePoint(){
  my $graph = shift;
  my %seen = ();
  $graph->applyFuncToSortedGraph(\&removeIfSeen,\%seen);
}
#---------------------------------------

######Sample Rank Function -- Frequency
sub frequencyRank(){
  my ($graph,$src,$sink,$srcctx,$sinkctx,$val) = @_;
  $graph->{'Graph'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'rank'} = 
    $graph->{'Graph'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'frequency'}/
     $graph->{'Graph'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'other freq'};
}
#--------------------------------------

######Basic Rank Function -- sqrt(B*B + C*C + R*R)
sub kitchenSink(){
  my ($graph,$src,$sink,$srcctx,$sinkctx) = @_;

  if(!defined $graph->{'Graph'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'order consistency'}){

    #We only reconstruct the top 2000 B-ranked edges.  If order consistency is undefined
    #This reconstruction gets rank = 0 because it doesn't exist!
     
    $graph->{'Graph'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'rank'} = 0;
    return;
  }

  my $b = 
    $graph->{'Graph'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'frequency'}/
    $graph->{'Graph'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'other freq'};

  my $c = 
    $graph->{'Graph'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'correct run ctx var'};

  my $r = 
    $graph->{'Graph'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'order consistency'};

  $graph->{'Graph'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'rank'} = 
    sqrt($b*$b + $c*$c + $r*$r);
 
}
#--------------------------------------


######Compute Rank Function
sub ComputeRank(){
  my $graph = shift;
  my $func = shift;

  $graph->applyFuncToGraph($func);

}
#--------------------------

######Compute the context-anomalousness of a graph's edges
sub computeEdgeCorrectRunCPVar(){

  my ($graph,$src,$sink,$srcctx,$sinkctx,$freq,$correctGraph,$srcmemo,$sinkmemo) = @_;

  #There are two things;
  #1)How often, in correct runs, does this sink get its data from this source -
  #  If never or rarely, then this is more likely an anomaly
  #
  #2)How much variance is there in who gives data to this sink?  If there are 
  #  lots of sources and each edge with those sources and this sink has about 
  #  the same value, then this edge could just be nondeterminism
  #
  #CAN WE COMBINE THESE THINGS?
  if(defined $correctGraph->{'Sink Src Context-Obliv Graph'}->{$sink}){
    my $freqSrcSinkEdgesInCorrectObliv = $correctGraph->{'Sink Src Context-Obliv Graph'}->{$sink}->{$src};
    my $allSinkEdgesInCorrectObliv = 0;
    foreach(keys %{$correctGraph->{'Sink Src Context-Obliv Graph'}->{$sink}}){
      $allSinkEdgesInCorrectObliv += $correctGraph->{'Sink Src Context-Obliv Graph'}->{$sink}->{$_};
    }
    my $var = ($freqSrcSinkEdgesInCorrectObliv / $allSinkEdgesInCorrectObliv );

    $graph->CorrectRunSrcCPVar($src,$sink,$srcctx,$sinkctx,$var);
  }else{
    $graph->CorrectRunSrcCPVar($src,$sink,$srcctx,$sinkctx,0);
  }
  
  if(defined $correctGraph->{'Src Sink Context-Obliv Graph'}->{$src}){
    my $freqSrcSinkEdgesInCorrectObliv = $correctGraph->{'Src Sink Context-Obliv Graph'}->{$src}->{$sink};
    my $allSrcEdgesInCorrectObliv = 0;
    foreach(keys %{$correctGraph->{'Src Sink Context-Obliv Graph'}->{$src}}){
      $allSrcEdgesInCorrectObliv += $correctGraph->{'Src Sink Context-Obliv Graph'}->{$src}->{$_};
    }
    my $var = ($freqSrcSinkEdgesInCorrectObliv / $allSrcEdgesInCorrectObliv );

    $graph->CorrectRunSinkCPVar($src,$sink,$srcctx,$sinkctx,$var);
  }else{
    $graph->CorrectRunSinkCPVar($src,$sink,$srcctx,$sinkctx,0);
  }


}

sub ComputeEdgesCorrectRunCPVar(){

  my $graph = shift;
  my $correctGraph = shift;
  my $srcmemo = {};
  my $sinkmemo = {};

  $graph->applyFuncToGraph(\&computeEdgeCorrectRunCPVar,$correctGraph,$srcmemo,$sinkmemo);
}



######Compute the context-anomalousness of a graph's edges
sub computeEdgeCorrectRunCtxVar(){

  my ($graph,$src,$sink,$srcctx,$sinkctx,$val,$correctGraph,$memo) = @_;

  if(exists $correctGraph->{'Context Count'}->{$src}->{$sink}){

    $graph->CorrectRunCtxVar($src,$sink,$srcctx,$sinkctx,abs($graph->{'Context Count'}->{$src}->{$sink}-$correctGraph->{'Context Count'}->{$src}->{$sink})/($graph->{'Context Count'}->{$src}->{$sink}+$correctGraph->{'Context Count'}->{$src}->{$sink}));
    

    #$graph->CorrectRunCtxVar($src,$sink,$srcctx,$sinkctx,abs($graph->{'Context Count'}->{$src}->{$sink} - $correctGraph->{'Context Count'}->{$src}->{$sink})/($correctGraph->{'Context Count'}->{$src}->{$sink} + $graph->{'Context Count'}->{$src}->{$sink}));

  }else{

    $graph->CorrectRunCtxVar($src,$sink,$srcctx,$sinkctx,1);

  }

}

sub ComputeEdgesCorrectRunCtxVar(){

  my $graph = shift;
  my $correctGraph = shift;
  my $memo = {};

  $graph->applyFuncToGraph(\&computeEdgeCorrectRunCtxVar,$correctGraph,$memo);
}
#---------------------------------------

sub printOrderedNodesSet(){
  my ($graph,$src,$sink,$srcctx,$sinkctx,$val) = @_;
  my $run;
  foreach $run(keys %{$graph->{'TS Ordered'}}){
    my $es;
    for($es = 0; $es <= $#{$graph->{'TS Ordered'}->{$run}}; $es++){
      print $graph->{'TS Ordered'}->{$run}->[$es]."\n";  
    }
  }
}

sub computeReconstructionForEdge(){
  my ($graph,$src,$sink,$srcctx,$sinkctx,$val,$numEdges) = @_;

  $$numEdges++;
  if($$numEdges > 200){
    return;
  }

  #assumes $graph->{TS Ordered}->{run} is a reference to a sorted array
  #The array contains the timestamp ordered events from run $run
  my $run;
  foreach $run(keys %{$graph->{'TS Ordered'}}){
    #the value of this is "srcTS:sinkTS" if src[srcctx]-->sink[sinkctx] 
    #occurred in run $run, and undef otherwise
    next if(!defined $graph->{'TS Graph By File'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{$run});
   
    #Get the timestamps out 
    my ($thisRunSrcTS,$thisRunSinkTS) = 
      split /:/, $graph->{'TS Graph By File'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{$run};

    #Find the Source in the TS Ordered List for this run
    my $es;#<--iterator
    my $srcIndex;#<--The entry in the TS ordered list that is the src of the edge

    for($es = 0; $es <= $#{$graph->{'TS Ordered'}->{$run}}; $es++){
      my ($inodepc,$inodectx,$inodets) = split /:/, $graph->{'TS Ordered'}->{$run}->[$es];
      if ($inodepc eq $src && 
          $inodectx eq $srcctx && 
          $inodets eq $thisRunSrcTS){
          $srcIndex = $es;  #If all properties of the entry match, then this entry is the src
          last;
      }
    } 

    #We want to look back from the src by
    #<ctxlength> events -- these are the events
    #that have an influence on the context directly
    my $ctx = $srcctx;
    $ctx =~ s/\[//;
    $ctx =~ s/\]//;
    my $ctxlen = length($ctx);

    #rewind the iterator to start at the first thing
    #that could be in the context
    $es -= $ctxlen;

    #We're trying to find the index of the thing in the TS order that is
    #ctxlength events past the index of the sink of the edge.  That is "endEs"
    my $endEs = $#{$graph->{'TS Ordered'}->{$run}};#<---Last event we consider in the order
    my $sinkIndex = $endEs;#<---The index of the sink in the order
    my $thisRunEvents = {};#<---The set of events we've seen from this run, to be sure we don't double count

    #Find the Sink to that source in the TS Ordered List, 
    #incrementing the count for all nodes between -- they intervene
    for(; $es <= $#{$graph->{'TS Ordered'}->{$run}}; $es++){
      my ($inodepc,$inodectx,$inodets) = split /:/, $graph->{'TS Ordered'}->{$run}->[$es];
      if ($inodepc  eq $sink && 
          $inodectx eq $sinkctx &&
          $inodets  eq $thisRunSinkTS){
        $sinkIndex = $es;#We found the index of the sink!
        $endEs = $es + $ctxlen; #We look ctxlen events past the sink, to include all things in its "sphere of context influence"
      }

      #Meanwhile, we need to add the events Before, Between, and After the edge we're reconstructing for
      if($es < $srcIndex){#<---This means we're before the src
        next if(defined $thisRunEvents->{'Before'}->{"$inodepc [$inodectx]"});#<--Don't look at events twice (IS POSSIBLE?)
        
        #Here is where we actually add this event from the TS order to the edge's reconstruction
        if(!defined $graph->{'Recons'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'Before'}->{"$inodepc [$inodectx]"}){
          $graph->{'Recons'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'Before'}->{"$inodepc [$inodectx]"} = 1;
        }else{
          $graph->{'Recons'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'Before'}->{"$inodepc [$inodectx]"}++ ;
        }

        #This indicates we've seen this event before
        $thisRunEvents->{'Before'}->{"$inodepc [$inodectx]"} = 1;
      }
  
      if($es > $srcIndex && $es < $sinkIndex){#<---Between src and sink
        next if(defined $thisRunEvents->{'Between'}->{"$inodepc [$inodectx]"});
        if(!defined $graph->{'Recons'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'Between'}->{"$inodepc [$inodectx]"}){
          $graph->{'Recons'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'Between'}->{"$inodepc [$inodectx]"} = 1;
        }else{
          $graph->{'Recons'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'Between'}->{"$inodepc [$inodectx]"}++ ;
        }
        $thisRunEvents->{'Between'}->{"$inodepc [$inodectx]"} = 1;
      } 
      
      if($es > $sinkIndex){#<---After the sink
        next if(defined $thisRunEvents->{'After'}->{"$inodepc [$inodectx]"});
        if(!defined $graph->{'Recons'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'After'}->{"$inodepc [$inodectx]"}){
          $graph->{'Recons'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'After'}->{"$inodepc [$inodectx]"} = 1;
        }else{
          $graph->{'Recons'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'After'}->{"$inodepc [$inodectx]"}++ ;
        }
        $thisRunEvents->{'After'}->{"$inodepc [$inodectx]"} = 1;
      } 

      last if($es == $endEs);#Quit when we hit sinkIndex + contextlength

    }#Done Scanning the Order between (srcindex - ctxlen) and (sinkindex + ctxlen)
  }#Done with this Run

  #TODO: Compute average surrounding node consistency in the reconstruction for this edge
  #      Store it in graph->src->sink->srcctx->sinkctx->order consistency
  my $node;
  my $s = Statistics::Descriptive::Full->new();
  foreach $node(keys %{ $graph->{'Recons'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'Before'}  }){
    $s->add_data($graph->{'Recons'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'Before'}->{$node});
  }
  foreach $node(keys %{ $graph->{'Recons'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'Between'}  }){
    $s->add_data($graph->{'Recons'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'Between'}->{$node});
  }
  foreach $node(keys %{ $graph->{'Recons'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'After'}  }){
    $s->add_data($graph->{'Recons'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'After'}->{$node});
  }
  $graph->{'Graph'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'order consistency'} = $s->mean(); 
  if(!defined $graph->{'max order consistency'} || 
    $graph->{'Graph'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'order consistency'} > $graph->{'max order consistency'}){
    $graph->{'max order consistency'} = $graph->{'Graph'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'order consistency'};
  }
  $s = undef;

}#end compute Buggy Orders

sub ComputeReconstructions(){
  my $graph = shift;
  my $numEdges = 0;
  $graph->applyFuncToSortedGraph(\&computeReconstructionForEdge,\$numEdges);
}

sub printOrWin(){
  my $win = shift;
  my $str = shift;
  if(defined $win){
    $win->insert('end',$str);
  }else{
    print $str;
  }
}

sub printBuggyOrdersForEdgeJSON(){
  my ($graph,$src,$sink,$srcctx,$sinkctx,$val,$numEdges,$outwin) = @_;


  $$numEdges++;
  if($$numEdges > 200){
    #only print for the first 20
    #$graph->printEdge($src,$sink,$srcctx,$sinkctx,$val);
    return;
  } 

  my $Rank = $graph->{'Graph'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'rank'};

  my $Source  = {
                 Code => $graph->codeInfoIfAvailable($src),
                 Context => $srcctx
                };
  my $Sink    = {
                 Code => $graph->codeInfoIfAvailable($sink),
                 Context => $sinkctx
                };

  my $Prefix = [];
  my $Body = [];
  my $Suffix = [];
  

  my $ev; 
  my $cnt = 0;
  my $max = $graph->{'number of graphs'};
  foreach $ev( 
    sort { 
           $graph->{'Recons'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'Before'}->{$b} <=> 
           $graph->{'Recons'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'Before'}->{$a} 
         } 
         keys %{$graph->{'Recons'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'Before'}} ){

    last if $cnt >= 10;
    my ($p,$c) = split / /, $ev;
    push @{$Prefix}, {
                      Code => $graph->codeInfoIfAvailable($p),
                      Context => $c,
                      Confidence => 100*$graph->{'Recons'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'Before'}->{$ev}/$max
                     };


    $cnt++;
  }

  $cnt = 0;
  foreach $ev(
    sort { 
           $graph->{'Recons'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'Between'}->{$b} <=> 
           $graph->{'Recons'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'Between'}->{$a} 
         } 
         keys %{$graph->{'Recons'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'Between'}} ){

    last if $cnt >= 10;
    my ($p,$c) = split / /, $ev;
    push @{$Body}, {
                      Code => $graph->codeInfoIfAvailable($p),
                      Context => $c,
                      Confidence => 100*$graph->{'Recons'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'Between'}->{$ev}/$max
                   };
    $cnt++;
  }

  $cnt = 0;
  foreach $ev(
    sort { 
           $graph->{'Recons'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'After'}->{$b} <=> 
           $graph->{'Recons'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'After'}->{$a} 
         } 
         keys %{$graph->{'Recons'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'After'}} ){
    last if $cnt >= 10;

    my ($p,$c) = split / /, $ev;
    push @{$Suffix}, {
                      Code => $graph->codeInfoIfAvailable($p),
                      Context => $c,
                      Confidence => 100*$graph->{'Recons'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'After'}->{$ev}/$max
                     };
    $cnt++;
  }

  my $reconstruction = { 
                         Rank   => $Rank,
                         Prefix => $Prefix,
                         Body   => $Body,
                         Suffix => $Suffix,
                         Source => $Source,
                         Sink   => $Sink
                       };

  my $json_text = encode_json $reconstruction;
  print $json_text."\n"; 
  
}

sub printBuggyOrdersForEdge(){
  my ($graph,$src,$sink,$srcctx,$sinkctx,$val,$numEdges,$outwin) = @_;

  $$numEdges++;
  if($$numEdges > 200){
    #only print for the first 20
    #$graph->printEdge($src,$sink,$srcctx,$sinkctx,$val);
    return;
  } 
  &printOrWin($outwin,"RANK: ".$graph->{'Graph'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'rank'}."\n");
  &printOrWin($outwin,"Events Near ".$graph->codeInfoIfAvailable($src)."[$srcctx]--->".$graph->codeInfoIfAvailable($sink)."[$sinkctx]\n");
  &printOrWin($outwin,"----------------------------------------------\n");
  &printOrWin($outwin,"Code Point\t\tContext\t\tFrequency\n"); 
  my $ev; 
  my $cnt = 0;
  my $max = $graph->{'number of graphs'};
  foreach $ev(sort { $graph->{'Recons'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'Before'}->{$b} <=> $graph->{'Recons'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'Before'}->{$a} } keys %{$graph->{'Recons'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'Before'}} ){
    last if $cnt >= 10;
    my ($p,$c) = split / /, $ev;
    &printOrWin($outwin,"".$graph->codeInfoIfAvailable($p)."\t\t[$c]:\t\t".100*$graph->{'Recons'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'Before'}->{$ev}/$max."% of Buggy Runs\n");
    $cnt++;
  }

  $cnt = 0;
  &printOrWin($outwin,"".$graph->codeInfoIfAvailable($src)."\t\t[$srcctx]\t\t(SRC)\n");
  foreach $ev(sort { $graph->{'Recons'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'Between'}->{$b} <=> $graph->{'Recons'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'Between'}->{$a} } keys %{$graph->{'Recons'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'Between'}} ){
    last if $cnt >= 10;
    my ($p,$c) = split / /, $ev;
    &printOrWin($outwin,"".$graph->codeInfoIfAvailable($p)."\t\t[$c]:\t\t".100*$graph->{'Recons'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'Between'}->{$ev}/$max."% of Buggy Runs\n");
    $cnt++;
  }

  $cnt = 0;
  &printOrWin($outwin,"".$graph->codeInfoIfAvailable($sink)."\t\t[$sinkctx]\t\t(SINK)\n");
  foreach $ev(sort { $graph->{'Recons'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'After'}->{$b} <=> $graph->{'Recons'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'After'}->{$a} } keys %{$graph->{'Recons'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'After'}} ){
    last if $cnt >= 10;
    my ($p,$c) = split / /, $ev;
    &printOrWin($outwin,"".$graph->codeInfoIfAvailable($p)."\t\t[$c]:\t\t".100*$graph->{'Recons'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'After'}->{$ev}/$max."% of Buggy Runs\n");
    $cnt++;
  }
  &printOrWin($outwin,"\n\n");
  
}

sub PrintBuggyOrders(){
  my $graph = shift;
  my $numEdges = 0;
  $graph->applyFuncToSortedGraph(\&printBuggyOrdersForEdgeJSON,\$numEdges);
}


sub printFeaturesForEdge(){
  my ($graph,$src,$sink,$srcctx,$sinkctx,$val) = @_;
  if(not defined $graph->{'Graph'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'order consistency'}){
    return;
  }

  print "".
         $graph->{'Graph'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'frequency'}/ $graph->{'number of graphs'}.", ".
         $graph->{'Graph'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'order consistency'} / $graph->{'max order consistency'}.", ".
         $graph->{'Graph'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'correct run ctx var'}.", ".
         $graph->{'Graph'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'Avg Span'}.", nonbuggy\n";
}

sub PrintFeatureVectors(){
  my $graph = shift;
  print "% Arff data generated by Recon\n";
  my $ex = `basename $graph->{'executable'}`;
  print "% Program: $ex\n";
  print "% Generated by Recon.  For Cross-Validation, change class of buggy reconstruction\n";
  print "% Copyright Brandon Lucia - 2010 - University of Washington\n";
  
  print "\n\@Relation Recon\n\n";
  print "\@ATTRIBUTE b NUMERIC\n"; 
  print "\@ATTRIBUTE r NUMERIC\n"; 
  print "\@ATTRIBUTE c NUMERIC\n"; 
  print "\@ATTRIBUTE s NUMERIC\n"; 
  print "\@ATTRIBUTE class {buggy,nonbuggy}\n\n"; 
  print "\@DATA\n";
 
  $graph->applyFuncToSortedGraph(\&printFeaturesForEdge);
}



sub PrintBuggyOrdersTk(){
  my $graph = shift;
  my $outwin = shift;
  my $numEdges = 0;
  $graph->applyFuncToSortedGraph(\&printBuggyOrdersForEdge,\$numEdges,$outwin);
}

sub ctxString(){
  my $numericCtx = shift;
  $numericCtx =~ s/[^0-4]//g;
  $numericCtx =~ s/0/| None /g;
  $numericCtx =~ s/1/| LocRd /g;
  $numericCtx =~ s/2/| LocWr /g;
  $numericCtx =~ s/3/| RemRd /g;
  $numericCtx =~ s/4/| RemWr /g;
  return $numericCtx; 
}

sub dotPrintBuggyOrdersForEdge(){
  my ($graph,$src,$sink,$srcctx,$sinkctx,$val,$numEdges,$dotPath,$window) = @_;

  $$numEdges++;
  if($$numEdges > 200){
    #only print for the first 20
    #$graph->printEdge($src,$sink,$srcctx,$sinkctx,$val);
    return;
  } 
  if(! -e $dotPath){
    mkdir $dotPath;
    if(defined $window){
      $window->insert('end',"Created output directory \"$dotPath\"");
    }
  }
  my $DOTFILE;
  open $DOTFILE, ">$dotPath/Reconstruction.$$numEdges.dot";
  print $DOTFILE "digraph g$$numEdges {\n";
  print $DOTFILE "node [shape=record];\n";
  print $DOTFILE "rankdir=LR;\n";
  print $DOTFILE "".$graph->codeInfoIfAvailable_short($src)." [label=\"".$graph->codeInfoIfAvailable($src)."| {CTX".&ctxString($srcctx)."}\" style=filled, fillcolor = red];\n";
  print $DOTFILE "".$graph->codeInfoIfAvailable_short($sink)." [label=\"".$graph->codeInfoIfAvailable($sink)."| {CTX".&ctxString($sinkctx)."}\" style=filled, fillcolor = red];\n";
  print $DOTFILE $graph->codeInfoIfAvailable_short($src)." -> ".$graph->codeInfoIfAvailable_short($sink)." [style=bold, weight=1, color=red];\n";

  my $ev; 
  my $cnt = 0;
  my $max = $graph->{'number of graphs'};
  foreach $ev(sort { $graph->{'Recons'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'Before'}->{$b} <=> $graph->{'Recons'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'Before'}->{$a} } keys %{$graph->{'Recons'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'Before'}} ){
    last if $cnt >= 5;
    my ($p,$c) = split / /, $ev;
    my $cs = $c;
    $cs =~ s/\[//g;
    $cs =~ s/\]//g;
    print $DOTFILE "".$graph->codeInfoIfAvailable_short($p)."B$cs [label=\"".$graph->codeInfoIfAvailable($p)."| {CTX".&ctxString($c)."}\"]\n";
    print $DOTFILE "".$graph->codeInfoIfAvailable_short($p)."B$cs -> ".$graph->codeInfoIfAvailable_short($src)." [label = ".100*$graph->{'Recons'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'Before'}->{$ev}/$max."];\n";
    $cnt++;
  }

  $cnt = 0;
  foreach $ev(sort { $graph->{'Recons'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'Between'}->{$b} <=> $graph->{'Recons'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'Between'}->{$a} } keys %{$graph->{'Recons'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'Between'}} ){
    last if $cnt >= 5;
    my ($p,$c) = split / /, $ev;
    my $cs = $c;
    $cs =~ s/\[//g;
    $cs =~ s/\]//g;
    print $DOTFILE "".$graph->codeInfoIfAvailable_short($p)."D$cs [label=\"".$graph->codeInfoIfAvailable($p)."| {CTX".&ctxString($c)."}\"]\n";
    print $DOTFILE "".$graph->codeInfoIfAvailable_short($src)." -> ".$graph->codeInfoIfAvailable_short($p)."D$cs [label = ".100*$graph->{'Recons'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'Between'}->{$ev}/$max."];\n";
    print $DOTFILE "".$graph->codeInfoIfAvailable_short($p)."D$cs -> ".$graph->codeInfoIfAvailable_short($sink)." [label = ".100*$graph->{'Recons'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'Between'}->{$ev}/$max."];\n";
    
    $cnt++;
  }

  $cnt = 0;
  foreach $ev(sort { $graph->{'Recons'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'After'}->{$b} <=> $graph->{'Recons'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'After'}->{$a} } keys %{$graph->{'Recons'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'After'}} ){
    last if $cnt >= 5;
    my ($p,$c) = split / /, $ev;
    my $cs = $c;
    $cs =~ s/\[//g;
    $cs =~ s/\]//g;
    print $DOTFILE "".$graph->codeInfoIfAvailable_short($p)."A$cs [label=\"".$graph->codeInfoIfAvailable($p)."| {CTX".&ctxString($c)."}\"]\n";
    print $DOTFILE "".$graph->codeInfoIfAvailable_short($sink)." -> ".$graph->codeInfoIfAvailable_short($p)."A$cs [label = ".100*$graph->{'Recons'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'After'}->{$ev}/$max."];\n";

    $cnt++;
  }
  print $DOTFILE "}\n";
  print "\n\n";
  close $DOTFILE;
  
  system("dot -Tpdf $dotPath/Reconstruction.$$numEdges.dot > $dotPath/Reconstruction.$$numEdges.pdf");
  if(defined $window){
    $window->insert('end',"Created Reconstruction.$$numEdges.pdf\n");
  }

  
}

sub DotPrintBuggyOrders(){
  my $graph = shift;
  my $dotPath = shift;
  my $numEdges = 0;
  
  $graph->applyFuncToSortedGraph(\&dotPrintBuggyOrdersForEdge,\$numEdges,$dotPath);
}

sub DotPrintBuggyOrdersTk(){
  my $graph = shift;
  my $dotPath = shift;
  my $window = shift;
  my $numEdges = 0;
  
  $graph->applyFuncToSortedGraph(\&dotPrintBuggyOrdersForEdge,\$numEdges,$dotPath,$window);
}


sub computeSpanForEdge(){
  my ($graph,$src,$sink,$srcctx,$sinkctx,$val) = @_;

  my $timeavg = Statistics::Descriptive::Full->new();

  #assumes $graph->{TS Ordered}->{run} is a reference to a sorted array
  my $run;
  foreach $run(%{$graph->{'TS Graph By File'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}}){
    next if !defined $graph->{'TS Graph By File'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{$run};

    my ($thisRunSrcTS,$thisRunSinkTS) = 
      split /:/, $graph->{'TS Graph By File'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{$run};

    #Push edge's duration (as a frac of exec time) onto array of data points
    if($thisRunSinkTS > $thisRunSrcTS){
      $timeavg->add_data(($thisRunSinkTS-$thisRunSrcTS)/$graph->{'Run Times'}->{$run});
    }
  }
  $graph->{'Graph'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'Avg Span'} = $timeavg->mean();

}


sub ComputeAverageEdgeSpan(){
  my $graph = shift;
  $graph->applyFuncToGraph(\&computeSpanForEdge);
}

sub differenceForEdge(){
  my ($graph,$src,$sink,$srcctx,$sinkctx,$val,$difference,$numEdges,$other) = @_;
  if(defined $other->{'Graph'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}){
    $$difference += 
      abs(($graph->{'Graph'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'frequency'}/$graph->{'number of graphs'}) -
          ($other->{'Graph'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'frequency'}/$other->{'number of graphs'}));
  }else{
    $$difference += ($graph->{'Graph'}->{$src}->{$sink}->{$srcctx}->{$sinkctx}->{'frequency'}/$graph->{'number of graphs'});
  }
  $$numEdges++;
}

sub Difference(){
  my $complete = shift;
  my $other = shift;
  my $difference = 0;
  my $numEdges = 0; 
  print "".$complete->{'number of graphs'}."\n";
  $complete->applyFuncToGraph(\&differenceForEdge,\$difference,\$numEdges,$other);
  if($numEdges == 0){ warn "0 Edges Found!\n"; return 0; }
  return ($difference/$numEdges);
}

#############################################################################
#This is a sample visitor that you can copy to make your own new visitors
#############################################################################
#sub doSomethingToEdge(){
#  my ($graph,$src,$sink,$srcctx,$sinkctx,$val,$somearg) = @_;
#  if(defined $graph->GetNode($src,$sink,$srcctx,$sinkctx)){
#    $graph->RemoveNode($src,$sink,$srcctx,$sinkctx);
#  }
#}
#
#sub DoSomethingToAllEdges(){
#  my $graph = shift;
#  my $someargument = shift;
#  $graph->applyFuncToSortedGraph(\&doSomethingToEdge,$someargument);
#}
############################################################################

#*******************************************
#Graph Traversal Routines (applyFuncToGraph)
#*******************************************
#######Apply Func To Sorted Graph Stuff

sub stringifyKeys(){
  my ($graph,$src,$sink,$srcctx,$sinkctx,$val,$edgeStrings) = @_;
  push @{$edgeStrings}, "$src:$sink:$srcctx:$sinkctx"; 
}

sub applyFuncToSortedGraph(){
  my $graph = shift;
  my $func = shift;
  my @otherArgs = @_;

  my $edgeString;
  foreach $edgeString(sort { #Begin Sort Lambda
                            my ($srcA,$sinkA,$srcctxA,$sinkctxA) = split /:/,$a;
                            my ($srcB,$sinkB,$srcctxB,$sinkctxB) = split /:/,$b;
                            return $graph->GetEdge($srcB,$sinkB,$srcctxB,$sinkctxB)->{'rank'} <=>
                                   $graph->GetEdge($srcA,$sinkA,$srcctxA,$sinkctxA)->{'rank'};
                           } #End Sort Lambda
                      keys %{$graph->{'EdgeKeys'}} 
                     ){
    my ($src,$sink,$srcctx,$sinkctx) = split /:/,$edgeString;
    $func->($graph,$src,$sink,$srcctx,$sinkctx,
            $graph->GetEdge($src,$sink,$srcctx,$sinkctx)->{'rank'},@otherArgs);
  }
}
#----------------------------------------

#######Apply Func To Graph
sub applyFuncToGraph(){
  my $graph = shift;
  my $func = shift;
  my @otherArgs = @_;

  while(my ($src,$sinks) = each(%{$graph->{'Graph'}})){
    while(my ($sink,$srcctxs) = each(%{$graph->{'Graph'}->{$src}})){
      while(my ($srcctx,$sinkctxs) = each(%{$graph->{'Graph'}->{$src}->{$sink}})){
        while(my ($sinkctx,$val) = each (%{$graph->{'Graph'}->{$src}->{$sink}->{$srcctx}})){
          $func->($graph,$src,$sink,$srcctx,$sinkctx,$val,@otherArgs);
        }
      }
    }
  }
}
#----------------------------------------




#************************
#Fancy Output
#************************
###############DOT OUTPUT
sub printDotEdge(){
  my $graph = shift;
  my $src = shift;
  my $sink = shift;
  my $srcctx = shift;
  my $sinkctx = shift;
  my $val = shift;
  my $FILE = shift;

  my $srcstring = $graph->codeInfoIfAvailable_short($src);
  $srcstring =~ s/://g;
  $srcstring =~ s/_//g;
  $srcstring =~ s/-//g;

  my $sinkstring = $graph->codeInfoIfAvailable_short($sink);
  $sinkstring =~ s/://g;
  $sinkstring =~ s/_//g;
  $sinkstring =~ s/-//g;

  print $FILE "$srcstring -> $sinkstring [label = ".($val/$graph->{'number of graphs'})."]\n";
}

sub GenerateDotGraph(){
  my $graph = shift;
  my $outfile = shift;
  my $outbase = `basename $outfile`;
  chomp $outbase;
  
  my $FILE; 
  open $FILE,">$outfile.dot" or die "$!: Couldn't open file $outfile.dot\n";
  print $FILE "digraph $outbase {\n";
  $graph->applyFuncToGraph(\&printDotEdge,$FILE); 
  print $FILE "}\n";
  close $FILE;
}
#----------------------------------------



##################GNUPLOT CDF OUTPUT
sub getNumberGreaterThan(){
  my $graph = shift;
  my $src = shift;
  my $sink = shift;
  my $srcctx = shift;
  my $sinkctx = shift;
  my $val = shift;
  my $freq = shift;
  my $numRef = shift;

  if($val > $freq){
    $$numRef++;
  }
}

sub GenerateGnuplotCDFHeader(){
  my $outdir = shift;
  my $numdatafiles = shift;
  my $FILE;
  open $FILE,">$outdir/dist.gnu" or die "$!: Couldn't open file $outdir/dist.gnu\n"; 
  print $FILE "set boxwidth 0.9 relative\n";
  print $FILE "set style data histograms\n";
  print $FILE "set style histogram clustered gap 1\n";
  print $FILE "set style fill solid 1.0 border -1\n";
  print $FILE "set xtic rotate by -45 scale 0\n";
  print $FILE "set term postscript color 8\n";
  print $FILE "set output 'dist.ps'\n";
  print $FILE "set yrange [0:1]\n";

  print $FILE "plot "; 
  for(my $i = 0; $i < $numdatafiles; $i++){ 
    print $FILE "'data.$i' using  2:xticlabels(1) title '$i Runs', \\\n";
  }
  print "\n";
  close $FILE;

}

sub GenerateGnuplotCDFDataFile(){
  my $graph = shift;
  my $outfile = shift;

  my $FILE; 
  open $FILE,">$outfile" or die "$!: Couldn't open file $outfile\n";
  for(my $freq = 0; $freq <= 100; $freq++){
    my $num = 0;
    $graph->applyFuncToSortedGraph(\&getNumberGreaterThan,$freq/100,\$num);
    printf $FILE "%.2f %.2f\n", $freq, $num/$graph->{'number of graphs'}; 
  }
  
  close $FILE;
}
#----------------------------------------


#######Gnuplot Histogram output stuff
sub printGnuplotEdge(){
  my $graph = shift;
  my $src = shift;
  my $sink = shift;
  my $srcctx = shift;
  my $sinkctx = shift;
  my $val = shift;
  my $outfile = shift;
  my $num = shift;
 
  printf $outfile "".($graph->codeInfoIfAvailable_short($src)).":".($graph->codeInfoIfAvailable_short($sink))." %.4f\n",  $val;
  $$num++;
}

sub GenerateGnuplotHistogram(){
  my $graph = shift;
  my $outfile = shift;
  my $outbase = `basename $outfile`;
  chomp $outbase;

  my $FILE; 
  open $FILE,">$outfile.data" or die "$!: Couldn't open file $outfile.data\n";
  my $num = 1;
  print $FILE "CommunicationEvent Frequency\n";
  $graph->applyFuncToSortedGraph(\&printGnuplotEdge,$FILE,\$num);
  close $FILE;

  open $FILE,">$outfile.gnu" or die "$!: Couldn't open file $outfile.gnu\n"; 
  print $FILE "set boxwidth 0.9 relative\n";
  print $FILE "set style data histograms\n";
  print $FILE "set style histogram clustered gap 1\n";
  print $FILE "set style fill solid 1.0 border -1\n";
  print $FILE "set xtic rotate by -45 scale 0\n";
  print $FILE "set term postscript color 8\n";
  print $FILE "set output '$outbase.ps'\n";
  print $FILE "set yrange [0:1]\n";

  print $FILE "plot '$outbase.data' using  2:xticlabels(1) title 1\n";

  close $FILE;
}
#--------------------------------------------------------------------------
#
#End of Module
1;
