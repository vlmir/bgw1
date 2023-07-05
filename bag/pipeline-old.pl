# $Id: pipeline.pl 2221 2008-08-17 09:20:41Z Erick Antezana $
#
# Module  : pipeline.pl
# Purpose : The CCO pipeline.
# License : Copyright (c) 2006 Erick Antezana. All rights reserved.
#           This program is free software; you can redistribute it and/or
#           modify it under the same terms as Perl itself.
# Contact : Erick Antezana <erant@psb.ugent.be>
#
################################################################################
BEGIN {
	my $onto_perl_latest = 0;
	$onto_perl_latest ? unshift @INC, '/norstore/user/mironov/workspace/svn/ONTO-PERL-1.25/lib' : unshift @INC, "/norstore/user/mironov/workspace/svn/onto-perl";
}
my $onto_perl_latest = 0;

use Carp;
use strict;
use warnings;
use OBO::Parser::OBOParser;
use OBO::CCO::NCBIParser;
use OBO::CCO::UniProtParser;
use OBO::CCO::GoaParser;
use OBO::CCO::NewIntActParser;
use OBO::CCO::CCO_ID_Term_Map;
use OBO::Util::Ontolome;
use SWISS::Entry;
use Data::Dumper;
use constant NL => "\n";
use constant TB => "\t";

# TODO!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# URGENT: update the cco_u.ids automatically !!!!!
#         it is done manually...
# TODO!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
################################################################################
#
# Directories
#
################################################################################

my $workspace  = "/norstore/user/mironov/workspace";
my $svn_dir = "$workspace/svn";
my $onto_perl_dir = "$svn_dir/onto-perl"; # used only for merge.pl, will  be obsolete
my $cco_dir = "$svn_dir/cco";
my $obo_dir = "$cco_dir/obo";
my $doc_dir = "$cco_dir/doc";
my $xrf_dir = "$cco_dir/xrf";
my $uniprot_dir = "$cco_dir/uniprot";
my $owl_dir = "$cco_dir/owl";
my $goa_dir = "$cco_dir/goa";
my $ncbi_dir = "$cco_dir/ncbi";
my $intact_dir = "$cco_dir/intact";
my $pipeline_dir = "$cco_dir/pipeline";
my $log_dir = "$cco_dir/log";
my $fasta_dir = "$cco_dir/fasta";

my $data_dir = "$svn_dir/data";
my $inhouse_obo_dir = "$data_dir/inhouse";
my $data_obo_dir = "$data_dir/obo";
my $data_ncbi_dir = "$data_dir/ncbi";
my $data_up_dir = "$data_dir/uniprot";
my $data_goa_dir = "$data_dir/goa";

################################################################################
#
# Files
#
################################################################################


# main source and cco from go
my $gene_ontology_obo_path = "$data_obo_dir/gene_ontology.obo";

# extra ontologies file paths
my $ulo_cco_path              = "$obo_dir/ulo_cco.obo";

# generated OBO file path
my $pre_cco_obo_H_sapiens_path    = "$obo_dir/pre_cco_H_sapiens.obo";
my $pre_cco_obo_A_thaliana_path   = "$obo_dir/pre_cco_A_thaliana.obo";
my $pre_cco_obo_S_cerevisiae_path = "$obo_dir/pre_cco_S_cerevisiae.obo";
my $pre_cco_obo_S_pombe_path      = "$obo_dir/pre_cco_S_pombe.obo";

my $cco_I_obo_H_sapiens_path    = "$obo_dir/cco_I_H_sapiens.obo";
my $cco_I_obo_A_thaliana_path   = "$obo_dir/cco_I_A_thaliana.obo";
my $cco_I_obo_S_cerevisiae_path = "$obo_dir/cco_I_S_cerevisiae.obo";
my $cco_I_obo_S_pombe_path      = "$obo_dir/cco_I_S_pombe.obo";

my $cco_obo_H_sapiens_path    = "$obo_dir/cco_H_sapiens.obo";
my $cco_obo_A_thaliana_path   = "$obo_dir/cco_A_thaliana.obo";
my $cco_obo_S_cerevisiae_path = "$obo_dir/cco_S_cerevisiae.obo";
my $cco_obo_S_pombe_path      = "$obo_dir/cco_S_pombe.obo";

# Complete CCO (At, Hu, Sc, Sp)
my $pre_cco_obo_path = "$obo_dir/pre_cco.obo";  # almost complete cco (no OMCL...)
my $cco_obo_path     = "$obo_dir/cco.obo";

# GO vs CCO maps
my $go_cco_ids_table_path = "$doc_dir/go_cco.ids"; # used in get_gene_assoc_data()
my $go_ids_in_cco_path    = "$doc_dir/go_in_cco.ids"; # used in get_gene_assoc_data()

# xrefs file path
my $go_xrf_abbs_path = "$xrf_dir/GO.xrf_abbs"; # used only in load_xrf_data_as_OBO()
my $curator_dbxrefs = "$xrf_dir/GO.curator_dbxrefs";

# NCBI taxonomy file path
my $ncbi_nodes_file_path = "$data_ncbi_dir/nodes.dmp";
my $ncbi_names_file_path = "$data_ncbi_dir/names.dmp";

# intact (or MI) ontology related files
my $psi_mi_obo_filename_path = "$data_obo_dir/psi-mi.obo";

# CCO Core: GO + RO + CCO_RO + NCBI
my $pre_cco_core_obo_path = "$obo_dir/pre_cco_core.obo";

# GOA files
my $goa_file_names_path = "$data_dir/proteome2taxid";

# map files paths
my $cco_p_ids_path = "$doc_dir/cco_p.ids"; # biological processes
my $cco_c_ids_path = "$doc_dir/cco_c.ids"; # cellular components
my $cco_f_ids_path = "$doc_dir/cco_f.ids"; # molecular functions
my $cco_y_ids_path = "$doc_dir/cco_y.ids";
my $cco_t_ids_path = "$doc_dir/cco_t.ids";
my $cco_b_ids_path = "$doc_dir/cco_b.ids";

# tmp file paths
my $clean_pre_cco_obo_path             = "$obo_dir/clean_pre_cco.obo";
#my $pre_ulo_and_relationships_obo_path = "$obo_dir/pre_ulo_and_relationships.obo";
my $tmp_path = "$obo_dir/tmp.obo";

my $biorel_path = "$inhouse_obo_dir/biorel.obo";
my $log_path = "$log_dir/pipeline.log";
my $sprot_dat_path = "$data_up_dir/uniprot_sprot.dat";
my $trembl_dat_path = "$data_up_dir/uniprot_trembl.dat";


################################################################################

#my @taxon_ids = ("3702", "9606", "4932", "4896", '6239', '8355', '7227', '10090');
#my @taxon_labels = ('arath', 'human', 'schpo', 'yeast');
my %taxon_labels = (
	'3702' => 'arath',
	'9606' => 'human',
	'4896' => 'schpo',
	'4932' => 'yeast',
	'6239' => 'caeel',
#	'8355' => 'xenla',
	'7227' => 'drome',
	'10090' => 'mouse'
);

my %taxon_name_by_taxon_id = (
	'4896' => 'Schizosaccharomyces pombe',
	'4932' => 'Saccharomyces cerevisiae',
	'3702' => 'Arabidopsis thaliana',
	'9606' => 'Homo sapiens'
);

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

my %goa_file_name_by_taxon_id = (
	'4896' => '78.S_pombe.goa',
	'4932' => '40.S_cerevisiae.goa',    #S_cerevisiae_ATCC_204508.goa
	'3702' => '3.A_thaliana.goa',
	'9606' => '25.H_sapiens.goa'
);

my %goa_cf_file_name_by_taxon_id = (
	'4896' => '78.S_pombe_cf.goa',
	'4932' => '40.S_cerevisiae_cf.goa',    #S_cerevisiae_ATCC_204508.goa
	'3702' => '3.A_thaliana_cf.goa',
	'9606' => '25.H_sapiens_cf.goa'
);

my @filenames_uniprot_path = (
	"$uniprot_dir/uniprot_sprot_fungi.dat.gz",
	"$uniprot_dir/uniprot_trembl_fungi.dat.gz",
	"$uniprot_dir/uniprot_sprot_plants.dat.gz",
	"$uniprot_dir/uniprot_trembl_plants.dat.gz",
	"$uniprot_dir/uniprot_sprot_human.dat.gz",
	"$uniprot_dir/uniprot_trembl_human.dat.gz"
);
my @uniprot_dat_path = (
	"$uniprot_dir/uniprot_fungi.dat",
	"$uniprot_dir/uniprot_plants.dat",
	"$uniprot_dir/uniprot_human.dat"
);

my %uniprot_dat_file_name_by_taxon_id = (    # proteomes
	'4896' => "$uniprot_dir/uniprot_fungi.dat", # pombe and cerevisiae share the same file
	'4932' => "$uniprot_dir/uniprot_fungi.dat", # pombe and cerevisiae share the same file
	'3702' => "$uniprot_dir/uniprot_plants.dat",
	'9606' => "$uniprot_dir/uniprot_human.dat"
);

my %uniprot_cco_file_name_by_taxon_id = (    # core cco 
	# used by filter_uniprot_files()
	'4896' => "$uniprot_dir/uniprot_S_pombe.cco",
	'4932' => "$uniprot_dir/uniprot_S_cerevisiae.cco",
	'3702' => "$uniprot_dir/uniprot_A_thaliana.cco",
	'9606' => "$uniprot_dir/uniprot_H_sapiens.cco"
);

my %uniprot_out_file_name_by_taxon_id =
  (    # for OMCL and IntActParser
  #used by  filter_uniprot.pl, write_up_map.pl, filter_uniprot_by_ontology.pl,
	'4896' => "$uniprot_dir/uniprot_S_pombe.out",
	'4932' => "$uniprot_dir/uniprot_S_cerevisiae.out",
	'3702' => "$uniprot_dir/uniprot_A_thaliana.out",
	'9606' => "$uniprot_dir/uniprot_H_sapiens.out"
  );

my %uniprot_CCO_file_name_by_taxon_id = 
  (    # for UniProt (core cco + added) = CCO
  # used by: filter_uniprot_by_ontology.pl, load_uniprot_data()
	'4896' => "$uniprot_dir/uniprot_S_pombe.CCO",
	'4932' => "$uniprot_dir/uniprot_S_cerevisiae.CCO",
	'3702' => "$uniprot_dir/uniprot_A_thaliana.CCO",
	'9606' => "$uniprot_dir/uniprot_H_sapiens.CCO"
  );

my %uniprot_map_cco_file_name_by_taxon_id =
  (    # map uniprot with ONLY core cco entries
  # used by write_up_map.pl, get_gene_assoc_data(), parse_psi25
	'4896' => "$uniprot_dir/uniprot_S_pombe_map.cco",
	'4932' => "$uniprot_dir/uniprot_S_cerevisiae_map.cco",
	'3702' => "$uniprot_dir/uniprot_A_thaliana_map.cco",
	'9606' => "$uniprot_dir/uniprot_H_sapiens_map.cco"
  );

my %uniprot_map_file_name_by_taxon_id =
  (    # map uniprot with entire proteome
  # used by write_up_map.pl, parse_psi()
	'4896' => "$uniprot_dir/uniprot_S_pombe_map.all",
	'4932' => "$uniprot_dir/uniprot_S_cerevisiae_map.all",
	'3702' => "$uniprot_dir/uniprot_A_thaliana_map.all",
	'9606' => "$uniprot_dir/uniprot_H_sapiens_map.all"
  );

my %branch_names = (
	"GO:0007049" => "cell cycle",
	"GO:0051301" => "cell division",
	"GO:0008283" => "cell proliferation", # is_a biological process
	"GO:0006260" => "DNA replication"
);

my %adopters = (
	"GO:0007049" => "cell cycle process",
	"GO:0051301" => "cell division process",
	"GO:0008283" => "cell proliferation process",
	"GO:0006260" => "DNA replication process"
);

my %adopter_ids = (
	"cell cycle" => "CCO:Z0000000",
	"cell division" => "CCO:Z0000001",
	"cell proliferation" => "CCO:Z0000002",
	"DNA replication" => 	"CCO:Z0000003"
);

$Carp::Verbose = 1;

my $new_data = 0; 
my $cleanup = 0;

# the 4 steps below are executed only if ARGV[0] eq 'seed'
	my $clean_pre_cco = 1;
	my $xrf =1;
	my $ncbi_taxonomy =1;
	my $typedefs = 1;
	
# the steps below are executed if ARGV[1]
	my $up_filtering_by_taxon = 0;
	my $goa_filtering_by_aspect = 0;
	my $core_proteins_from_goa = 1;

# the steps of the original pipeline
my $UniProt_preprocessing = 0;
my $core_cell_cycle_proteins = 0; # from GOA
my $IntAct_data_integration = 0; 
my $UniProt_data_integration = 0;
my $cc_mf_integration = 0; # from GOA
my $merge_species = 0;
my $orthologs = 0;
my $exports = 0;

my $test_code =0;

################################################################################
#
#
# START!
#
#
################################################################################

my $global_label = shift @ARGV;
my $global_taxon_id = shift @ARGV;
  
print_log ( NL
  . "---------------------------------------------------------------"
  . NL
  . NL
  . "The pipeline started at:");
  
my $ome = OBO::Util::Ontolome->new();
my $obo_parser = OBO::Parser::OBOParser->new(); 

if ($global_label eq 'seed') {
if ($clean_pre_cco) {		
	my $cco_id_p_map = OBO::CCO::CCO_ID_Term_Map->new($cco_p_ids_path);    # Set of [P]rocess IDs

	print_log ( "GETTING BIOLOGICAL PROCESSES FROM GO");
	my ($go, $ulo_go_bp);	
	my $ulo_onto = $obo_parser->work($ulo_cco_path); # print_obo ($ulo_onto, $tmp_path);
	if ( ( -e $gene_ontology_obo_path ) && ( -r $gene_ontology_obo_path ) ) {
		$go =  $obo_parser->work($gene_ontology_obo_path);	
		# get all the cell-cycle relates branches from GO
		my %branches;
		foreach (keys %branch_names) {
			my $id = $_;
			my $root_term = $go->get_term_by_id($id) || confess "The term for $id is not defined", $!;
			my $branch = $go->get_subontology_from($root_term);
#			my $branch = obo2cco ($go, $cco_p_ids_path, 'P', $id); ### Doesn't work in the loop
			$branch = $ome->union($ulo_onto, $branch);
			my $biological_process_term = $branch->get_term_by_id("CCO:U0000002")
			  || croak "The term 'biological process' is not defined $!";
			my $branch_name = $branch_names{$id};
			# the line below is necesssary!
			$root_term = $branch->get_term_by_name($branch_name) || confess "The term for $id is not defined", $!;
			$branch->create_rel($root_term, "is_a", $biological_process_term);
			my $adopter_name = $adopters{$id};
			if (my $adopter = $branch->get_term_by_name($adopter_name)) {
				$branch->create_rel($adopter, "is_a", $biological_process_term);
				adopt_orphans($branch, $adopter);
			}	else {
					my $adopter_id = $adopter_ids{$branch_name};
					my $adopter = create_term ($adopter_id, $adopter_name, "Any process involved in $branch_name.", "[CCO:cco_team]");
					$branch->add_term($adopter);
					$branch->create_rel($adopter, "is_a", $biological_process_term);
					$branch->create_rel($adopter, "part_of", $root_term);
					adopt_orphans($branch, $adopter);
#				if ( !$cco_id_p_map->contains_value( $adopter_name ) )	{ print "name for $adopter_name not found\n";
#				} else {
#					print "name $adopter_name already in the map\n";
#				}
			}
			$branches{$id} = $branch;
		}
		$ulo_go_bp = $ome->union( values %branches );
		print_log ( "OK" );	
	}
	else {		
		print_log ( "ERROR" );
		croak "File not found: '$gene_ontology_obo_path'\n";
	}
	
	print_log ( "CONVERTING GO TO CCO");
	$ulo_go_bp = obo2cco ($ulo_go_bp, $cco_p_ids_path, 'P');
	print_log ( "OK" );
	
	print_log ("ADDING CORE CELL CYCLE  PROTEIN");
	my $protein = $ulo_go_bp->get_term_by_name('cell cycle protein')
	  || croak "The term 'cell cycle protein' is not defined $!";
	my $core_cell_cycle_protein = create_term ('CCO:B0000000', 'core cell cycle protein', "A protein being considered as principal in the regulation of the cell cycle process.", "[CCO:cco_team]");
	$ulo_go_bp->add_term($core_cell_cycle_protein);
	$ulo_go_bp->create_rel( $core_cell_cycle_protein, 'is_a',
		$protein );
	print_log ( "OK" );
	
	print_log ( "GETTING CELLULAR COMPONENTS FROM GO" );
	my $go_cc = obo2cco ($go, $cco_c_ids_path, 'C', 'GO:0005575');	
	print_log ( "OK" );	
	
	print_log ( "GETTING MOLECULAR FUNCTIONS FROM GO" ); 
	my $go_mf = obo2cco ($go, $cco_f_ids_path, 'F', 'GO:0003674');	
	print_log ( "OK" );
	
	print_log ("GETTING INTERACTION TYPES FROM PSI-MI");	
	my $psi_mi = $obo_parser->work($psi_mi_obo_filename_path);
	my $psi_mi_int_type = obo2cco ($psi_mi, $cco_y_ids_path, 'Y', 'MI:0190');	
	print_log ( "OK" );	
	
	print_log ( "MERGING ONTOLOGIES: MF, CC, PSI-MI_INT, pre_ulo_and_relationships" );
	my $clean_pre_cco_obo = $ome->union( $go_mf,  $go_cc, $psi_mi_int_type, $ulo_go_bp);
	print_log ( "OK" );
	
	print_log ( "LINKING THE ROOTS OF CC, MF, MI BRANCHES TO ULO" );
	link_terms ($clean_pre_cco_obo, "GO", "0005575", "CCO:U0000001"); # linking 'cellular component' to 'biological continuant'
	link_terms ($clean_pre_cco_obo, "GO", "0003674", "CCO:U0000001");# linking 'molecular function'to 'biological continuant'
	link_terms ($clean_pre_cco_obo, "MI", "0190", "CCO:U0000002"); # linking 'interaction type' to 'biological process'
	print_obo ($clean_pre_cco_obo, $clean_pre_cco_obo_path);
	print_log ( "OK" );	
}


if ($xrf) {
#	print_log ("GETTING XRF FILES FROM GO");
#	# both functions can be called only from a subdir of cco/  - TODO
#	get_GO_xrf_abbs_from_cvs();
#	print_log ("OK");
	print_log ("LOADING XRF DATA");
	system "perl -w get_xrf.pl $go_xrf_abbs_path $clean_pre_cco_obo_path";
	print_log ("OK");
}


if ($ncbi_taxonomy) {
	

	################################################################################
	#
	# Integrate	the taxonomy from NCBI:
	#
	# ID: 3702 <=> Arabidopsis thaliana
	# ID: 9606 <=> Homo sapiens
	# ID: 4896 <=> Schizosaccharomyces pombe
	# ID: 4932 <=> Saccharomyces cerevisiae  (<=> 284812: strain)
	#
	# INPUT  : $clean_pre_cco_obo_path
	# OUTPUT : $pre_cco_core_obo_path
	#
	################################################################################
	

		
	print_log ( "PARSING THE NCBI TAXONOMY" );
	my $ncbi_parser = OBO::CCO::NCBIParser->new();
	my @taxon_ids = keys %taxon_labels;
	my $onto        = $ncbi_parser->work(
		$clean_pre_cco_obo_path, $pre_cco_core_obo_path, $cco_t_ids_path, $ncbi_nodes_file_path, $ncbi_names_file_path, @taxon_ids
	);	
	print_log ( "OK" );
}

if ($typedefs) {
	print_log ("ADDING TYPEDEFS FROM biorel.obo");
	add_typedefs ($pre_cco_core_obo_path, $biorel_path);
	print_log ( "OK");
}

} # the seed ontology created

################################################################################
#
#		The species specific part starts here
#
################################################################################

if ($global_taxon_id) {
	

if ($up_filtering_by_taxon) {
	my $tax_lab = $global_label;
	croak "taxon label was not supplied\n" if !$tax_lab;
	my $tax_id = $global_taxon_id;
	carp "taxon label was not supplied\n" if !$tax_id;
	print_log ("FILTERING UNIPROT FILES FOR $tax_lab");
	system "perl $pipeline_dir/filter_up_by_taxon.pl $tax_lab $uniprot_dir/$tax_lab.sprot.dat $uniprot_dir/$tax_lab.sprot.map < $sprot_dat_path";
	system "perl $pipeline_dir/filter_up_by_taxon.pl $tax_lab $uniprot_dir/$tax_lab.trembl.dat $uniprot_dir/$tax_lab.trembl.map < $trembl_dat_path";
	system "cat $uniprot_dir/$tax_lab.sprot.dat $uniprot_dir/$tax_lab.trembl.dat > $uniprot_dir/$tax_lab.dat";
	system "cat $uniprot_dir/$tax_lab.sprot.map $uniprot_dir/$tax_lab.trembl.map | sort > $uniprot_dir/$tax_lab.map";
	system "perl get_fasta.pl $tax_lab < $uniprot_dir/$tax_lab.dat > $fasta_dir/$tax_lab.fasta";
	print_log ("OK");	
}

if ($goa_filtering_by_aspect) {
	print_log ("FILTERING GOA FOR $global_label");
	my $file_name =  `grep -P "\t$global_taxon_id\t" $goa_file_names_path | cut -f 3`;
	my $file_path = "$data_goa_dir/$file_name";
	my $out_file_path = "$goa_dir/$global_label.p.goa";	
#	`perl filter_goa_by_aspect.pl P 0 0 < "$file_path" > "$out_file_path"`;  # does not find one of the files
		my $cmd =
	"perl filter_goa_by_aspect.pl P 0 0 $out_file_path < $file_path ";
		system $cmd;
		$out_file_path = "$goa_dir/$global_label.cf.goa";
		$cmd =
	"perl filter_goa_by_aspect.pl 0 C F $out_file_path < $file_path ";
		system $cmd;
		print_log ("OK");
}

if ($core_proteins_from_goa) {
	print_log ("EXTRACTING CORE CELL CYCLE PROTEINS FROM GOA BP FOR $global_label");
	my $input_onto = $pre_cco_core_obo_path;
	my $output_onto = "$obo_dir/$global_label.1.obo";
	my $assoc_file = "$goa_dir/$global_label.p.goa";
	my $short_map = "$doc_dir/cco_b_" . $global_label . ".ids";
	my $map = $cco_b_ids_path;
	my $up_map = "$uniprot_dir/$global_label.map";
	my @files    = (
		$input_onto, $output_onto, $assoc_file, $short_map, $map, $up_map
	);
	my $goa_parser   = OBO::CCO::GoaParser->new();
	my $new_ontology = $goa_parser->work( \@files );	
	print_log ( "OK" );
}

if ($test_code) {
	
}

} # the end of the taxon specific section

if ($global_label eq 'ortho') {
	system "cat $fasta_dir/*.fasta > $fasta_dir/cco.fa";
	my  @ontos;
	foreach my $taxon_label (values %taxon_labels) {
		my  $onto = $obo_parser->work("$obo_dir/$taxon_label.1.obo");
		push @ontos, $onto;
	}
	my $cco_1 = $ome->union(@ontos);
	
}


###############################################################
#
#	OLD STUFF
#
###############################################################
if ($UniProt_preprocessing) {	
#	print_log ( "Generating the merged uniprot files" );
#	system
#	"gunzip -c $filenames_uniprot_path[0] $filenames_uniprot_path[1] > $uniprot_dat_path[0]";
#	system
#	"gunzip -c $filenames_uniprot_path[2] $filenames_uniprot_path[3] > $uniprot_dat_path[1]";
#	system
#	"gunzip -c $filenames_uniprot_path[4] $filenames_uniprot_path[5] > $uniprot_dat_path[2]";
#	
#	print_log ( "OK" );
		
	################################################################################
	#
	# A.2 Filter UniProt and update names
	#
	################################################################################
	foreach my $taxon_id ( keys %organism_by_taxon_id ) {
		my $organism = $organism_short_by_taxon_id{$taxon_id};
		my $taxon    = $organism_by_taxon_id{$taxon_id};
	
	#
	# A.2.1 Generate the files: uniprot_(S_pombe|S_cerevisiae|A_thaliana|H_sapiens).cco
	#
		filter_uniprot_files(
			$uniprot_dat_file_name_by_taxon_id{$taxon_id},
			$uniprot_cco_file_name_by_taxon_id{$taxon_id},
			$organism_short_by_taxon_id{$taxon_id}
		);
	
		#
		# A.2.2 Generate a map: ACC's versus names (for the core cell cycle)
		#
		
		print_log ( "\tGenerate a map: ACC's versus names for $organism" );
		my $cco_core_uniprot_input_file =
		  $uniprot_cco_file_name_by_taxon_id{$taxon_id};
		my $cco_map_uniprot_input_file =
		  $uniprot_map_cco_file_name_by_taxon_id{$taxon_id};
		system
	"perl write_up_map.pl < $cco_core_uniprot_input_file > $cco_map_uniprot_input_file";
		
		print_log ( "OK" );
	
	#
	# A.2.3 Filtering UniProt (NB. The files generated here are also used afterwards by OMCL)
	#
		
		print_log ( "\tFiltering UniProt for $organism" );
		my $cmd =
	"perl filter_uniprot.pl \'$taxon_name_by_taxon_id{$taxon_id}\' < $uniprot_dat_file_name_by_taxon_id{$taxon_id} > $uniprot_out_file_name_by_taxon_id{$taxon_id}";
		system $cmd;
		
		print_log ( "OK" );
	
	#
	# A.2.4 Generate a map: ACC's versus names (for the whole uniprot) (NB. The files generated here are ONLY used by IntActParser)
	#
		
		print_log ( "\tGenerate a map: ACC's versus names for $organism for the whole uniprot" );
		my $uniprot_input_file =
		  $uniprot_out_file_name_by_taxon_id{$taxon_id
		  };    # entire proteome	per organism
		my $map_uniprot_input_file =
		  $uniprot_map_file_name_by_taxon_id{$taxon_id
		  };    # map uniprot with entire proteome
		system
		  "perl write_up_map.pl < $uniprot_input_file > $map_uniprot_input_file";
		
		print_log ( "OK" );
	}
}
	
	
if ($core_cell_cycle_proteins) {
	
	#
	#
	# Per organism
	#
	
	print_log ( "Starting to load data" );
	foreach my $taxon_id ( keys %organism_by_taxon_id ) {
		my $organism = $organism_short_by_taxon_id{$taxon_id};
	
		# 2.1 load the data from the assoc files and fill the cco_b.ids
		get_gene_assoc_data(
			$uniprot_map_cco_file_name_by_taxon_id{$taxon_id},
			$goa_file_name_by_taxon_id{$taxon_id}, $organism )
		  ;    # OBO::CCO::GoaParser used here!
	
		# 2.2 load the xrf data into CCO:
		load_xrf_data_as_OBO($organism);    # fill: cco_r.ids by calling to "get_xrf.pl"
	}
}

################################################################################
#
# BIG tasks:
#			0. Integrate data from IntAct
#           1. Integrate protein data from UniProt
#           2. Load the gene assoc files
#
################################################################################

if ($IntAct_data_integration) {
	
	########################################################################
	#
	# 0. Integrate data form IntAct (NewIntActParser)
	#
	################################################################################
	
	print_log ( "Parsing the PSI25 files" );
	parse_psi25();
	
	print_log ( "Finished the parsing of PSI25 files" );
}

if ($UniProt_data_integration) {
	
	################################################################################
	#
	# 1. Integrate protein data from UniProt
	#
	#     Per organism
	#
	################################################################################
	
	print_log ( "Starting to load UniProt data" );
	
	foreach my $taxon_id ( keys %organism_by_taxon_id ) {
		my $organism = $organism_short_by_taxon_id{$taxon_id};
		my $taxon    = $organism_by_taxon_id{$taxon_id};
	
	#
	# Produce the needed uniprot files by ontology ($obo_dir/cco_I_$organism.obo)
	# Reuse the file $uniprot_out_file_name_by_taxon_id which was got by filter_uniprot.pl
	#
		
		print_log ( "Produce the needed uniprot file by ontology (cco_I_$organism.obo)" );
		my $cmd =
	"perl filter_uniprot_by_ontology.pl $obo_dir/cco_I_$organism.obo < $uniprot_out_file_name_by_taxon_id{$taxon_id} > $uniprot_CCO_file_name_by_taxon_id{$taxon_id}";
		system $cmd;
		
		print_log ( "OK" );
	
	#
	# Parse the filtered data and add the proteins to CCO as well as their genes
	# $uniprot_CCO_file_name_by_taxon_id is obtained with cco_I_$organism.obo
	#
		load_uniprot_data( $taxon, $organism,
			$uniprot_CCO_file_name_by_taxon_id{$taxon_id} )
		  ;    # UniProtParser is used here!
	}
	
	print_log ( "Finishing the loading UniProt data procedure" );
}
 
 if ($cc_mf_integration) {
 	
	################################################################################
	#
	# 2. Load the gene assoc files:
	#
	#    Integration of the data from GOA (cellular components and molecular functions)
	#
	################################################################################
	
	print_log ( "Integration of the data from GOA" );
	foreach my $taxon_id ( keys %organism_by_taxon_id ) {
		my $organism = $organism_short_by_taxon_id{$taxon_id};
		my $taxon    = $organism_by_taxon_id{$taxon_id};
		
	### Attn: ../goa were replaced with $goa_dir, see if it may create problems
		my $cmd =
	"perl filter_goa_by_aspect.pl 0 C F < $goa_dir/$goa_file_name_by_taxon_id{$taxon_id} > $goa_dir/$goa_cf_file_name_by_taxon_id{$taxon_id}";
		system $cmd;
	
		my $goa_parser = OBO::CCO::GoaParser->new();
		my @files      = (
			"$obo_dir/cco_UP_$organism.obo",
			"$obo_dir/cco_$organism.obo",
			"$goa_dir/$goa_cf_file_name_by_taxon_id{$taxon_id}"
		);
		my $ontology = $goa_parser->add_go_assocs( \@files );
	
		
		print_log ( "Integrated GOA associations for $organism" );	
	}
	
	print_log ( "Finishing the integration of the data from GOA" );
}

if ($cleanup) {
# Sort and gather the uniprot IDs handled in integrate_cc_from_goa()
system "cat $doc_dir/uniprot_cco_*.ids | sort > $doc_dir/uniprot_cco.ids";
################################################################################
#
# Clean tmp files
#
################################################################################
print_log ( "Cleaning temporal files: " );

#system "rm $clean_pre_cco_obo_path $pre_ulo_and_relationships_obo_path";
print_log ( "OK" );
################################################################################
#
# Update the complete list of IDs
#
################################################################################
print_log ( "Updating the complete list of IDs" );
}

if ($merge_species) {
	
	# Merge all the IDs by organims that were generated in assoc_filter by the GoaParser
	system
	"sort $doc_dir/cco_b_H_sapiens.ids $doc_dir/cco_b_A_thaliana.ids $doc_dir/cco_b_S_cerevisiae.ids $doc_dir/cco_b_S_pombe.ids > $doc_dir/cco_b.ids";
	system "sort $doc_dir/cco_?.ids > $doc_dir/cco.ids";
	print_log ( "OK" );
	################################################################################
	#
	# Merging the 4 organism ontologies: At, Hu, Sc, Sp -----> cco.obo
	#
	################################################################################
	
	print_log ( "Merging ontologies" );
	system "perl -w $onto_perl_dir/scripts/merge.pl $cco_obo_H_sapiens_path $cco_obo_A_thaliana_path $cco_obo_S_cerevisiae_path $cco_obo_S_pombe_path > $pre_cco_obo_path";
	
	print_log ( "OK" );
}

if ($orthologs) {
	
	################################################################################
	#
	# OMCL pipeline
	#
	#      OUTPUT   : $cco_obo_path (cco.obo)
	#
	################################################################################
	
	print_log ( "OMCL pipeline" );
	system "perl -w pipeline_omcl.pl";
	system
	"sort $doc_dir/cco_b_H_sapiens.ids $doc_dir/cco_b_A_thaliana.ids $doc_dir/cco_b_S_cerevisiae.ids $doc_dir/cco_b_S_pombe.ids > $doc_dir/cco_b.ids";
	system "sort $doc_dir/cco_?.ids > $doc_dir/cco.ids";
	
	print_log ( "OK" );
}

if ($exports) {
	
	################################################################################
	#
	# Exports to: OWL, DOT, GML, XML, VIS (XML)
	#
	################################################################################
	my @files = (
		$cco_obo_H_sapiens_path,    $cco_obo_A_thaliana_path,
		$cco_obo_S_cerevisiae_path, $cco_obo_S_pombe_path,
		$cco_obo_path,              $gene_ontology_obo_path
	);
	
	foreach my $file (@files) {
		export2dot_gml_owl_xml($file);
	}
}

################################################################################
print_log ( "The pipeline ended at: " );
close PIPELINE_LOG;
exit 0;

################################################################################
#
# Get GO.xrf_abbs from GO via CVS.
# Store them in the 'xrf' directory.
#
################################################################################
sub get_GO_xrf_abbs_from_cvs {
	print_log ( "Getting 'GO.xrf_abbs':" );
	chdir("..") or carp "Cannot change directory: $!";

	# clean old entries:
	my $rm_cmd = 'rm -rf xrf/GO.xrf_abbs; rm -rf xrf/GO.curator_dbxrefs';
	my $output = `$rm_cmd 2>&1`;
	my $cmd1 = 'cvs -d :pserver:anonymous:@cvs.geneontology.org:/anoncvs login';
	my $cmd2 =
'cvs -d :pserver:anonymous:@cvs.geneontology.org:/anoncvs co -d xrf go/doc/GO.xrf_abbs';
	my $cmd3 =
'cvs -d :pserver:anonymous:@cvs.geneontology.org:/anoncvs co -d xrf go/doc/GO.curator_dbxrefs';
	$output .= `$cmd1 2>&1`;
	$output .= `$cmd2 2>&1`;
	$output .= `$cmd3 2>&1`;
	print_log ( $output );
	system('rm -r xrf/CVS/>>pipeline.log');
	chdir("pipeline") or carp "Cannot change directory back to pipeline: $!";
	print_log ( "Checkout: OK" );
}

sub _get_GO_xrf_abbs_from_cvs {
#	print_log ( "Getting 'GO.xrf_abbs':" );
#	chdir("..") or carp "Cannot change directory: $!";

	# clean old entries:
	my $rm_cmd = 'rm -rf $xrf_dir/GO.xrf_abbs; rm -rf $xrf_dir/GO.curator_dbxrefs';
	my $output = `$rm_cmd 2>&1`;
	my $cmd1 = 'cvs -d :pserver:anonymous:@cvs.geneontology.org:/anoncvs login';
	my $cmd2 =
'cvs -d :pserver:anonymous:@cvs.geneontology.org:/anoncvs co -d $xrf_dir go/doc/GO.xrf_abbs';
	my $cmd3 =
'cvs -d :pserver:anonymous:@cvs.geneontology.org:/anoncvs co -d $xrf_dir go/doc/GO.curator_dbxrefs';
	$output .= `$cmd1 2>&1`;
	$output .= `$cmd2 2>&1`;
	$output .= `$cmd3 2>&1`;
	print_log ( $output );
	system('rm -r $xrf_dir/CVS/>>pipeline.log');
#	chdir("pipeline") or carp "Cannot change directory back to pipeline: $!";
#	print_log ( "Checkout: OK" );
}

################################################################################
#
# Parse the PSI25 data files from IntAct
# INPUT  : $pre_cco_obo_$organism_path  = "$obo_dir/pre_cco_$organism.obo"
# OUTPUT : cco_I_obo_$organism_path
#
################################################################################
sub parse_psi25 {

	#
	# A_thaliana
	#
	
	print_log ( "\tInteractions in A thaliana" );
	my @files = (
		$pre_cco_obo_A_thaliana_path,
		$cco_I_obo_A_thaliana_path,
		"$doc_dir/cco_b_A_thaliana.ids",
		"$doc_dir/cco_b.ids",
		"$doc_dir/cco_i_A_thaliana.ids",
		"$doc_dir/cco_i.ids",
		$uniprot_map_cco_file_name_by_taxon_id{'3702'},
		$uniprot_map_file_name_by_taxon_id{'3702'},
		"$intact_dir/arath_small-01.xml",
		"$intact_dir/arath_small-02.xml",
		"$intact_dir/arath_small-03.xml",
		"$intact_dir/arath_small-04.xml",
		"$intact_dir/arath_small-05.xml"
	);

	my $intact_parser = OBO::CCO::NewIntActParser->new();
	my $ontology  = $intact_parser->work( \@files );
	
	print_log ( "OK" );

	#
	# S_pombe
	#
	
	print_log ( "\tInteractions in S pombe" );
	@files = (
		$pre_cco_obo_S_pombe_path,
		$cco_I_obo_S_pombe_path,
		"$doc_dir/cco_b_S_pombe.ids",
		"$doc_dir/cco_b.ids",
		"$doc_dir/cco_i_S_pombe.ids",
		"$doc_dir/cco_i.ids",
		$uniprot_map_cco_file_name_by_taxon_id{'4896'},
		$uniprot_map_file_name_by_taxon_id{'4896'},
		"$intact_dir/schpo_small-01.xml",
		"$intact_dir/schpo_small-02.xml"
	);

	$intact_parser = OBO::CCO::NewIntActParser->new();
	$ontology  = $intact_parser->work( \@files );
	
	print_log ( "OK" );

	#
	# S_cerevisiae
	#
	
	print_log ( "\tInteractions in S_cerevisiae" );
	@files = (
		$pre_cco_obo_S_cerevisiae_path,
		$cco_I_obo_S_cerevisiae_path,
		"$doc_dir/cco_b_S_cerevisiae.ids",
		"$doc_dir/cco_b.ids",
		"$doc_dir/cco_i_S_cerevisiae.ids",
		"$doc_dir/cco_i.ids",
		$uniprot_map_cco_file_name_by_taxon_id{'4932'},
		$uniprot_map_file_name_by_taxon_id{'4932'},
		"$intact_dir/yeast_hazbun-2003-1_01.xml",
		"$intact_dir/yeast_hazbun-2003-1_02.xml",
		"$intact_dir/yeast_ito-2001-1_01.xml",
		"$intact_dir/yeast_ito-2001-1_02.xml",
		"$intact_dir/yeast_ito-2001-1_03.xml",
		"$intact_dir/yeast_small-01.xml",
		"$intact_dir/yeast_small-02.xml",
		"$intact_dir/yeast_small-03.xml",
		"$intact_dir/yeast_small-04.xml",
		"$intact_dir/yeast_small-05.xml",
		"$intact_dir/yeast_small-06.xml",
		"$intact_dir/yeast_small-07.xml",
		"$intact_dir/yeast_small-08.xml",
		"$intact_dir/yeast_small-09.xml",
		"$intact_dir/yeast_small-1-00.xml",
		"$intact_dir/yeast_small-1-01.xml",
		"$intact_dir/yeast_small-1-02.xml",
		"$intact_dir/yeast_small-1-03.xml"
	);

#	$intact_parser = OBO::CCO::NewIntActParser->new(); ### why??? it already exists
	$ontology  = $intact_parser->work( \@files );
	
	print_log ( "OK" );

	#
	# H_sapiens
	#
	
	print_log ( "\tInteractions in H_sapiens" );
	@files = (
		$pre_cco_obo_H_sapiens_path,
		$cco_I_obo_H_sapiens_path,
		"$doc_dir/cco_b_H_sapiens.ids",
		"$doc_dir/cco_b.ids",
		"$doc_dir/cco_i_H_sapiens.ids",
		"$doc_dir/cco_i.ids",
		$uniprot_map_cco_file_name_by_taxon_id{'9606'},
		$uniprot_map_file_name_by_taxon_id{'9606'},
		"$intact_dir/human_rual-2005-2_01.xml",
		"$intact_dir/human_rual-2005-2_02.xml",
		"$intact_dir/human_small-01.xml",
		"$intact_dir/human_small-02.xml",
		"$intact_dir/human_small-03.xml",
		"$intact_dir/human_small-04.xml",
		"$intact_dir/human_small-05.xml",
		"$intact_dir/human_small-06.xml",
		"$intact_dir/human_small-07.xml",
		"$intact_dir/human_small-08.xml",
		"$intact_dir/human_small-09.xml",
		"$intact_dir/human_small-1-00.xml",
		"$intact_dir/human_small-1-01.xml",
		"$intact_dir/human_small-1-02.xml",
		"$intact_dir/human_small-1-03.xml",
		"$intact_dir/human_small-1-04.xml",
		"$intact_dir/human_small-1-05.xml",
		"$intact_dir/human_small-1-06.xml",
		"$intact_dir/human_small-1-07.xml",
		"$intact_dir/human_small-1-08.xml",
		"$intact_dir/human_stelzl-2005-1_01.xml",
		"$intact_dir/human_stelzl-2005-1_02.xml"
	);

#	$intact_parser = OBO::CCO::NewIntActParser->new(); ### why???
	$ontology  = $intact_parser->work( \@files );
	
	print_log ( "OK" );
}
################################################################################
#
# Get the PSI25 files from EBI (IntAct) via FTP
#
################################################################################
sub get_psi25_intact_from_ftp {
	print_log ( "Get the PS25 files from EBI (IntAct): " );
	chdir("$intact_dir/") or carp "Cannot change directory: $!";

	#my $rm_cmd = 'rm -rf $psi_mi_obo_filename';
	#my $output = `$rm_cmd 2>&1`;

	# ftp://ftp.ebi.ac.uk/pub/databases/intact/current/psi25/species/arath*
	my $hostname = 'ftp.ebi.ac.uk';
	my $username = 'anonymous';
	my $password = 'myname@mydomain.com';

	# Hardcode the directory and filename to get
	my $path_to_ontology = '/pub/databases/intact/current/psi25/species/';

	# Open the connection to the host
	require Net::FTP;
	my $ftp = Net::FTP->new($hostname);
	$ftp->login( $username, $password );

	$ftp->cwd($path_to_ontology);

	my @files = (
		"arath_small-01.xml",            "arath_small-02.xml",
		"arath_small-03.xml",            "arath_small-04.xml",
		"arath_small-05.xml",            "arath_small-05_negative.xml",
		"humad_small.xml",               "human_rual-2005-2_01.xml",
		"human_rual-2005-2_02.xml",      "human_small-01.xml",
		"human_small-02.xml",            "human_small-02_negative.xml",
		"human_small-03.xml",            "human_small-03_negative.xml",
		"human_small-04.xml",            "human_small-05.xml",
		"human_small-05_negative.xml",   "human_small-06.xml",
		"human_small-06_negative.xml",   "human_small-07.xml",
		"human_small-08.xml",            "human_small-08_negative.xml",
		"human_small-09.xml",            "human_small-09_negative.xml",
		"human_small-1-00.xml",          "human_small-1-00_negative.xml",
		"human_small-1-01.xml",          "human_small-1-01_negative.xml",
		"human_small-1-02.xml",          "human_small-1-03.xml",
		"human_small-1-04.xml",          "human_small-1-04_negative.xml",
		"human_small-1-05.xml",          "human_small-1-06.xml",
		"human_small-1-06_negative.xml", "human_small-1-07.xml",
		"human_small-1-08.xml",          "human_stelzl-2005-1_01.xml",
		"human_stelzl-2005-1_02.xml",    "schpo_small-01.xml",
		"schpo_small-01_negative.xml",   "schpo_small-02.xml",
		"yeast_hazbun-2003-1_01.xml",    "yeast_hazbun-2003-1_02.xml",
		"yeast_ito-2001-1_01.xml",       "yeast_ito-2001-1_02.xml",
		"yeast_ito-2001-1_03.xml",       "yeast_small-01.xml",
		"yeast_small-02.xml",            "yeast_small-03.xml",
		"yeast_small-04.xml",            "yeast_small-05.xml",
		"yeast_small-06.xml",            "yeast_small-07.xml",
		"yeast_small-08.xml",            "yeast_small-09.xml",
		"yeast_small-1-00.xml",          "yeast_small-1-01.xml",
		"yeast_small-1-02.xml",          "yeast_small-1-03.xml"
	);

	# Now get the files and leave
	foreach my $filename (@files) {
		$ftp->get($filename);
	}
	$ftp->quit;

	#print_log ( $output );
	chdir("$pipeline_dir") or carp "Cannot change directory to pipeline: $!";
	print_log ( "OK" );
}
################################################################################
#
# Function  : Export ontology to all the available formats (OWL, XML, GML, ...)
# Arguments : Input file path of the OBO file.
# Returns   : none
#
################################################################################
sub export2dot_gml_owl_xml {
	if (@_) {
		my $cco_obo_path_input = shift;
		my @formats = ( 'dot', 'gml', 'owl', 'xml', 'vis', 'rdf' );

		my $my_obo_parser = OBO::Parser::OBOParser->new();

		if ( ( -e $cco_obo_path_input ) && ( -r $cco_obo_path_input ) ) {
			my $ontology = $my_obo_parser->work($cco_obo_path_input);
			print_log ( "Start exporting the ontology:\n" );
			foreach my $format (@formats) {
				my $export_path = "$cco_dir/" . $format;
				chdir($export_path) or carp "Cannot change directory: $!";
				( my $cco_path_output = $cco_obo_path_input ) =~
				  s/obo/$format/g;
				my $format_uc = uc($format);
				print_log ( "\tExporting the ontology ($cco_obo_path_input) to $format_uc ($cco_path_output)" );
				open( FH, ">$cco_path_output" ) || croak "The ", $format_uc,
				  " file ($cco_path_output) could not be created:  $!";
				$ontology->export( \*FH, $format );
				select( ( select(FH), $| = 1 )[0] );
				close FH;
				chdir("$pipeline_dir")
				  or carp "Cannot change directory to pipeline: $!";
			}

		}
		else {
			croak
			  "File not found (export2dot_gml_owl_xml): '$cco_obo_path_input'." . NL;
		}
		print_log ( "End of exporting process: OK" );
	}
	else {
		print_log ( "Exporting the OBO file to dot_gml_owl_xml: ERROR" );
	}
}
################################################################################
#
# Gene association loading
# Args - H_sapiens.goa       : H. sapiens assoc.
#      - S_cerevisiae.goa    : S. cerevisiae assoc.
#      - S_pombe.goa         : S. pombe assoc.
#      - A_thaliana.goa      : A. thaliana assoc.
# Outfile:
#			$obo_dir/pre_cco_.$organism.obo
#
################################################################################
# Note: used only  in the if ($core_cell_cycle_proteins) section
sub get_gene_assoc_data {
	my ( $cco_map_uniprot_input_file, $file_name, $organism ) = @_;
	if ( $cco_map_uniprot_input_file && $file_name && $organism ) {
		my $clean_cco_obo_path_output = "$obo_dir/pre_cco_" . $organism . ".obo";
		
		print_log ( "\tAdding the terms from the assoc file for $organism" );
		$file_name = "$goa_dir/" . $file_name;

		# open the go ids vs. cco ids table and put it into a map.
		open( GO_CCO_IDS, "$go_cco_ids_table_path" )
		  || croak "The '$go_cco_ids_table_path' file couldn't be opened";
		chomp( my @go_cco_ids = <GO_CCO_IDS> );
		close GO_CCO_IDS;

		my %go_cco_ids = ();

		# key=go_id, value=cco_id
		foreach my $entry (@go_cco_ids) {
			$go_cco_ids{$1} = $2 if ( $entry =~ /^(GO:.*)\s+(CCO:.*)/ );
		}
		########################################################################
		#
		# Filters out the lines having a GO/CCO ID
		#
		########################################################################
		my $assoc_filter_log = "/assoc_filter.log";
		open( FILTER_LOG, ">>$assoc_filter_log" )
		  || croak "The $assoc_filter_log file couldn't be opened";
		print FILTER_LOG "\n\nDate: " . `date`;
		print FILTER_LOG "Filtering the gene association file ("
		  . $file_name . "): ";

		( my $file_name_cco_path = $file_name ) =~ s/\.goa/\.p\.cco/;

		# initialize the generated assoc file
		system "/bin/cat /dev/null > $file_name_cco_path";
		my @go_ids = keys %go_cco_ids;    # IDs from GO used in CCO

		open( FN, $file_name )
		  || croak "The file name: $file_name cannot be opened:  $!";
		my @list = <FN>;
		close FN;

		open( FNCP, ">$file_name_cco_path" )
		  || croak "The file name: $file_name_cco_path cannot be opened: ", $!;
		foreach my $go_id (@go_ids) {
			map { s/$go_id/$go_cco_ids{$go_id}/g; print FNCP $_ }
			  grep /(?<!NOT)\t$go_id\t\w+:.*/, @list;
		}
		close FNCP;

		# sort the cco assoc file and clean the directory
		my $tmp_file = $file_name_cco_path . "tmp";
		my $cmd      = "sort $file_name_cco_path > $tmp_file";
		system "$cmd; mv $tmp_file $file_name_cco_path";

		print FILTER_LOG "OK";
		close FILTER_LOG;
		########################################################################
		#
		# GOA Parsing
		#
		########################################################################
		my $map_file = "$doc_dir/cco_b_" . $organism . ".ids";
		my @files    = (
			$pre_cco_core_obo_path, $clean_cco_obo_path_output,
			$file_name_cco_path,    $map_file,
			"$doc_dir/cco_b.ids",     $cco_map_uniprot_input_file
		);

		my $goa_parser   = OBO::CCO::GoaParser->new();
		my $new_ontology = $goa_parser->work( \@files );

		
		print_log ( "OK" );
		return $new_ontology;
	}
	else {
		
		print_log ( "\tAdding the terms from the assoc file: ERROR" );
	}
}
################################################################################
#
# Load the data from the downloaded xrf's files.
# Arguments:
#          1. organism
# TODO tratar solo los xrf considerados en CCO.
#
################################################################################
sub load_xrf_data_as_OBO {
	
	print_log ( "\tLoading the data from the downloaded xrf's files" );
	my ($organism) = @_;
	if ($organism) {
		my $clean_cco_obo_path_input = "$obo_dir/pre_cco_" . $organism . ".obo";
		if (   ( -e $clean_cco_obo_path_input )
			&& ( -r $clean_cco_obo_path_input ) )
		{
			system "perl -w get_xrf.pl $go_xrf_abbs_path $clean_cco_obo_path_input";
		}
		else {
			croak "File not found: '$clean_cco_obo_path_input'.";
		}
		
		print_log ( "OK" );
	}
	else {
		
		print_log ( "ERROR" );
	}
}
################################################################################
#
# Filter the data from UniProt
# Usage: filter_uniprot_files(dat_file, cco_file, organism)
# TODO Is this method better implemented by using SWISS?
#
# INPUT   : $obo_dir/pre_cco_$organism.obo
# OUTPUT  : filterred files from uniprot
#
################################################################################
sub _filter_uniprot_files {
	
	my ( $uniprot_dat, $uniprot_cco, $organism ) = @_;
	print_log ( "\tFiltering the data from UniProt for $organism" );
	select( ( select(PIPELINE_LOG), $| = 1 )[0] );
	if ( $uniprot_dat && $uniprot_cco && $organism ) {
		my $a_parser = OBO::Parser::OBOParser->new();
		my $ontology = $a_parser->work("$obo_dir/pre_cco_$organism.obo");

		#
		# Get all the biopolymers by xref (UniProt AC number):
		#
		my %terms_map_by_name;
		foreach my $term ( @{ $ontology->get_terms("CCO:B.*") } )
		{    # visit the proteins
			my $cco_protein_uniprot_ac = &get_xref_acc( "UniProtKB", $term );
			$terms_map_by_name{$cco_protein_uniprot_ac} =
			  $cco_protein_uniprot_ac
			  if ($cco_protein_uniprot_ac);
		}

		#
		# filter up
		#
		local $/ = "\n//\n";

		system "cat /dev/null > $uniprot_cco";    # clean old file

		open FH, ">$uniprot_cco"
		  || croak "Can't open file ($uniprot_cco) for writing!", $!;
		select( ( select(FH), $| = 1 )[0] );
		open( UH, "$uniprot_dat" )
		  || croak "The file $uniprot_dat could not be opened: ", $!;
		while (<UH>) {
			my $entry = $_;
			$_ =~ /AC   (.*)/ ? my $acs = $1 : next;
			chop($acs);    # erase the last ';'
			foreach my $ac ( split( /;(\s+)?/, $acs ) ) {
				if ( defined $terms_map_by_name{$ac} ) {

#if ($ontology->has_term_id($ontology->get_term_by_name($name))){ # TODO use a map! Temporal solution: %terms_map_by_name					print "el ac es: ", $ac, "\n";
					print FH $entry
					  ;    # print out the result in $uniprot_cco
					last;  # only one entry!
				}
			}
		}
		close UH;
		close FH;
		$/ = "\n";
		
		print_log ( "OK" );
	}
	else {
		
		print_log ( "ERROR" );
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
	my ( $db, $term ) = @_;
	my $result_acc = undef;
	my $dbxrefset  = $term->xref_set();
	foreach my $xref ( $dbxrefset->get_set() ) {
		if ( $xref->db() eq $db ) {
			$result_acc = $xref->acc();
			last;
		}
	}
	return $result_acc;
}
################################################################################
#
# Load the data from UniProt by using the UniProtParser
#
# INPUT   : "$obo_dir/cco_I_$organism.obo"
# OUTPUT  : "$obo_dir/cco_UP_$organism.obo"
#
################################################################################
sub load_uniprot_data {
	
	my ( $taxon, $organism, $uniprot_cco ) = @_;
	print_log ( "\tLoading the data from UniProt for $organism" );
	select( ( select(PIPELINE_LOG), $| = 1 )[0] );
	if ( $taxon && $organism && $uniprot_cco ) {
		my @files = (
			"$obo_dir/cco_I_$organism.obo", "$obo_dir/cco_UP_$organism.obo",
			$uniprot_cco,    "$doc_dir/cco_b_$organism.ids",
			"$doc_dir/cco_b.ids",           "$doc_dir/cco_g_$organism.ids",
			"$doc_dir/cco_g.ids",
		);

		my $my_uniprot_parser = OBO::CCO::UniProtParser->new();
		my $ontology = $my_uniprot_parser->work( \@files, $taxon );
		
		print_log ( "OK" );
	}
	else {
		
		print_log ( "ERROR" );
	}
	select( ( select(PIPELINE_LOG), $| = 1 )[0] );
}

sub adopt_orphans {
	my ($onto, $adopter) = @_;	
#	my @terms = @{ $onto->get_terms("CCO:P.*") }; # get the processes
	my @terms = @{ $onto->get_terms("GO:.*") }; # get the GO terms
	foreach my $term (@terms) {
		my @rels = @{
			$onto->get_relationships_by_source_term(
				$term)
		  };
		my $link_found = 0;
		foreach my $r (@rels) {
			if ( $r->type() eq 'is_a' ) {
				$link_found = 1;
				last;
			}
		}
		if ( !$link_found ) {    # if there is no 'is_a'
			$onto->create_rel( $term, 'is_a', $adopter );
		}
	}
}

sub obo2cco {
	my  $onto = shift @_;
	my $cco_id_map = OBO::CCO::CCO_ID_Term_Map->new(shift @_);  # IDs file
	my $sns = shift @_ || 'Z';                                  # subnamespace
	my $sub_ontology_root_id = shift @_;                        # root term e.g. MI:0190
	
	if ($sub_ontology_root_id) {
		my $term = $onto->get_term_by_id($sub_ontology_root_id);
		$onto = $onto->get_subontology_from($term);
	}
	
	my $ns = $onto->idspace_as_string("CCO", "http://www.cellcycleontology.org/ontology/obo/CCO");
	$onto->default_namespace("cellcycle_ontology");
	$onto_perl_latest ? $onto->remarks("A Cell-Cycle Sub-Ontology") : $onto->remark("A Cell-Cycle Sub-Ontology");
	foreach my $entry (sort {$a->id() cmp $b->id()} @{$onto->get_terms()}){
		my $current_id = $entry->id();
		next if $current_id =~ /\ACCO:/xms;
		my $entry_name = $entry->name();
		my $cco_id;
		if ($onto_perl_latest) {
			$cco_id = $cco_id_map->get_id_by_term($entry_name);
		} else {
			$cco_id = $cco_id_map->get_cco_id_by_term($entry_name); 
		}
#		$onto_perl_latest ? $cco_id = $cco_id_map->get_id_by_term($entry_name) : $cco_id = $cco_id_map->get_cco_id_by_term($entry_name); # by term name
		# Has an ID been already associated to this term (repeated entry)?
		$cco_id = $cco_id_map->get_new_cco_id($ns->local_idspace(), $sns, $entry_name) if (!defined $cco_id);
		$onto->set_term_id($entry, $cco_id);
		# xref's
		my $xref = OBO::Core::Dbxref->new();
		$xref->name($current_id);
		my $xref_set = $onto->get_term_by_id($entry->id())->xref_set();
		$xref_set->add($xref);
		# add the alt_id's as xref's
		foreach my $alt_id ($entry->alt_id()->get_set()){
			my $xref_alt_id = OBO::Core::Dbxref->new();
			$xref_alt_id->name($alt_id);
			$xref_set->add($xref_alt_id);
		}
		$entry->alt_id()->clear() if (defined $entry->alt_id()); # erase the alt_id(s) from this 'entry'
	}
	$cco_id_map->write_map(); 
	return $onto;
}

sub print_obo {
	my ($onto, $path) = @_;
	open( FH, ">$path" ) || croak "Error  exporting: $path", $!;
	$onto->export( \*FH );
	select( ( select(FH), $| = 1 )[0] );
	close FH;
}

sub add_typedefs  {
	
#	print_log ( "Cleaning biorel.obo" );
	my $onto_path = shift;
	my @rel_ontos = @_;
	system "cat @rel_ontos |
			grep -hv '^format-version:' |
			grep -hv '^data-version:' |
			grep -hv '^date:' |
			grep -hv '^saved-by:' |
			grep -hv '^auto-generated-by:' |
			grep -hv '^import:' |
			grep -hv '^subsetdef:' |
			grep -hv '^synonymtypedef:' |
			grep -hv '^idspace:' |
			grep -hv '^default-namespace:' |
			grep -hv 'remark:' |
			grep -hv 'inverse_of:' |
			perl -p -i -e 's/id: ((OBO|CCO)_REL:(.*))/id: \$3\nxref: \$1/; s/is_a: ((OBO|CCO)_REL:(.*))/is_a: \$3/;' >> $onto_path";
	
#	print_log ( "OK" );
}

sub link_terms {
	my ($onto, $xref_db, $xref_acc, $term_id) = @_;
	my $subject = $onto->get_term_by_xref ($xref_db, $xref_acc) || croak "The object term is not defined $!\n";
	my $object = $onto->get_term_by_id($term_id) || croak "The subject term is not defined $!\n";
	$onto->create_rel($subject, "is_a", $object);
}

sub create_term {
	my ($id, $name, $def, $def_id) = @_;	
	my $term = OBO::Core::Term->new();
	$term->id($id);
	$term->name($name);
	$term->def_as_string($def, $def_id);
	return $term;
}

sub print_log {
	my $message = shift;
	my $path;
	if ($global_label) {
		$path = "$log_dir/$global_label.log";
	} else {
		$path = $log_path;
	}
	chomp( my $date = `date` );
	open my $FH, '>>', $path  || croak "The log file couldn't be opened";
	print $FH "$message ($date)\n ";	
	select( ( select($FH), $| = 1 )[0] );
	close $FH;
}

