# The code in this file in already in the pipeline, it has 
# been created for testing the filtering of the uniprot files
# eventually, this file should be one of the pipeline modules.
use Carp;
use strict;
use warnings;

my $workspace = '/group/biocomp/cbd/users/erant/workspace/ONTO-PERL/';

BEGIN {
	unshift @INC, '/group/biocomp/cbd/users/erant/workspace/ONTO-PERL';
}

use OBO::Parser::OBOParser;

use constant NL					=> "\n";

my $date;

my %organism_by_taxon_id = (
	'4896' => 'Schizosaccharomyces pombe organism',
	'4932' => 'Saccharomyces cerevisiae organism', 
	'3702' => 'Arabidopsis thaliana organism',
	'9606' => 'Homo sapiens organism'
);
my %organism_short_by_taxon_id = (
	'4896' => 'S_pombe',
	'4932' => 'S_cerevisiae', 
	'3702' => 'A_thaliana',
	'9606' => 'H_sapiens'
);
my %uniprot_sprot_trembl_dat_file_name_by_taxon_id = (
        '4896' => '../uniprot/uniprot_sprot_trembl_fungi.dat', # pombe and cerevisiae share the same file
        '4932' => '../uniprot/uniprot_sprot_trembl_fungi.dat', # pombe and cerevisiae share the same file
        '3702' => '../uniprot/uniprot_sprot_trembl_plants.dat',
        '9606' => '../uniprot/uniprot_sprot_trembl_human.dat'
); 

my %uniprot_sprot_trembl_cco_file_name_by_taxon_id = (
        '4896' => '../uniprot/uniprot_sprot_trembl_S_pombe.cco',
        '4932' => '../uniprot/uniprot_sprot_trembl_S_cerevisiae.cco',
        '3702' => '../uniprot/uniprot_sprot_trembl_A_thaliana.cco',
        '9606' => '../uniprot/uniprot_sprot_trembl_H_sapiens.cco'
);

chomp($date = `date`);
print "Starting to load data ($date): ".NL.NL;
foreach my $taxon_id (keys %organism_by_taxon_id) {
	my $organism = $organism_short_by_taxon_id{$taxon_id};
	my $taxon = $organism_by_taxon_id{$taxon_id};

	# 1. Generate the files: uniprot_sprot_trembl_(S_pombe|S_cerevisiae|A_thaliana|H_sapiens).cco
	filter_uniprot_files(
			$uniprot_sprot_trembl_dat_file_name_by_taxon_id{$taxon_id},
			$uniprot_sprot_trembl_cco_file_name_by_taxon_id{$taxon_id},
			$organism_short_by_taxon_id{$taxon_id}
			);

	# 2. parse the filtered data and add the proteins to CCO as well as their genes
###	load_uniprot_data($taxon, $organism, $uniprot_sprot_trembl_cco_file_name_by_taxon_id{$taxon_id}); # UniProtParser is used here!
}
chomp($date = `date`);
print NL."Finishing the loading data procedure ($date)".NL;
################################################################################
#
# Filter the data from UniProt
# Usage: filter_uniprot_files(dat_file, cco_file, organism)
# TODO Is this method better implemented by using SWISS?
#
################################################################################
sub filter_uniprot_files {
	chomp($date = `date`);
	select((select(STDOUT), $|=1)[0]);
	my ($uniprot_sprot_trembl_dat, $uniprot_sprot_trembl_cco, $organism) = @_;
	print "\tFiltering the data from UniProt for $organism ($date): ";
	if ($uniprot_sprot_trembl_dat && $uniprot_sprot_trembl_cco && $organism) {		
		my $a_parser = OBO::Parser::OBOParser->new();
		my $ontology = $a_parser->work("../obo/pre_cco_$organism.obo");

		#
		# Get all the biopolymers by name:
		#
		my %terms_map_by_name;
		foreach my $term (@{$ontology->get_terms("CCO:B.*")}) { # visit the Biopolymers (only proteins so far!)
			my $cco_protein_uniprot_ac = &get_xref_acc("UniProtKB", $term);
			$terms_map_by_name{$cco_protein_uniprot_ac} = $cco_protein_uniprot_ac;
		}
		#
		# filter up
		#
		local $/ = "\n//\n";
		
		system "cat /dev/null > $uniprot_sprot_trembl_cco"; # clean old file
		
		open FH, ">$uniprot_sprot_trembl_cco" || die "Can't open file ($uniprot_sprot_trembl_cco) for writing!", $!;
		select((select(FH), $|=1)[0]);
		open (UH, "$uniprot_sprot_trembl_dat") || die "The file $uniprot_sprot_trembl_dat could not be opened: ", $!;
		while(<UH>){
			my $entry = $_;
			$_ =~ /AC   (.*)/ ? my $acs = $1 : next;
			chop($acs); # erase the last ';'
			foreach my $ac (split (/;(\s+)?/, $acs)) {
				if (defined $terms_map_by_name{$ac}){
				#if ($ontology->has_term_id($ontology->get_term_by_name($name))){ # TODO use a map! Temporal solution: %terms_map_by_name					print "el ac es: ", $ac, "\n";
					print FH $entry; # print out the result in $uniprot_sprot_trembl_cco
				}
			}
		}
		close UH;
		close FH;
		$/ = "\n";
		chomp($date = `date`);
		print "OK ($date)".NL;
	} else {
		chomp($date = `date`);
		print "ERROR ($date)".NL;
	}
}
################################################################################
# Usage    - get_xref_acc($db, $term)
# Returns  - the name of the external database and the ID (strings)
# Args     - the database name and the term (OBO::Core::Term)
# Function - Given a term, get the xref of a given db. Otherwise, undef
# Comment  - This sub was copied from IntActParser.pm
################################################################################
sub get_xref_acc() {
	my ($db, $term) = @_; 
	my $result_acc = undef;
	my $dbxrefset = $term->xref_set();
	foreach my $xref ($dbxrefset->get_set()) {
		if ($xref->db() eq $db) {
			$result_acc = $xref->acc();
			last;		
		}
	}
	return $result_acc;
}