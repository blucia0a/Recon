package ReconUtil;

use warnings;
use strict;

sub addr2lineCall($$){
  my $exec = shift;
  my $pc = shift;
  my $ADDR2LINE;
  open($ADDR2LINE, '-|',"addr2line","-C","-f","-e",$exec,$pc); 
  my ($func,$codePoint) = <$ADDR2LINE>;
  close($ADDR2LINE);
  chomp $func;
  my ($codePointFile,$codePointLine) = split /:/,$codePoint;
  chomp $codePointFile;
  chomp $codePointLine;
  return ($func,$codePointFile,$codePointLine); 
}


1;
