# $Id: pipeline_omcl.pl 1 2007-08-24 13:34:19Z erant $
#
# Module  : pipeline_omcl.pl
# Purpose : The OrthoMCL pipeline.
# License : Copyright (c) 2007 Erick Antezana. All rights reserved.
#           This program is free software; you can redistribute it and/or
#           modify it under the same terms as Perl itself.
# Contact : Erick Antezana <erant@psb.ugent.be>
#
################################################################################
use Carp;
use strict;
use warnings;

BEGIN {
	unshift @INC, '../../onto-perl';
}

#
# Paths
#
my $pipeline_path = "../pipeline/";
my $fasta_path   = "../fasta/";
my $omcl_path    = "../omcl/";
my $uniprot_path = "../uniprot/";

use OBO::Parser::OBOParser;
use OBO::CCO::OrthoMCLParser;
use OBO::Util::Ontolome;
use OBO::CCO::UniProtParser;
use OBO::CCO::GoaParser;

my $date = `date`; # for log

my @taxon_names = ('Arabidopsis thaliana',
					'Schizosaccharomyces pombe',
					'Saccharomyces cerevisiae',					,
					'Homo sapiens'
					);

my @uniprot_sprot_trembl_dat_path = (
								'../uniprot/uniprot_sprot_trembl_fungi.dat',
								'../uniprot/uniprot_sprot_trembl_plants.dat',
								'../uniprot/uniprot_sprot_trembl_human.dat'
								);
								
my %uniprot_sprot_trembl_dat_file_name_by_taxon_id = (
        'Schizosaccharomyces pombe' => '../uniprot/uniprot_sprot_trembl_fungi.dat', # pombe and cerevisiae share the same file
        'Saccharomyces cerevisiae'  => '../uniprot/uniprot_sprot_trembl_fungi.dat', # pombe and cerevisiae share the same file
        'Arabidopsis thaliana'      => '../uniprot/uniprot_sprot_trembl_plants.dat',
        'Homo sapiens'              => '../uniprot/uniprot_sprot_trembl_human.dat'
);

my %uniprot_sprot_trembl_out_file_name_by_taxon_id = (
        'Schizosaccharomyces pombe' => '../uniprot/uniprot_sprot_trembl_S_pombe.out',
        'Saccharomyces cerevisiae'  => '../uniprot/uniprot_sprot_trembl_S_cerevisiae.out',
        'Arabidopsis thaliana'      => '../uniprot/uniprot_sprot_trembl_A_thaliana.out',
        'Homo sapiens'              => '../uniprot/uniprot_sprot_trembl_H_sapiens.out'
);

my %uniprot_sprot_trembl_out_file_name_by_taxon_number = (
        '4896' => '../uniprot/uniprot_sprot_trembl_S_pombe.out',
        '4932' => '../uniprot/uniprot_sprot_trembl_S_cerevisiae.out',
        '3702' => '../uniprot/uniprot_sprot_trembl_A_thaliana.out',
        '9606' => '../uniprot/uniprot_sprot_trembl_H_sapiens.out'
);

# nuevos:
my %organism_by_taxon_id = (
	'4896' => 'Schizosaccharomyces pombe organism',
	'4932' => 'Saccharomyces cerevisiae organism', 
	'3702' => 'Arabidopsis thaliana organism',
	'9606' => 'Homo sapiens organism'
);

my %organism_term_id_by_taxon_id = (
	'4896' => 'CCO:T0000017',  # 'Schizosaccharomyces pombe organism',
	'4932' => 'CCO:T0000016',  # 'Saccharomyces cerevisiae organism', 
	'3702' => 'CCO:T0000034',  # 'Arabidopsis thaliana organism',
	'9606' => 'CCO:T0000004'   # 'Homo sapiens organism'
);

my %organism_short_by_taxon_id = (
	'4896' => 'S_pombe',
	'4932' => 'S_cerevisiae', 
	'3702' => 'A_thaliana',
	'9606' => 'H_sapiens'
);

my %uniprot_sprot_trembl_CCO_file_name_by_taxon_id = (         # for UniProt (core cco + added) = CCO
        '4896' => '../uniprot/uniprot_sprot_trembl_S_pombe.CCO',
        '4932' => '../uniprot/uniprot_sprot_trembl_S_cerevisiae.CCO',
        '3702' => '../uniprot/uniprot_sprot_trembl_A_thaliana.CCO',
        '9606' => '../uniprot/uniprot_sprot_trembl_H_sapiens.CCO'
);

my $merged_uniprot_sprot_trembl_out = "../uniprot/uniprot_sprot_trembl.out";
my $merged_uniprot_sprot_trembl_CCO = "../uniprot/uniprot_sprot_trembl.CCO";

my $cmd;

open (OMCL_LOG, ">>pipeline_omcl.log") || die "The pipeline_omcl.log file couldn't be opened";
print OMCL_LOG "\nThe pipeline OMCL began at: $date\n";
		
##
## Step 0: Cleaning the directories from a previous execution
##
#chomp($date = `date`);
#print OMCL_LOG "Step 0: Cleaning the directories from previous execution ($date): ";
#$cmd = "rm -rf ../fasta/all_blast.log ../fasta/all_blast.out ../fasta/all.fa ../fasta/Ath.fa ../fasta/Hsa.fa ../fasta/omcl_input_file_bpo.idx ../fasta/omcl_input_file_bpo.se ../fasta/all.bpo ../fasta/orthomcl.log ../fasta/all.gg ../fasta/Sce.fa ../fasta/Spo.fa";
##system $cmd;
#chomp($date = `date`);
#print OMCL_LOG "OK ($date)\n";
#
##
## Step 1: Checking whether the filtered UniProt files are out there
##		  INPUT  : Uniprot files
##		  OUTPUT : yes/no
##
#foreach my $taxon_name (@taxon_names) {
#	chomp($date = `date`);
#	print OMCL_LOG "Step 1: Checking whether the filtered UniProt files are out there for $taxon_name ($date): ";
#	
#	my $f_name = $uniprot_sprot_trembl_out_file_name_by_taxon_id{$taxon_name};
#	if ((-e $f_name) && (-r $f_name)) {
#		chomp($date = `date`);
#		print OMCL_LOG "OK ($date)\n";
#	} else {
#		chomp($date = `date`);
#		print OMCL_LOG "ERROR ($date)\n";
#		die "File not found: '$f_name'.\n";
#	}	
#}
#
##
## Step 2: Getting the fasta files
##		  INPUT  : $uniprot_sprot_trembl_out_file_name_by_taxon_id{}
##		  OUTPUT : $output_fasta_file_path per taxon name
##
#my %organism_short_by_taxon_name = (
#	'Schizosaccharomyces pombe' => 'Spo',
#	'Saccharomyces cerevisiae'  => 'Sce', 
#	'Arabidopsis thaliana'      => 'Ath',
#	'Homo sapiens'              => 'Hsa'
#);
#
#foreach my $taxon_name (@taxon_names) {
#	chomp($date = `date`);
#	print OMCL_LOG "Step 2: Getting the fasta files for $taxon_name ($date): ";
#	my $output_fasta_file_path = $fasta_path.$organism_short_by_taxon_name{$taxon_name}.'.fa';
#	$cmd = "perl get_fasta.pl < $uniprot_sprot_trembl_out_file_name_by_taxon_id{$taxon_name} > $output_fasta_file_path";
#	system $cmd;
#	chomp($date = `date`);
#	print OMCL_LOG "OK ($date)\n";
#}
#
##
## Step 3: Merging the fasta files into only one
##
#my $merged_fasta_file_path = $fasta_path."all.fa";
#chomp($date = `date`);
#print OMCL_LOG "Step 3: Merging the fasta files into only one ($date): ";
#$cmd = "cat ../fasta/Spo.fa ../fasta/Sce.fa ../fasta/Ath.fa ../fasta/Hsa.fa > $merged_fasta_file_path";
#system $cmd;
#chomp($date = `date`);
#print OMCL_LOG "OK ($date)\n";
#
##
## Step 4: Creating and formating the DB
##
#chomp($date = `date`);
#print OMCL_LOG "Step 4: Creating and formating the DB ($date): ";
##$cmd = "dc_new_target_rt -mach cauldron.fvms.ugent.be -template ../fasta/format_aa_into_aa -targ ccodb -desc \"CCO database, contains Ath, Hsa, Sce, Spo\" -source $merged_fasta_file_path";
#$cmd = "formatdb -i $merged_fasta_file_path -p t -n $fasta_path/ccodb";
#system $cmd;
#chomp($date = `date`);
#print OMCL_LOG "OK ($date)\n";
#
##
## Step 5: Blasting all-against-all
##
#my $all_blast_out_path = $fasta_path."all_blast.out";
#chomp($date = `date`);
#print OMCL_LOG "Step 5: Blasting all-against-all ($date): ";
##$cmd = "dc_template_rt -mach cauldron.fvms.ugent.be -template ../fasta/omcl_tblastp -targ ccodb -query $merged_fasta_file_path > $all_blast_out_path 2>../fasta/all_blast.log";
#$cmd = "blastall -p blastp -i $merged_fasta_file_path -d $fasta_path/ccodb -e 1e-05 -o $all_blast_out_path -m 8 -a 24 -v 1000 -b 1000 2>../fasta/all_blast.log";
#
#system $cmd;
#chomp($date = `date`);
#print OMCL_LOG "OK ($date)\n";
#
##
## Step 6: Making a GG file for OMCL 
##
#chomp($date = `date`);
#print OMCL_LOG "Step 6: Making a GG file for OMCL ($date): ";
#
#chdir("../fasta") or warn "Cannot change directory to fasta: $!"; # now in cco/fasta
#
#$cmd = "perl ../pipeline/make_gg_file.pl  Spo.fa Sce.fa Ath.fa Hsa.fa > ../omcl/all.gg";
#system $cmd;
#chdir("../pipeline") or warn "Cannot change directory to pipeline: $!"; # now in cco/pipeline
#chomp($date = `date`);
#print OMCL_LOG "OK ($date)\n";
#
##
## Step 7: Creating a BPO file for OMCL
##
#chomp($date = `date`);
#print OMCL_LOG "Step 7: Creating a BPO file for OMCL ($date): ";
#$cmd = "perl parse_blastp.pl < $all_blast_out_path > ../omcl/all.bpo";
#system $cmd;
#chomp($date = `date`);
#print OMCL_LOG "OK ($date)\n";
#
##
## Step 8: OMCL Clustering
##
#
#chdir "$omcl_path" or die "can't cd to $omcl_path: #!\n"; # now in cco/omcl
#
#my $orthomcl_log_path = "orthomcl.log";
#chomp($date = `date`);
#print OMCL_LOG "Step 8: OMCL Clustering ($date): ";
##$cmd = "perl /group/biocomp/cbd/users/erant/workspace/local/ORTHOMCLV1.4/orthomcl.pl --mode 4 --pi_cutoff 25 --inflation 4 --pv_cutoff 1e-6 --bpo_file ../fasta/all.bpo --gg_file ../fasta/all.gg 2>$orthomcl_log_path";
##$cmd = "perl orthomcl.pl --mode 3 --inflation 4 --pv_cutoff 1e-6 --blast_file $all_blast_out_path --gg_file ../fasta/all.gg 2>$orthomcl_log_path";
#$cmd = "perl orthomcl.pl --mode 4 --inflation 4 --pv_cutoff 1e-6 --bpo_file all.bpo --gg_file all.gg 2>$orthomcl_log_path";
#system $cmd;
##chdir "$pipeline_path" or die "can't cd to $pipeline_path: #!\n";
#chomp($date = `date`);
#print OMCL_LOG "OK ($date)\n";
#
##
## Step 9: Looking for the result file: all_orthomcl.out
##
#chomp($date = `date`);
#print OMCL_LOG "Step 9: Looking for the result file: all_orthomcl.out ($date): ";
##my $orthomcl_log_path = $omcl_path.$orthomcl_log;
#my $orthomcl_result_file_path;
#if ((-r $orthomcl_log_path)) {
#	open (MCL, "grep -P 'Final ORTHOMCL Result: (.*) generated' $orthomcl_log_path |");
#	if (my $line = <MCL>) {
#		chomp($line);
#		$orthomcl_result_file_path = ($1)?$1:"" if ($line =~ /Final ORTHOMCL Result: (.*) generated/);
#		confess "The orthomcl result file path could not be found" if (!$orthomcl_result_file_path);
#		close MCL;
#	} else {
#		confess "The orthomcl result file path could not be found in file: '$orthomcl_log_path'";
#	}
#} else {
#	confess "The orthomcl log file could not be found";
#}
#chomp($date = `date`);
#print OMCL_LOG "OK ($date)\n";

#
# Step 10: Filtering clusters
#			INPUT  : core cco proteins from uniprot
#			OUTPUT : clusters
#

my $orthomcl_result_file_path = $omcl_path.'all_orthomcl.out'; # the  only change w.r.t svn

confess "The orthomcl result file path could not be found" if (!$orthomcl_result_file_path);
chomp($date = `date`);
print OMCL_LOG "Step 10: Filtering clusters ($date): "; # still in cco/omcl
my $filter_clusters_out = "filter_clusters.out";
#$cmd = "perl filter_clusters.pl $orthomcl_result_file_path < ../uniprot/uniprot_sprot_trembl_A_thaliana.cco ../uniprot/uniprot_sprot_trembl_H_sapiens.cco ../uniprot/uniprot_sprot_trembl_S_pombe.cco ../uniprot/uniprot_sprot_trembl_S_cerevisiae.cco > $filter_clusters_out";
$cmd = "perl ../pipeline/filter_clusters.pl $orthomcl_result_file_path < ../uniprot/uniprot_sprot_trembl_A_thaliana.cco ../uniprot/uniprot_sprot_trembl_H_sapiens.cco ../uniprot/uniprot_sprot_trembl_S_pombe.cco ../uniprot/uniprot_sprot_trembl_S_cerevisiae.cco > $filter_clusters_out";

system $cmd;
chomp($date = `date`);
print OMCL_LOG "OK ($date)\n";

#
# Step 11: OrthoMCLParser execution
# OUTPUT: pre_omcl.obo
#
chomp($date = `date`);
print OMCL_LOG "Step 11: OrthoMCLParser execution ($date): ";
my %taxa = (
	'Ath' => ['Arabidopsis thaliana organism', "../doc/cco_b_A_thaliana.ids"],
	'Hsa' => ['Homo sapiens organism', "../doc/cco_b_H_sapiens.ids"],
	'Sce' => ['Saccharomyces cerevisiae organism', "../doc/cco_b_S_cerevisiae.ids"],
	'Spo' => ['Schizosaccharomyces pombe organism', "../doc/cco_b_S_pombe.ids"],
	);

my @files = (
	"../obo/pre_pre_omcl.obo",
	"../doc/cco_u.ids",
	"../doc/cco_t.ids",
	"../doc/cco_o.ids",
	"../doc/cco_b.ids",
);

my $my_parser = OBO::CCO::OrthoMCLParser->new();
my $clusters = $my_parser->parse($filter_clusters_out);
my $ontology = $my_parser->work($clusters, \@files, \%taxa);

chdir "$pipeline_path" or die "can't cd to $pipeline_path: #!\n"; # now in cco/pipeline

chomp($date = `date`);
print OMCL_LOG "OK ($date)\n";

#
# Step 11.1: Add 'is_a: CCO:B0000000 ! core cell cycle protein' to the core cell cycle proteins in 'pre_omcl.obo'
# INPUT : pre_pre_omcl.obo ($ontology)
# OUTPUT: pre_omcl.obo = pre_pre_omcl.obo + core cell cycle protein links
# USES  : pre_cco.obo
#
chomp($date = `date`);
print OMCL_LOG "Step 11.1: Adding 'is_a: CCO:B0000000 ! core cell cycle protein' ($date): ";

my $my_obo_parser  = OBO::Parser::OBOParser->new();
my $pre_cco_onto   = $my_obo_parser->work("../obo/pre_cco.obo"); # $pre_cco_onto is also used later

$ontology->add_term_as_string('CCO:B0000000', 'core cell cycle protein');
my $cccp_term = $ontology->get_term_by_id('CCO:B0000000');
my @proteins = @{$ontology->get_terms("CCO:B.*")}; # get all the B's (proteins)
foreach my $protein (@proteins) {
	if ($pre_cco_onto->has_relationship_id($protein->id()."_is_a_CCO:B0000000")) {
		$ontology->create_rel($protein, "is_a", $cccp_term);
	}
}
open (my $FH, ">../obo/pre_omcl.obo") || die "Cannot write OBO file: ", $!;
$ontology->export(\*$FH);
close $FH;
chomp($date = `date`);
print OMCL_LOG "OK ($date)\n";

#
# Step 12: Load data from UniProt in 'pre_omcl.obo'
# INPUT : pre_omcl.obo
# OUTPUT: omcl.obo
#
chomp($date = `date`);
print OMCL_LOG "Step 12: Load data from UniProt in pre_omcl.obo ($date): ";
### EASR<<
chomp($date = `date`);
print OMCL_LOG "\nStarting to load data ($date): \n\n";
	
#
# Produce the needed uniprot file by ontology (../obo/pre_omcl.obo)
# Reuse the file $uniprot_sprot_trembl_out_file_name_by_taxon_id which was got by filter_uniprot.pl
# 
chomp($date = `date`);
print OMCL_LOG "\tProduce the needed uniprot file for 'pre_omcl.obo' ($date): ";

# Get the merged uniprot source:
my $merge_cmd= "/bin/cat";
foreach my $taxon_id (keys %organism_by_taxon_id) {
	$merge_cmd .= " $uniprot_sprot_trembl_out_file_name_by_taxon_number{$taxon_id}";
}
$merge_cmd .= " > $merged_uniprot_sprot_trembl_out"; # this file IS NOT used yet...maybe one day...
system $merge_cmd;

my $cmd2 = "perl filter_uniprot_by_ontology.pl ../obo/pre_omcl.obo < $merged_uniprot_sprot_trembl_out > $merged_uniprot_sprot_trembl_CCO";
system $cmd2;
chomp($date = `date`);
print OMCL_LOG "OK ($date)\n\n";

my $input_obo  = "../obo/pre_omcl.obo";
my $output_obo;

# add some missing terms/rels to the pre_omcl.obo
my $myp = OBO::Parser::OBOParser->new();
my $myo = $myp->work($input_obo);

$myo->add_term_as_string('CCO:U0000007', 'cell cycle protein');
$myo->add_term_as_string('CCO:U0000008', 'cell cycle gene');
$myo->add_term_as_string('CCO:U0000010', 'modified protein');
$myo->add_term_as_string('CCO:U0000011', 'cell cycle modified protein');

$myo->add_relationship_type_as_string('source_of', 'source_of');
$myo->add_relationship_type_as_string('encoded_by', 'encoded_by');
$myo->add_relationship_type_as_string('codes_for', 'codes_for');
$myo->add_relationship_type_as_string('transformation_of', 'transformation_of');
$myo->add_relationship_type_as_string('transforms_into', 'transforms_into');

open (FH, ">$input_obo") || die "Could produce the file $input_obo: ", $!;
$myo->export(\*FH);
close FH;

foreach my $taxon_id (keys %organism_by_taxon_id) {
	my $organism = $organism_short_by_taxon_id{$taxon_id};
	my $taxon = $organism_by_taxon_id{$taxon_id};
	my $organism_id = $organism_term_id_by_taxon_id{$taxon_id};
	#
	# Produce the needed uniprot files by ontology (../obo/cco_I_$organism.obo)
	# Reuse the file $uniprot_sprot_trembl_out_file_name_by_taxon_number which was got by filter_uniprot.pl
	# 
	chomp($date = `date`);
	print OMCL_LOG "\tProduce the needed uniprot file by ontology ($input_obo) ($date): ";
	my $uni_omcl_in  = $uniprot_sprot_trembl_out_file_name_by_taxon_number{$taxon_id};
	my $uni_omcl_out = $uniprot_sprot_trembl_CCO_file_name_by_taxon_id{$taxon_id}.".omcl";
	my $cmd = "perl filter_uniprot_by_ontology.pl $input_obo $organism_id < $uni_omcl_in > $uni_omcl_out";
	system $cmd;
	chomp($date = `date`);
	print OMCL_LOG "OK ($date)\n";

	$output_obo = "../obo/pre_omcl_".$organism.".obo";
	#
	# Parse the filtered data and add the proteins to CCO as well as their genes
	# $uniprot_sprot_trembl_CCO_file_name_by_taxon_id is obtained with cco_I_$organism.obo
	#
	load_uniprot_data_from_orthomcl (
		$input_obo, 
		$output_obo, 
		$taxon, 
		$organism, 
		$uni_omcl_out); # UniProtParser is used here!

	$input_obo = $output_obo; # next ontology...
}
chomp($date = `date`);
print OMCL_LOG "\nFinishing the loading UniProt data procedure ($date)\n";
### EASR>>
my $cmd3 = "cp $output_obo ../obo/omcl.obo";
system $cmd3;

chomp($date = `date`);
print OMCL_LOG "OK ($date)\n";


# Integration of  GOA associations 
# step1 - merging pre_cco_core.obo (source of GO terms) and omcl.obo
chomp($date = `date`);
print OMCL_LOG " Merging ontologies 1 ($date): ";
my $ome1           = OBO::Util::Ontolome->new();
my $pre_cco_core_obo_path                    = "../obo/pre_cco_core.obo";
my $pre_cco_core_onto      = $my_obo_parser->work($pre_cco_core_obo_path);
my $omcl_obo_path = "../obo/omcl.obo";
my $omcl_onto      = $my_obo_parser->work($omcl_obo_path);

my $pre_cco_core_omcl           = $ome1->union($pre_cco_core_onto, $omcl_onto);
my $pre_cco_core_omcl_obo_path = "../obo/pre_cco_core_omcl.obo";
open (FH, ">".$pre_cco_core_omcl_obo_path) || die "Error while exporting the merge file: '", $pre_cco_core_omcl_obo_path, "'", $!;
$pre_cco_core_omcl->export(\*FH);
close FH;
chomp($date = `date`);
print OMCL_LOG "OK ($date)\n";


# step2 - adding GOA associations
my $all_cco_goa = "../goa/all_cco.goa";
my $cat_cmd = "cat ../goa/*_*_cf.*  > $all_cco_goa";
system $cat_cmd;
my $goa_parser = OBO::CCO::GoaParser->new();
my  @files1 = (
$pre_cco_core_omcl_obo_path,
"../obo/omcl_goa.obo",
$all_cco_goa
);
my $omcl_goa_onto = $goa_parser->add_go_assocs(\@files1);
chomp($date = `date`);
print OMCL_LOG "\tIntegrated  GOA associations ($date)\n";


#
# Step 13: Merging ontologies 2: 
#					union(pre_cco.obo, omcl.obo) <--- Entire CCO and ontology generated from OMCL 
# OUTPUT: cco.obo (the final ontology!!!)
#
chomp($date = `date`);
print OMCL_LOG "Step 13: Merging ontologies 2($date): ";
my $ome2           = OBO::Util::Ontolome->new();
# my $omcl_onto      = $my_obo_parser->work("../obo/omcl.obo"); the original code

my $cco_obo_and_omcl_obo_merged1           = $ome2->union($pre_cco_onto, $omcl_goa_onto);
#my $cco_obo_and_omcl_obo_merged2           = $ome2->union($omcl_onto, $pre_cco_onto);
#my $cco_obo_and_omcl_obo_merged3           = $ome2->union($cco_obo_and_omcl_obo_merged1, $cco_obo_and_omcl_obo_merged2);

my $cco_obo_and_omcl_obo_merged_file_name = "../obo/cco.obo";

# export back to obo
open (FH, ">".$cco_obo_and_omcl_obo_merged_file_name) || die "Error while exporting the merge file: '", $cco_obo_and_omcl_obo_merged_file_name, "'", $!;
$cco_obo_and_omcl_obo_merged1->export(\*FH);
close FH;
chomp($date = `date`);
print OMCL_LOG "OK ($date)\n";

#
# Last Step:
#
print OMCL_LOG "The OMCL pipeline ended at: ".`date`."\n";
close OMCL_LOG;
exit 0;

################################################################################
#
# Load the data from UniProt by using the UniProtParser
#
# INPUT   : "../obo/pre_omcl.obo"
# OUTPUT  : "../obo/omcl.obo"
#
################################################################################
sub load_uniprot_data_from_orthomcl {
	chomp($date = `date`);
	my ($input_obo, $output_obo, $taxon, $organism, $uniprot_sprot_trembl_cco) = @_;
	print OMCL_LOG "\tLoading the data from UniProt for $organism ($date) with files $input_obo and $output_obo: ";
	select((select(OMCL_LOG), $|=1)[0]);
	if ($taxon && $organism && $uniprot_sprot_trembl_cco) {
		my @files = (
				$input_obo,  #"../obo/pre_omcl.obo",
				$output_obo, #"../obo/omcl.obo",
				$uniprot_sprot_trembl_cco, 
				"../doc/cco_b_$organism.ids",
				"../doc/cco_b.ids",
				"../doc/cco_g_$organism.ids",
				"../doc/cco_g.ids",
				);
		my $my_uniprot_parser = OBO::CCO::UniProtParser->new();
		my $ontology = $my_uniprot_parser->work(\@files, $taxon);
		chomp($date = `date`);
		print OMCL_LOG "OK ($date)\n";
	} else {
		chomp($date = `date`);
		print OMCL_LOG "ERROR ($date)\n";
	}
}

