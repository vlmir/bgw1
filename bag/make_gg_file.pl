#!/usr/local/perl5.8.5/bin/perl -w
=head2 make_gg_file.pl

  Usage    - perl make_gg_file.pl  input_fasta_file(s) > output_gg_file
  Args     - names of FASTA	files
  Function - filters fasta file(s) and writes gg file (taxon label followed by protein identifiers)
  
=cut
use strict;
use warnings;
use Carp;
use Data::Dumper;

my @file_names = @ARGV;
my %gg; # hash of arrays

foreach my $file_name (@file_names) {	
	$file_name =~ /^(\w+)/xms;
	my $taxon_label = $1;
	open my $FH, '<', $file_name or croak "cannot open file $file_name $!";
	while (<$FH>) {
		if ($_ =~ /^>([^|]+)/) {
			push @{$gg{$taxon_label}}, $1;		
		}
		else {
			next;
		}
	}
}

foreach my $taxon_label (keys %gg) {
	print "$taxon_label: @{$gg{$taxon_label}}\n";
}


