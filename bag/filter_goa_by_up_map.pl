# reads a GOA file from STDIN and writes a filtered file to STDOUT 

use Carp;
use strict;
use warnings;

my $up_map_file = shift;
my %up_map;
open my $FH, '<',  $up_map_file;
while (<$FH>) {
	my ($ac, $id) = split;
	$up_map{$ac} = $id;
}
while (<>) {
	next if /\A!/xms; # !gaf-version: 2.0
	my @assoc = split(/\t/);
	my $line = $_;
	my $prot_ac = $assoc[1];
	foreach ( keys %up_map) {
		if ($_ eq $prot_ac) {
			print $line;
			last;
		}		
	} 
}
