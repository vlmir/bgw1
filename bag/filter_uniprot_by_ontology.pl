#!/usr/local/bin/perl -w

=head2 filter_uniprot_by_ontology.pl

  Usage    - perl filter_uniprot_by_ontology.pl cco_I_$organism.obo [$organism_name] < input_uniprot_file > uniprot_sprot_trembl_CCO_file_name_by_taxon_id
  Args     - the given OBO file
  Function - retrieves entries for a particular species from a UniProt file based on the given ontology entries
  
=cut

use strict;
use warnings;
use Carp;

my $workspace = '../../onto-perl/';

BEGIN {
	unshift @INC, '../../onto-perl';
}

use OBO::Parser::OBOParser;

my $OBO_file    = shift @ARGV; # cco_I_$organism.obo
my $organism_id = shift @ARGV; # optional argument

# Initialize the OBO parser, load the OBO file
my $my_parser = OBO::Parser::OBOParser->new();
my $ontology = $my_parser->work($OBO_file);

my %prot;
if ($organism_id) {
	my $rtbn = $ontology->get_relationship_type_by_name('has_source');
	foreach my $prot (@{$ontology->get_terms("CCO:B.*")}) {
		my $head = (@{$ontology->get_head_by_relationship_type($prot, $rtbn)})[0];
		if ($head) {
			if ($head->id() eq $organism_id) {
				$prot{$prot->name()} = 1; # proteins belonging to a specific organism
				#open FF, ">>log.filter.$organism_id" || die $!;
				#print FF "\nprotein: ", $prot->name();
				#close FF;
			}
		} elsif ($prot->id() eq "CCO:B0000000") {
			# do nothing: no organims for 'core cell cycle protein'
		} else {
			warn "There is not organism associated to '", $prot->id(), "'";
		}
	}
} else {
	foreach my $prot (@{$ontology->get_terms("CCO:B.*")}) {
		$prot{$prot->name()} = 1; # all the proteins from the given ontology file
	}
}

local $/ = "\n//\n";
while (<>) {
	#
	# Print out the entries which are part of the given OBO file
	#
	print $_ if (/ID\s{3}(\w+_\w+)\s/ && $prot{$1});
}