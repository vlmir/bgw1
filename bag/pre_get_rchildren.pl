# $Id: pre_get_rchildren.pl 89 2006-01-18 10:52:47Z erant $
#
# Module  : pre_get_rchildren.pl
#
# Purpose : Extracts all the children from a given GO-node (GO:0007049) and 
#           puts them all into a pre-cell cyle ontology file in OBO format.
#           Besides, creates/updates the initial table (go_cco.ids) of 
#           association IDs (GO_ID vs CCO_ID). 
#           Also, creates a 'dirty_pre_cco.obo' file.
#
# Usage:
#           perl -w pre_get_rchildren.pl ../doc/go_cco.ids ../doc/go_in_cco.ids ../obo/gene_ontology.obo > ../obo/cco_from_go.obo
#
# License : Copyright (c) 2006 Erick Antezana. All rights reserved.
#           This program is free software; you can redistribute it and/or
#           modify it under the same terms as Perl itself.
#
# Contact : Erick Antezana <erant@psb.ugent.be>
#
##############################################################################
use strict;
use Carp;
BEGIN {
	unshift @INC, '../../onto-perl';
}
use OBO::Parser::OBOParser;
use OBO::CCO::CCO_ID_Term_Map;

use constant NL				=> "\n";

my $go_cco_ids_table_path	= shift @ARGV; # "../doc/go_cco.ids";
my $go_ids_in_cco_path		= shift @ARGV; # "../doc/go_in_cco.ids";

my $cco_p_ids_path          = "../doc/cco_p.ids"; # [p]rocesses
##############################################################################
my $my_parser = OBO::Parser::OBOParser->new();
my $onto = $my_parser->work(shift @ARGV); # load: gene_ontology.obo
my $sub_ontology_root_id = "GO:0007049";
my $term = $onto->get_term_by_id($sub_ontology_root_id);
my @descendents = @{$onto->get_descendent_terms($term)};
unshift @descendents, $term;
my $term_set = OBO::Util::TermSet->new();
$term_set->add_all(@descendents);
my $so = $onto->subontology_by_terms($term_set);
$so->default_namespace("cellcycle_ontology");
$so->subsets($onto->subsets()->get_set()); # TODO Only add the used subsets, not all...
$so->synonym_type_def_set($onto->synonym_type_def_set()->get_set());
$so->remark("A Cell-Cycle Sub-Ontology");
$so->export(\*STDOUT);      # cco_from_go.obo
select((select(STDOUT), $|=1)[0]);
################################################################################
#
# TODO Consider the following terms to be integrated into the CCO.
# Source: 2006-01_PAG_annotating_hdrabkin.ppt
#
# GO has three terms to be used when the curator has determined that there is no existing literature to support an annotation.
# 	Biological_process GO:0008150
# 	Molecular_function GO:0003674
# 	Cellular_component GO:0005575
# These are NOT the same as having no annotation at all. 
# 	No annotation means that no one has looked yet.
#
##############################################################################
#
# Creation of the association table: GO_ID vs CCO_ID
#
##############################################################################
my $number_unique_terms = 391;
my $number_of_descendents = $#descendents + 1;

# assert
($number_of_descendents == $number_unique_terms) || warn "The number of unique terms is not $number_unique_terms, it is: ", $number_of_descendents;

# Assoc one CCO-ID to GO-ID
my %go_cco_ids = ();
my $cco_id_prefix = 'CCO:';     # idspace (CCO)
my $cco_id_type   = 'P';        # subnamespace (P=Process)
my @cco_id_number;              # 7 digits

# If the assoc file already exists, open it and load the entries:
if (-e "$go_cco_ids_table_path") {
	open (GO_CCO_IDS_FH, "$go_cco_ids_table_path") || die "The association table file couldn't be opened";
	my @go_cco = <GO_CCO_IDS_FH>;
	close (GO_CCO_IDS_FH);
	
	my $max = 0; 
	foreach (@go_cco) {
		($go_cco_ids{$1} = $2, $max = ($3>$max)?$3:$max) if (/^(GO:\d{7})\t(CCO:[A-Z](\d{7}))/g); 
	}
	$max += 10000000;
	for (my $i = 1; $i <= 7; $i++){
		push @cco_id_number, substr($max, $i, 1);
	}

	# re-open the file to update it
	open (GO_CCO_FH, ">$go_cco_ids_table_path") || croak "The association table file couldn't be re-opened";
	
	if (-e "$go_ids_in_cco_path") { # if the go ids in cco table exists
		open (GO_IN_CCO_FH, ">$go_ids_in_cco_path") || croak "The file couldn't be openend (GO IDs in CCO)";
		
		# TODO get the IDs from the central repository.
		foreach my $t (sort {$a->id() cmp $b->id()} @descendents){
			my $go_identifier  = $t->id();
			my $cco_identifier = $go_cco_ids{$go_identifier};
			
			if (!defined $cco_identifier) {
				# Get the array filled with current ID
				my @arr = split ('', join ('', @cco_id_number) + 1);
				# Add fore-zeros
				for (my $i = scalar(@arr); $i < scalar(@cco_id_number); $i++) {
					unshift (@arr, '0');
				}
				@cco_id_number = @arr;
				$cco_identifier = $cco_id_prefix.$cco_id_type.(join ('', @cco_id_number));
				$go_cco_ids{$go_identifier} = $cco_identifier;
			}
			print GO_CCO_FH $go_identifier."\t".$cco_identifier."\n"; # GO_ID <-> CCO_ID
			print GO_IN_CCO_FH $go_identifier."\n";                   # GO_IDs (used in CCO)
		}
		close (GO_IN_CCO_FH);
	} else {
		croak "It must never come here!"; 
	}
	close (GO_CCO_FH);
} else { # first time
	@cco_id_number = (0,0,0,0,0,0,0); # 7 digits
	
	# Open the assocciation file: GO_ID vs CCO_ID
	open (GO_CCO_FH, ">$go_cco_ids_table_path") || croak "The association table file couldn't be created";
	open (GO_IN_CCO_FH, ">$go_ids_in_cco_path") || croak "The file couldn't be created (GO IDs in CCO)";
	
	# TODO add the modification date to this assoc file
	print GO_CCO_FH << 'PREAMBLE_GOID_CCO_ID';
!GO_ID <-> CCO_ID equivalence table
!version: $Id: go_cco.ids 1 $
!
! File automatically generated from the GO and CCO.
!
!GO ID		CCO ID		status
!
!GO:0000022	CCO:P0000001	
!GO:0000067	CCO:P0000002
!GO:0000069	CCO:P0000003
!
PREAMBLE_GOID_CCO_ID

	print GO_IN_CCO_FH << 'PREAMBLE_GO_IN_CCO_ID';
!GO IDs used in CCO
!version: $Id: go_in_cco.ids 1 $
!
! File automatically generated from the GO and CCO.
!
!GO ID		status
!
!GO:0000022	
!GO:0000070
!GO:0000072
!
PREAMBLE_GO_IN_CCO_ID
	
	# TODO get the IDs from the central repository.
	foreach my $t (sort {$a->id() cmp $b->id()} @descendents){
		my $go_identifier  = $t->id();
		# Get the array filled with current ID
		my @arr = split ('', join ('', @cco_id_number) + 1);
		
		# Add fore-zeros
		for (my $i = scalar(@arr); $i < scalar(@cco_id_number); $i++) {
			unshift (@arr, '0');
		}
		
		@cco_id_number = @arr;
		 
		my $cco_id = $cco_id_prefix.$cco_id_type.(join ('', @cco_id_number));
		$go_cco_ids{$go_identifier} = $cco_id;
		
		# create the equivalence table: GO_ID <-> CCO_ID
		print GO_CCO_FH $go_identifier."\t".$cco_id."\n";
		
		# write the GO IDs used in CCO
		print GO_IN_CCO_FH $go_identifier."\n";
	}
	close (GO_IN_CCO_FH);
	close (GO_CCO_FH);
}

# assert
(keys(%go_cco_ids) == $number_unique_terms) || warn "The number of unique terms ids is not $number_unique_terms, it is: ", scalar (keys %go_cco_ids);
#print "CCO-id of 'GO:0007049': ".$go_cco_ids{"GO:0007049"};
##############################################################################
#
# IDs for the processes
#
my $cco_id_p_map = OBO::CCO::CCO_ID_Term_Map->new($cco_p_ids_path); # Set of [P]rocess IDs
# walk thru the (unique) terms (Processes) to fill the IDs table: cco_p.ids
foreach my $entry (sort {$go_cco_ids{$a->id()} cmp $go_cco_ids{$b->id()}} @descendents){
	if (!$cco_id_p_map->contains_value($entry->name)) { # Has an ID been already associated to this term?
		$cco_id_p_map->put($go_cco_ids{$entry->id()}, $entry->name);
	}
}
$cco_id_p_map->write_map($cco_p_ids_path); 
##############################################################################
#
# CCO in OBO: Generate 'dirty_pre_cco.obo' from '../obo/cco_from_go.obo'
#
##############################################################################
my $parser = OBO::Parser::OBOParser->new();
my $cco_from_go_file = "../obo/cco_from_go.obo"; # generated above
my $dirty_onto = $parser->work($cco_from_go_file);

croak "The numer of terms is not '", $number_unique_terms, "'" if ($dirty_onto->get_number_of_terms() != $number_unique_terms);

# preambule: some OBO header tags
$dirty_onto->idspace_as_string("CCO", "http://www.cellcycleontology.org/ontology/CCO");
$dirty_onto->default_namespace("cellcycle_ontology");
$dirty_onto->remark("The Cell-Cycle Ontology");

# walk thru the (unique) terms (Processes)
foreach my $entry (@{$dirty_onto->get_terms()}){
	
	# CCO ID (corresponding to the GO ID)
	my $current_go_id = $entry->id();
	$dirty_onto->set_term_id($entry, $go_cco_ids{$current_go_id});
		
	# EASR: there are 12 terms without a def (03.01.06)
	# EASR: there are 5  terms without a def (16.01.07)
	
	# xref's
	my $xref = OBO::Core::Dbxref->new();
	$xref->name($current_go_id);
	my $xref_set = $dirty_onto->get_term_by_id($entry->id())->xref_set();
	$xref_set->add($xref);
	# add the alt_id's as xref's
	foreach my $alt_id ($entry->alt_id()->get_set()){
		my $xref_alt_id = OBO::Core::Dbxref->new();
		$xref_alt_id->name($alt_id);
		$xref_set->add($xref_alt_id);
	}
	$entry->alt_id()->clear() if (defined $entry->alt_id()); # erase the alt_id(s) from this 'entry'
}
croak "The number of terms is not '", $number_unique_terms, "'" if ($dirty_onto->get_number_of_terms() != $number_unique_terms);
# export the dirty ontology
open (FH, ">dirty_pre_cco.obo") || die "The dirty pre-ontology cannot be created: ", $!;
$dirty_onto->export(\*FH, 'obo');
close FH;
