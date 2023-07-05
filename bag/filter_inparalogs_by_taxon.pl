# takes a file with inparalog pairs from STDIN  and prints entries for a specified taxon to STDOUT
# argument: taxon id

use Carp;
use strict;
use warnings;

my  $taxon = shift;
while (<>) {
	print if (/\A$taxon\t/xms);
}