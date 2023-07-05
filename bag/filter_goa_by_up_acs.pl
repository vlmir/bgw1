# reads a GOA file from STDIN and writes a filtered file to STDOUT 
# the argument: a file with UniProt ACs

use Carp;
use strict;
use warnings;

my $up_acs_file = shift;
open my $FH, '<',  $up_acs_file;
my @up_acs =  (<$FH>);
chomp @up_acs;
while (<>) {
	next if /\A!/xms; # !gaf-version: 2.0
	my @assoc = split(/\t/);
	my $line = $_;
	my $prot_ac = $assoc[1];
	foreach ( @up_acs ) {
		if ($_ eq $prot_ac) {
			print $line;
			last;
		}	
	} 
}
