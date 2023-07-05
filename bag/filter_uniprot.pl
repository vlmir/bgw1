#!/usr/local/bin/perl -w

=head2 filter_uniprot.pl

  Usage    - perl filter_uniprot.pl 'taxon_name' < input_uniprot_file(s) > output_uniprot_file
  Args     - taxon name
  Function - retrieves entries for a particular species from a UniProt file
  
=cut

use strict;
use warnings;
use Carp;

my $taxon = shift @ARGV;

local $/ = "\n//\n";
while (<>) {
	print $_ if (/^OS[ ]{3}$taxon/ms);
}