#!/usr/bin/perl -w

$num_args = $#ARGV + 1;

if ($num_args != 2) {
  print "\nUsage: bin2cmd.pl file.bin LOAD_ADDR > SIMH.cmd\n\n";
  exit;
}

$infile=$ARGV[0];
$addr=eval($ARGV[1]);

open INFILE, "<$infile" or die $!;
binmode INFILE;

my ($data, $n);

while (($n = read INFILE, $data, 1) != 0) {
   printf ("d -b %06o %03o\n",$addr,ord($data) );
   $addr++;
}


close(INFILE);
