# 
#
# File    : write_up_map.pl
# Purpose : generates maps of protein names vs accession numbers from UniProt files
# Usage   : perl write_up_map.pl < uniprot_file_name > output_file_name
# Args    : a UniProt input file
# License : Copyright (c) 2007 Cell Cycle Ontology. All rights reserved.
#           This program is free software; you can redistribute it and/or
#           modify it under the same terms as Perl itself.
# Contact : CCO <ccofriends@psb.ugent.be>

use SWISS::Entry;

use strict;
use warnings;
use Carp;

{
	local $/ = "\n//\n";
	while (<>) {
		my $entry        = SWISS::Entry->fromText($_);
		my @accs         = @{ $entry->ACs->{list} };
		my $protein_name = $entry->ID;
		#foreach my $acc (@accs) {
			#print "$acc\t$protein_name\n";
		#}
		print "$accs[0]\t$protein_name\n";
	}
}

