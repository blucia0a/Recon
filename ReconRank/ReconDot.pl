#!/usr/bin/perl 
use lib '/sampa/home/blucia/perl/share/perl/5.8.8';
use JSON;
use utf8;

my $outdir = shift @ARGV || ".";

my $num = 0;
while(<>){

  my $r = decode_json($_);
  &GenerateDotGraph($r,$num);
  system("dot -Tpdf $outdir/graph$num.dot > $outdir/graph$num.pdf");
  unlink "$outdir/graph$num.dot";
  $num++;   

}

#************************
#Fancy Output
#************************

sub dotify(){

  my $str = shift;
  $str =~ s/://g;
  $str =~ s/_//g;
  $str =~ s/-//g;
  return $str;  
 
}

sub printReconstruction(){

  my $reconstruction = shift;
  my $FILE = shift;

  print $FILE "\"".&dotify($reconstruction->{'Source'}->{'Code'})."\" -> \"".&dotify($reconstruction->{'Sink'}->{'Code'})."\" [style = \"setlinewidth(5)\"]\n"; 

  my $p;
  foreach $p( @{$reconstruction->{'Prefix'}} ){
    print $FILE "\"".&dotify($p->{'Code'})."P\" -> \"".&dotify($reconstruction->{'Source'}->{'Code'})."\" [label = ".$p->{'Confidence'}."]\n"; 
  }

  my $b;
  foreach $b( @{$reconstruction->{'Body'}} ){
    print $FILE "\"".&dotify($reconstruction->{'Source'}->{'Code'})."\"-> \"".&dotify($b->{'Code'})."B\" [label = ".$b->{'Confidence'}."]\n"; 
    print $FILE "\"".&dotify($b->{'Code'})."B\" -> \"".&dotify($reconstruction->{'Sink'}->{'Code'})."\" [label = ".$b->{'Confidence'}."]\n"; 
  }

  my $s;
  foreach $s( @{$reconstruction->{'Suffix'}} ){
    print $FILE "\"".&dotify($reconstruction->{'Sink'}->{'Code'})."\" -> \"".&dotify($s->{'Code'})."S\" [label = ".$s->{'Confidence'}."]\n"; 
  }

}

sub GenerateDotGraph(){

  my $reconstruction = shift;
  my $num = shift;

  my $outfile = "$outdir/graph$num";
  
  my $FILE; 

  open $FILE,">$outfile.dot" or die "$!: Couldn't open file $outdir/$outfile.dot\n";

  print $FILE "digraph $outbase {\n";
  &printReconstruction($reconstruction, $FILE);  
  print $FILE "}\n";

  close $FILE;

}
#----------------------------------------
