# TODO:
# include OMIM
# distinctons between 'interaction' and 'interaction type'
# take ALL GeneIDs from UniProt (a couple of genes without GeneID in GeXO)
# remove subsedef: and synonymtypedef: from the header ?
# MIREOTed import
# expand MI - add MI methods to APOs ??
# ULO; import terms instead of providing as variables
# proper error handling
# formatting
## TODO
## naming in the data Directories
## creating necessaey dirs
## clean up global vars
## consistent naming of data files

################################################################################

BEGIN {
	push @INC, '/datamap/home_mironov/git/scripts', '/norstore_osl/home/mironov/git/scripts';
}

use Carp;
use strict;
use warnings;
# use Date::Manip qw(ParseDate UnixDate);

my $verbose = 1;
if ( $verbose ) {
	$Carp::Verbose = 1;
	use Data::Dumper;
};
use IO::Handle;
*STDOUT-> autoflush();

use OBO::Parser::OBOParser;
use parsers::Entrez;
use parsers::Goa;
use parsers::Intact;
use parsers::Uniprot;
use parsers::Obof;
use parsers::Ortho;
# use parsers::Kegg.pm;

use auxmod::SharedSubs qw( 
open_read
open_write
print_obo 
read_map
extract_map
filter_tsv_by_map
print_counts 
benchmark
__date
);

use auxmod::SharedVars qw(
$download_dir
$projects_dir
$ortho_dir
%uris
);

#-------------------------- project variables ----------------------------------
# change appropriately
# must be the same as in seed.pl
use auxmod::CcoVars; 
# use auxmod::GexkbVars; 

####################### configuration vars #####################################
my $load_goap = 0;
my $load_intact = 0;
my $load_ortho = 0;
my $load_goafc = 0;
my $load_uniprot = 0;
my $load_entrez = 0;
my $exports = 1;
my $export_tmp = 0;
my $test = 0;
########################## global vars #########################################
my $prj = lc $PRJ; # acronym
my $prjnm = lc $PRJNM; # full name
my ( $onto, $start_time, $step_time, $msg, $cmd);

### Directories
my $prj_dir = "$projects_dir/$prj";
# my $ortho_dir = $projects_dir . '/ortho';
my $log_dir = $prj_dir.'/log';
my $dat_dir = "$prj_dir/data";

### paths
my $seed_path = "$prj_dir/tmp/seed.obo";
# my $obo0_path = "$prj_dir/tmp/$prj-0.obo";
my $obo1_path = "$prj_dir/tmp/$prj-1.obo";
my $obo2_path = "$prj_dir/tmp/$prj-2.obo";
my $obo3_path = "$prj_dir/tmp/$prj-3.obo";
my $obo4_path = "$prj_dir/tmp/$prj-4.obo";
my $obo5_path = "$prj_dir/tmp/$prj-5.obo"; # uniprot
my $obo6_path = "$prj_dir/final/$prj.obo"; # entrez
my $map0_path = "$prj_dir/maps/refprot.acc"; # for the project's proteomes
my $map1_path = "$prj_dir/maps/gpa-p.acc"; # core proteins
my $map2_path = "$prj_dir/maps/intact.acc";
my $map3_path = "$prj_dir/maps/ortho.acc";
my $map5_path = "$prj_dir/maps/gnid2upac.tsv"; # 1:n
my $map6_path = "$prj_dir/maps/gnid2gnnm.tsv"; # not used

###################### ! Change before running ! ###############################
## in OBOParser.pm
## - line 235: my $r_db_acc  = qr/\s+(\w+:\S+)/o; # vlmir 
# after each download:
# obsolete: replace globally '\' with e.g. '--' in gene_info; in VIM: :%s/\\/--/g

############################### START! #########################################

print "\n\nSTARTED ALL: $0 ", __date, "\n"; my $begin_time = time;
my $obo_parser = OBO::Parser::OBOParser-> new();
my $entrez = parsers::Entrez-> new();
my $goa = parsers::Goa-> new();
my $intact = parsers::Intact-> new();
my $uniprot = parsers::Uniprot-> new();
my $obof = parsers::Obof-> new();
my $ortho = parsers::Ortho-> new();

############################## goap ############################################
## takes no time
if ( $load_goap ) {
	print "STARTED goap\n"; $start_time = time;
	$step_time = time; # filtering data 
	my $gpa_path = "$prj_dir/data/$prj.gpa"; print "gpa_path: $gpa_path\n"; # for writing
	my $data_path = $gpa_path;
	my @src_files = map { "$projects_dir/data/goa/$_.gpa" } keys %taxon_labels; # filtered by refprots ?
	$cmd = "cat @src_files > $gpa_path"; system ( $cmd );
	my @map_files = map { "$projects_dir/data/uniprot/$_.acc" } keys %taxon_labels; 
	$cmd = "cat @map_files > $map0_path"; system ( $cmd );
	
	$step_time = time;
	my $in_obo_path = $seed_path;
	my $out_obo_path = $obo1_path;
	$onto = $obo_parser-> work ( $in_obo_path ) unless $onto;
	$onto-> name ($prj) unless $onto-> name();
	$msg = "> parsed $in_obo_path"; benchmark ( $step_time, $msg, 0 );
	$step_time = time;
	print "> using map: $map0_path\n";
	my $data = $goa-> parse_gpa ( # all aspects
	$data_path, 
	extract_map ($map0_path, 0),  # just to exclude spurious protein entries in GPA files
	); 
	$msg = "> parsed $data_path"; benchmark ( $step_time, $msg, 0 );
# 	print_counts ( $data );
	$step_time = time;
	my $result = $goa-> gpa2onto ( 
	$onto, 
	$data, 
	'ptn2bp',
	);
	$msg = "> loaded data from $data_path into $out_obo_path"; benchmark ( $step_time, $msg, 0 );
	$step_time = time;
	print_obo ( $onto, $out_obo_path );
	$msg = "> saved $out_obo_path"; benchmark ( $step_time, $msg, 0 );
	$step_time = time;
	my $map_path = $map1_path;
	my $FH = open_write ( $map_path );
	map { print $FH "$_\t".$result->{$_}."\n"; } sort keys %{$result}; # didn't work without concatenation
	close $FH;
	$msg = "> saved $map_path"; benchmark ( $step_time, $msg, 0 );
	$msg = "DONE "; benchmark ( $start_time, $msg, );
}

############################ intact ############################################
# TODO confirm the interactions are reciprocal !
if ( $load_intact ) {
	print "STARTED intact\n"; $start_time = time;
	my $map_path = $map0_path;
	my $in_obo_path = $obo1_path;
	my $out_obo_path = $obo2_path;
	$step_time = time;
	$onto = $obo_parser-> work ( $in_obo_path ) unless $onto;
	$onto-> name ($prj) unless $onto-> name(); # print "name: $onto-> name()";
	$msg = "> parsed $obo1_path"; benchmark ( $step_time, $msg, 0 );
	$step_time = time;
	my $data_path = "$prj_dir/data/refprot.ia"; print "data_path: $data_path\n";
	# using *.1rp files - filtered by the accs of the InteractorA, InteractorB anything or nothing
	my @src_files = map { "$projects_dir/data/intact/$_.1rp" } keys %taxon_labels;
	$cmd = "cat @src_files > $data_path"; system ( $cmd );
	$msg = "> concatenated source files in $data_path"; benchmark ( $step_time, $msg, 0 );
	$step_time = time;
	print "> using map: $map0_path\n"; # all accs for the project
	## data were prefiltered by the InteractorA
	my $data = $intact-> parse_tab (	$data_path, extract_map($map0_path, 0) );
	## now both interactor A and B are limited to the project taxa
	## the complete Intact data file could be used as well
	$msg = "> parsed $data_path"; benchmark ( $step_time, $msg, 0 );
	print_counts ( $data );
	$step_time = time;
	print "> using map: $map1_path\n"; # accs from gpa files (core proteins)
	my $result = $intact-> intact2onto (	$onto, $data, extract_map($map1_path, 0) );
	$msg = "> loaded data from $data_path into $out_obo_path"; benchmark ( $step_time, $msg, 0 );
	$step_time = time;
	print_obo ( $onto, $out_obo_path );
	$msg = "> saved $out_obo_path"; benchmark ( $step_time, $msg, 0 );
	$step_time = time;
	$map_path = $map2_path;
	my $FH = open_write ( $map_path );
	map { print $FH "$_\t$result-> {$_}\n" } sort keys %{$result};
	close $FH;
	$msg = "> saved $map_path"; benchmark ( $step_time, $msg, 0 );
	
	$msg = "DONE "; benchmark ( $start_time, $msg, );
}

############################# ortho ############################################
# TODO enable a map in parse_abc ?
if ( $load_ortho ) {
	print "STARTED ortho\n"; $start_time = time;
	$step_time = time;
	my $in_obo_path = $obo2_path;
	my $out_obo_path = $obo3_path;
	$onto = $obo_parser-> work ( $in_obo_path ) unless $onto;
	$onto-> name ($prj) unless $onto-> name();
	$msg = "> parsed $obo2_path"; benchmark ( $step_time, $msg, 0 );
	my $key;
	my $map0 = extract_map ( $map0_path, 0 );
	my $map1 = extract_map ( $map1_path, 0 );
#----------------------------- orthologs ---------------------------------------
	$step_time = time;
	my $data_path = $ortho_dir.'/all_orthologs.abc';
	my $data = $ortho-> parse_abc ( $data_path, $map0 ); # filtering by both accs, excluding isoforms
	$msg = "> parsed $data_path"; benchmark ( $step_time, $msg, 0 );
	print_counts ( $data, 2 );
	$step_time = time;
	print "> using map: $map1_path\n";
	$key = 'orl2orl';
	my $orlresult = $ortho-> ortho2onto ( $onto, $data, $key, $map1 );
	$msg = "> loaded data from $data_path into $out_obo_path"; benchmark ( $step_time, $msg, 0 );
#------------------------------ paralogs ---------------------------------------	
	$step_time = time;
	$data_path = $ortho_dir.'/inparalogs.abc';
	$data = $ortho-> parse_abc ( $data_path, $map0 ); # filtering by both accs, excluding isoforms
	$msg = "> parsed $data_path"; benchmark ( $step_time, $msg, 0 );
	print_counts ( $data, 2 );
	$step_time = time;
	print "> using map: $map1_path\n";
	$key = 'prl2prl';
	my $prlresult = $ortho-> ortho2onto ( $onto, $data, $key, $map1 );
	$msg = "> loaded data from $data_path into $out_obo_path"; benchmark ( $step_time, $msg, 0 );
	# combining
	my %result = ( %{$orlresult}, %{$prlresult} ); # this throughs errors if either of the hashes is empty
	$step_time = time;
	print_obo ( $onto, $out_obo_path );
	$msg = "> saved $out_obo_path"; benchmark ( $step_time, $msg, 0 );
	$step_time = time;
	my $map_path = $map3_path;
	open my $FH, '>', $map_path;
	map { print $FH "$_\t$result{$_}\n" } sort keys %result;
	$msg = "> saved $map_path"; benchmark ( $step_time, $msg, 0 );
	$msg = "DONE "; benchmark ( $start_time, $msg, );
}
############################## goafc ###########################################
if ( $load_goafc ) { 
	print "STARTED goafc\n"; $start_time = time;
	$step_time = time;
	my $in_obo_path = $obo3_path;
	my $out_obo_path = $obo4_path;
	$onto = $obo_parser-> work ( $in_obo_path ) unless $onto;
	$onto-> name ($prj) unless $onto-> name();
	$msg = "> parsed $obo3_path"; benchmark ( $step_time, $msg, 0 );
	
	$step_time = time;
	print "> using map: $map0_path\n";
	my $map = extract_map ($map0_path, 0); # $map is used just to limit the size of $data
	my $gpa_path = "$prj_dir/data/$prj.gpa"; print "> gpa_path: $gpa_path\n";
	my $data_path = $gpa_path;
	my $data = $goa-> parse_gpa ( $data_path, $map );
	$msg = "> parsed $data_path"; benchmark ( $step_time, $msg, 0 );
	my $key;
#----------------------------- F -----------------------------------------------
	$step_time = time;
	$key = 'ptn2mf';
	my $resultF = $goa-> gpa2onto ( 
	$onto, 
	$data, 
	$key,
	);
	$msg = "> loaded data from $data_path into $out_obo_path"; benchmark ( $step_time, $msg, 0 );

#----------------------------- C -----------------------------------------------
	$step_time = time;
	$key = 'ptn2cc';
	my $resultC = $goa-> gpa2onto ( 
	$onto, 
	$data, 
	$key,
	);
	$msg = "> loaded data from $data_path into $out_obo_path"; benchmark ( $step_time, $msg, 0 );
	
	$step_time = time;
	print_obo ( $onto, $out_obo_path );
	$msg = "> saved $out_obo_path"; benchmark ( $step_time, $msg, 0 );
	$msg = "DONE "; benchmark ( $start_time, $msg, );
}

############################## uniprot #########################################

if ( $load_uniprot ) {
	print "STARTED uniprot\n"; $start_time = time;
	my $data_path = "$prj_dir/data/$prj.up"; print "> data_path: $data_path\n";
	my @src_files = map { "$download_dir/uniprot/$_.txt" } keys %taxon_labels;
	$cmd = "cat @src_files > $data_path"; print "> cmd: $cmd\n"; system ( $cmd );
	
	$step_time = time;
	my $in_obo_path = $obo4_path;
	my $out_obo_path = $obo5_path;
	$onto = $obo_parser-> work ( $in_obo_path ) unless $onto;
	$onto-> name ($prj) unless $onto-> name();
	$msg = "> parsed $obo4_path"; benchmark ( $step_time, $msg, 0 );
	
	$step_time = time;
	my $mod_file_path = "$download_dir/obo/mod.obo";
	my $syns = $obof -> map2id ( $mod_file_path, 'synonym' );
	$msg = "> processed synonyms from '$mod_file_path'"; benchmark ( $step_time, $msg, 0 );
# 	print Dumper($syns);
	$step_time = time;
	my $data = $uniprot-> parse ( $data_path, $map5_path, $syns ); # no need for filtering
	$msg = "> parsed $data_path"; benchmark ( $step_time, $msg, 0 );
	print_counts ( $data );
	
	$step_time = time;
	my $out = $uniprot-> uniprot2onto ( $onto, $data, );
	$msg = "> loaded data from $data_path into $out_obo_path"; benchmark ( $step_time, $msg, 0 );
	
	my $FH = open_write ( $map5_path );
	foreach my $gnid ( sort keys %{$out} ) {
		map { print $FH "$gnid\t$_\n" } sort keys %{$out-> {$gnid}};
	}
	close $FH;
	
	$step_time = time;
	print_obo ( $onto, $out_obo_path );
	$msg = "> saved $out_obo_path"; benchmark ( $step_time, $msg, 0 );
	$msg = "DONE "; benchmark ( $start_time, $msg, );
}

############################### entrez #########################################

if ( $load_entrez ) {
	print "STARTED entrez\n"; $start_time = time;
	my $data_path = "$prj_dir/data/$prj.gi"; print "> data_path: $data_path\n"; # for writing
	my @src_files = map { "$projects_dir/data/entrez/gene_info/$_.ref" } keys %taxon_labels;
	$cmd = "cat @src_files > $data_path"; print "cmd: $cmd\n"; system ( $cmd );
	
	my $gnid2upac = read_map ( $map5_path, 2 ); # { geneid => [upacs] } } (the mode should be '2' indeed)
	$step_time = time;
	print "> using map $map5_path\n";
	my $data = $entrez-> parse_genes ( $data_path, $gnid2upac ); # $gnid2upac is used only for filtering
	$msg = "> parsed $data_path"; benchmark ( $step_time, $msg, 0 );
	print_counts ( $data );
	
	$step_time = time;
	my $in_obo_path = $obo5_path;
	my $out_obo_path = $obo6_path;
	$onto = $obo_parser-> work ( $in_obo_path ) unless $onto;
	$onto-> name ($prj) unless $onto-> name();
	$msg = "> parsed $obo5_path"; benchmark ( $step_time, $msg, 0 );

	$step_time = time;
	my $result = $entrez-> entrez2onto ( $onto, $data, $gnid2upac ); # $gnid2upac is used for adding relations
	$msg = "> loaded data from $data_path into $out_obo_path"; benchmark ( $step_time, $msg, 0 );
	
	my $FH = open_write ( $map6_path );
	map { my $gn = $result-> {$_}; print $FH $gn-> id( )."\t".$gn-> name()."\n"; } sort keys %{$result};
	
	$step_time = time;
	print_obo ( $onto, $out_obo_path );
	$msg = "> saved $out_obo_path"; benchmark ( $step_time, $msg, 0 );
	$msg = "DONE "; benchmark ( $start_time, $msg, );
}

################################# exports ######################################

if ( $exports ) {
	print "STARTED exports\n"; $start_time = time;
	my ( $out_path, $FH, $id_map );
	
	$step_time = time;
	my $in_obo_path = $obo6_path;
	$onto = $obo_parser-> work ( $in_obo_path ) unless $onto;
	$onto-> name ($prj) unless $onto-> name();
	$msg = "> parsed $in_obo_path"; benchmark ( $step_time, $msg, 0 );
	
	$step_time = time;
	$out_path = "$prj_dir/final/$prj.rdf";
	$FH = open_write ( $out_path );
	$id_map = $obof-> obo2xml( $onto, $out_path, 'rdfs' );
	close $FH;
	$msg = "> saved $out_path"; benchmark ( $step_time, $msg, 0 );
	
	$step_time = time;
	$out_path = "$prj_dir/final/$prj.owl";
	$FH = open_write ( $out_path );
	$id_map = $obof-> obo2xml( $onto, $out_path, 'owl' );
	close $FH;
	$msg = "> saved $out_path"; benchmark ( $step_time, $msg, 0 );
	
	$msg = "DONE "; benchmark ( $start_time, $msg, );
}

if ( $export_tmp ) {
# TODO neds fixing, the output files are crap
	print "STARTED exports of tmp files\n"; $start_time = time;
	my $out_dir = "$prj_dir/tmp";
	my @names = map {substr $_, 0, -5; } `ls $out_dir/$prj*.obo`; # removing '.obo', with full paths
	foreach my $name ( @names ) {
		my ( $out_path, $FH, $id_map );
		my $in_obo_path = "$name.obo";
		$onto = $obo_parser-> work ( $in_obo_path ); # sic!
		$onto-> name ($prj);
		$step_time = time;
		$out_path = "$name.rdf";
		print "> exporting $out_path\n";
		$FH = open_write ( $out_path );
		$id_map = $obof-> obo2xml( $onto, $out_path, 'rdfs' );
		$msg = "> saved $out_path"; benchmark ( $step_time, $msg, 0 );
		close $FH;
		$step_time = time;
		$out_path = "$name.owl";
		print "> exporting $out_path\n";
		$FH = open_write ( $out_path );
		$id_map = $obof-> obo2xml( $onto, $out_path, 'owl' );
		$msg = "> saved $out_path"; benchmark ( $step_time, $msg, 0 );
		close $FH;
	}
	$msg = "DONE "; benchmark ( $start_time, $msg, );
}
$msg = "DONE ALL $0 "; benchmark ( $begin_time, $msg, 1 );

if ( $test ) {
	print "STARTED exports\n"; $start_time = time;
	my ( $out_path, $FH, $id_map );
	
	$step_time = time;
	my $base_name = "gaz";
	
	my $in_obo_path = "$download_dir/obo/$base_name.obo";;
	$onto = $obo_parser-> work ( $in_obo_path ) unless $onto;
	$onto-> name ($prj) unless $onto-> name();
	$msg = "> parsed $in_obo_path"; benchmark ( $step_time, $msg, 0 );
	
	$step_time = time;
	$out_path = "$prj_dir/$base_name.rdf";
	$FH = open_write ( $out_path );
	$id_map = $obof-> obo2xml( $onto, $out_path, 'rdfs' );
	close $FH;
	$msg = "> saved $out_path"; benchmark ( $step_time, $msg, 0 );
	
	$step_time = time;
	$out_path = "$prj_dir/$base_name.owl";
	$FH = open_write ( $out_path );
	$id_map = $obof-> obo2xml( $onto, $out_path, 'owl' );
	close $FH;
	$msg = "> saved $out_path"; benchmark ( $step_time, $msg, 0 );
	
	$msg = "DONE "; benchmark ( $start_time, $msg, );
}
