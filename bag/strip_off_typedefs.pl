# takes an input ontology from STDIN and prints the ontology without Typedefs to STDOUT

use Carp;
use strict;
use warnings;

{
	local $/ = "\n\n";
	while (<>) {
#		chomp; # use it if want to delete the trailing $/
		if ($_ !~ /\A\[Typedef\]/xms) {
			print;
		}
	}
}