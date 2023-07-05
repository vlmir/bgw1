# extracts from a UniProt map (AC vs ID) the lines with the ACs from a supplied list of ACs
# the only argument is a list of UP accessions
# the map to filter is taken from STDIN
# the filtered map is sent to STDOUT
use strict;
use warnings;
use Carp;

my $ac_list = shift @ARGV;
open my $FH, '<', $ac_list; # or croack "can't open $ac_list\n";
my @acs = <$FH>;
while (<>) {
	my $line = $_;
	foreach my $ac (@acs) {
		chomp $ac;
		if ($line =~ /\A$ac/xms) {
			print $line;
		}		
	}
}