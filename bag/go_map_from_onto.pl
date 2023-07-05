# takes an input ontology from STDIN, generates map of GO-CCO ids and sends it to STDOUT
# argument: a list of GO ids (no altids!!!)
# Attn!!! - the output should be always checked for warnings like "another GO id for $cco_id\n"

use Carp;
use strict;
use warnings;

my $go_ids_file = shift;
open my $FH, '<', $go_ids_file;
my @go_ids = <$FH>;
chomp @go_ids;

{
	local $/ = "\n\n";
	while (<>) {
		if ($_ !~ /\A\[Term\]/xms) {
			next;
		}
#		if (/^id:\s(CCO:[PCF]\d{7}).*^xref:\s(GO:\d{7})/xms) { # works but cannot cope with multiple xrefs
#		if (/^name:\s(.+?)\n.*^xref:\s(GO:\d{7})/xms) { # this one also works, the ? and \n are essential
		if (/^xref:\sGO:/xms) {
			chomp; # use it if want to delete the trailing $/			
			my @lines = split /\n/;
			my $cco_id = substr $lines[1], 4, 12;
			my $go_id;
			my $counter;
			foreach  (@lines) {
				if (/^xref:\s(GO:\d{7})/xms) {
					$go_id = $1;
					foreach (@go_ids) {
						if ($_ eq $go_id) {
							$counter++;
							carp "another GO id for $cco_id\n" if ($counter > 1);							
							print "$go_id\t$cco_id\n" ;
						}
					}
				}
			}
		}
	}
}