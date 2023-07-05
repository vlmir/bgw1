# $Id: update_protein_names.pl 1385 2007-08-06 16:41:39Z erant $
#
# File    : update_protein_names.pl
# Purpose : Updates the deprecated protein names in the given ontology using UniProt files as references (source of the newest names)
# Usage   : perl update_protein_names.pl input_obo_file short_map long_map input_uniprot_file output_obo_file
# Args    : ontology to be updated in obo format, taxon specific map file (CCO_id Protein_name), combined map file, UniProt file(s)
# License : Copyright (c) 2007 Cell Cycle Ontology. All rights reserved.
#           This program is free software; you can redistribute it and/or
#           modify it under the same terms as Perl itself.
# Contact : CCO <ccofriends@psb.ugent.be>

my $workspace = '/group/biocomp/cbd/users/erant/workspace/ONTO-PERL/';

BEGIN {
	unshift @INC, '/group/biocomp/cbd/users/erant/workspace/ONTO-PERL';
}

use OBO::Parser::OBOParser;
use OBO::CCO::CCO_ID_Term_Map;
use SWISS::Entry;

use strict;
use warnings;
use Carp;

my $obo_file       = shift;
my $short_map_file = shift;
my $long_map_file  = shift;
my $input_uniprot_file = shift;
my $output_obo_file = shift;

#
# building hashes of proteiin names and accession numbers from UniProt
#
my %names; # key - protein name (ID), value - integer (only for proteins present in UniProt)
my %map;    # key - protein accession number, value - protein name (ID)
{
	local $/ = "\n//\n";
	open (IN, $input_uniprot_file) || die "Error: ", $!;
	while (<IN>) {
		my $entry        = SWISS::Entry->fromText($_);
		my @accs         = @{ $entry->ACs->{list} };
		my $protein_name = $entry->ID;
		$names{$protein_name} += 1;
		foreach my $acc (@accs) {
			$map{$acc} = $protein_name;
		}
	}
	close IN;
}

# Initialize the OBO parser
my $my_parser = OBO::Parser::OBOParser->new();
my $ontology  = $my_parser->work($obo_file);

# Initialize CCO_ID_Map objects
my $short_map = OBO::CCO::CCO_ID_Term_Map->new($short_map_file); # taxon specific map of [B]iomolecules IDs and [B]iomolecules names
my $long_map = OBO::CCO::CCO_ID_Term_Map->new($long_map_file);   # Set of [B]iomolecules IDs

foreach my $term ( @{$ontology->get_terms("CCO:B.*")} ) {
	my $name = $term->name();
	next if $names{$name};
	# the term is of [B]iomolecule type and its name is not present in the UniProt file(s)
	#find the first external reference in the term matching an accession number from UniProt
	foreach my $xref ( $term->xref_set()->get_set() ) {
		next unless $xref->db() eq 'UniProtKB';
		next unless my $new_name = $map{ $xref->acc() };
        # the UniProt file contains a protein with the given accession number
		#overwrite the current name in the ontology
		$term->name($new_name);
		if ( $short_map->contains_value($new_name) ) {
			# the new protein name from UniProt is already in the maps
			# happens when a protein term with a deprecated name has been reintroduced from other sources
			# change the protein id to the original one
			my $cco_id            = $short_map->get_cco_id_by_term($new_name);
			my $deprecated_cco_id = $term->id();
			
			$ontology->set_term_id( $term, $cco_id );
			
			# update the maps
			$short_map->remove_by_key($deprecated_cco_id);
			$long_map->remove_by_key($deprecated_cco_id);
		} elsif (!$short_map->contains_value($new_name) && $short_map->contains_value($name)) {

			# the new protein name from UniProt is not present in the maps
			# overwrite the protein name in the map files
			my $cco_id = $term->id();
			$short_map->put( $cco_id, $new_name );
			$long_map->put( $cco_id,  $new_name );
		} else {
			warn "The maps contain neither $name nor $new_name for accession number $xref->{'ACC'}\n";
		}
	}	
}
open (OUT, ">".$output_obo_file) || die "Error: ", $!;
$ontology->export( \*OUT );
close OUT;

$short_map->write_map();
$long_map->write_map();