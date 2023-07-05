# takes a file with inparalog pairs from STDIN  and prints output to STDOUT
# argument: taxon id, file with protein ids
# input format: 'tax_id1'\t'prot_id1'\t'taxid2'\t'prot_id2'\t'score'
# only entries with prot_id1 present in the list of ids are printed

use Carp;
use strict;
use warnings;

my  $tax_id = shift;
my $up_map_file = shift;
open my $FH, '<', $up_map_file;
#my @prot_ids = (<$FH>);
my %up_map;
while (<$FH>) {
	chomp;
	my ($ac, $id) = split;
	$up_map{$ac}= $id;
}
my @prot_ids = values %up_map;
chomp @prot_ids;
while (<>) {
	my $line = $_;
	my @fields = split;
	my ($tax_id1, $prot_id1) = split (/\|/, $fields[0]);
	if ($tax_id1 eq $tax_id) {
		foreach (@prot_ids) {
			if ($prot_id1 eq $_) {
				print $line;
				last;
			}
		}
	}
}