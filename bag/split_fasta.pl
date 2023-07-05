# Args: 1. index of the field with taxon ID, 2. index of the field with protein ID
# Input: FASTA sequences for multiple taxa (STDIN); '|' separated headers
# Output: separate FASTA files per taxon; file names - taxonID.fasta

use Carp;
use strict;
use warnings;
use Data::Dumper;

my $txidind = shift;
my $ptidind = shift;

my %all;
{
	local $/ = ">";
	while (<>) {
		chomp; # use it if want to delete the trailing $/
		my @lines = split /\n/;
		next if @lines == 0;
		my $header = shift @lines;
		my @fields = split /\|/, $header;
		my $tax = $fields[$txidind];
		next unless $tax;
		my ( $id, @junk ) = split /\s/, $fields[$ptidind]; # cleaning up mess from OMCLDB
		next unless $id;
		my $entry = ">$tax|$id\n";
		map { $entry .= "$_\n" } @lines;
		#~ print $entry;
		if ( ! $all{$tax} ) { $all{$tax} = $entry } else { $all{$tax} .= $entry }
		
	}
map { open my $fh, '>', "$_.fasta"; print $fh $all{$_}; close $fh } sort keys %all;
}
