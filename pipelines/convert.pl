#! /usr/bin/perl
BEGIN {
	my @homes = (
	'/home/mironov/git/usr/bgw', 
	'/nird/home/mironov/git/usr/bgw',
	);
	push @INC, @homes;
}
use strict;
use warnings;
use Carp;

my $verbose = 1;
if ( $verbose ) {
	$Carp::Verbose = 1;
	use Data::Dumper;
};

use IO::Handle;
*STDOUT->autoflush(); # screws up logs ?
########################################################################
# Not used
#~ use Config;
#~ use threads;
#~ use threads::shared;
#~ $Config{useithreads} or croak ('Recompile Perl with threads to run this program.');
########################################################################

use parsers::Entrez;
use parsers::Goa;
use parsers::Intact;
use parsers::Uniprot;
use parsers::Obof;
use OBO::Parser::OBOParser; # needed

use auxmod::SharedSubs qw( 
extract_map
read_map
benchmark
__date
);

use auxmod::SharedVars qw(
$download_dir
$projects_dir
$gpi_txn_lst
%uris
);


my ( $label, $fmt  ) = @ARGV;
my (
$start_time,
$elapsed_time,
$step_time,
$msg,
$cmd,
);

my $data_dir = "$projects_dir/data";
# my $up_dat_dir = "$data_dir/uniprot";
# my $goa_dat_dir = "$data_dir/goa";
# my $entrez_dat_dir = "$data_dir/entrez";
# my $intact_dat_dir = "$data_dir/intact";
my $bgw_dir = "$projects_dir/biogateway";

## doesn't make sense, should be created in advance, script convert.sh should be run from the log dir:
# unless ( -e $bgw_dir ) { mkdir $bgw_dir or croak "failed to create dir '$bgw_dir': $!"; }
# my $log_dir = "$bgw_dir/log";
# unless ( -e $log_dir ) { mkdir $log_dir or croak "failed to create dir '$log_dir': $!"; }

my @taxa = keys %{extract_map ($gpi_txn_lst, 0) };
my $maps_dir = "$bgw_dir/gnid2upac/";
unless ( -e $maps_dir ) { mkdir $maps_dir or croak "failed to create dir '$maps_dir': $!"; }

####################### UniProt ########################################
## must be run before Entrez

if ( $label eq 'uniprot' ) {
	my $uniprot = parsers::Uniprot->new ( );
	my $obof = parsers::Obof->new ( );
	print "STARTED $0 @ARGV ", __date, "\n"; $start_time = time;
	my $input_dir = "$download_dir/$label";
	my $out_dir = "$bgw_dir/$label";
	unless ( -e $out_dir ) { mkdir $out_dir or croak "failed to create dir '$out_dir': $!"; }
	my $mod_file_path = "$download_dir/obo/mod.obo";
	print "parsing '$mod_file_path'\n";
	my $syns = $obof -> map2id ( $mod_file_path, 'synonym' );
	my $count = 0; print "count: $count\n";
	foreach my $txn ( @taxa ) {
		my $in_file_path = "$input_dir/$txn.txt";
		next unless -e $in_file_path;
		next if -z $in_file_path;
		my $out_file_path = "$out_dir/$txn.rdf";
		my $gnid2upac_path = "$maps_dir/$txn.tsv"; # for writng map
		my $data = $uniprot-> parse ( $in_file_path, $gnid2upac_path, $syns ); # no need for filtering
		next unless $data;
		$uniprot-> uniprot2rdf ( $data, $out_file_path, );
		$count++;
	}
	print "count: $count\n";
	$msg = "DONE $0 @ARGV"; benchmark ( $start_time, $msg, 1 );
}

######################## Entrez ########################################
if ( $label eq 'entrez' ) {
	my $entrez = parsers::Entrez->new ( );
	print "STARTED $0 @ARGV ", __date, "\n"; $start_time = time;
	my $input_dir = "$data_dir/$label";
	my $out_dir = "$bgw_dir/$label";
	unless ( -e $out_dir ) { mkdir $out_dir or croak "failed to create dir '$out_dir': $!"; }
	my $count = 0; print "count: $count\n";
	foreach my $txn ( @taxa ) {
		my ( $in_file_path, $data );
		## step 1
		$in_file_path = "$input_dir/gene_info/$txn.ref";
		## filtering only once
		next unless -e $in_file_path;
		next if -z $in_file_path;
		$data = $entrez-> parse_genes ( $in_file_path, );
		next unless $data;
		## step 2
		$in_file_path = "$input_dir/gene2accession/$txn.ref";
		my $map_file = "$maps_dir/$txn.tsv";
		my $gnid2upac = read_map ( $map_file, 2 ); # { geneid => [upacs] } }
		$data = $entrez->parse_accs ( $in_file_path, $data, $gnid2upac );
		## step 3
		$in_file_path = "$input_dir/gene2ensembl/$txn.ref";
		$data = $entrez->parse_ensembl ( $in_file_path, $data ); # no map needed
		## step 4
		my $out_file_path = "$out_dir/$txn.rdf";		
		#~ $entrez->entrez2rdf ( $data, $out_file_path, $base, $namespace );
		$entrez->entrez2rdf ( $data, $out_file_path, );
		$count++;
	}
	print "count: $count\n";
	$msg = "DONE $0 @ARGV"; benchmark ( $start_time, $msg, 1 );
}

########################## Intact#######################################

if ( $label eq 'intact' ) {
	my $intact = parsers::Intact->new ( );	
	print "STARTED $0 @ARGV ", __date, "\n"; $start_time = time;
	my $input_dir = "$data_dir/$label";
	my $out_dir = "$bgw_dir/$label";
	unless ( -e $out_dir ) { mkdir $out_dir or croak "failed to create dir '$out_dir': $!"; }
	my $count = 0; print "count: $count\n";
	foreach my $txn ( @taxa ) {
		my $in_file_path = "$input_dir/$txn.2rp";
		my $out_file_path = "$out_dir/$txn.$fmt";
		next unless -e $in_file_path;
		next if -z $in_file_path;
		my $data = $intact-> parse_tab ( $in_file_path ); # no map - the input pre-filtered by refprot ACs
		next unless $data;
		if ( $fmt eq 'ttl' ) {
			$intact-> intact2ttl ( $data, $out_file_path, );
		} elsif ( $fmt eq 'rdf' ) {
			$intact-> intact2rdf ( $data, $out_file_path, );
		} else {
			croak "Unknown file format: '$fmt'\n";
		}
		$count++;
	}
	print "count: $count\n";
	$msg = "DONE $0 @ARGV"; benchmark ( $start_time, $msg, 1 );
}

######################### GOA ##########################################
if ( $label eq 'goa' ){
	my $goa = parsers::Goa->new ( );
	print "STARTED $0 @ARGV ", __date, "\n"; $start_time = time;
	my $input_dir = "$data_dir/$label";
	my $out_dir = "$bgw_dir/$label";
	unless ( -e $out_dir ) { mkdir $out_dir or croak "failed to create dir '$out_dir': $!"; }
	my $count = 0; print "count: $count\n";
	foreach my $txn ( @taxa ) {
		my $in_file_path = "$input_dir/$txn.gpa";
		my $out_file_path = "$out_dir/$txn.rdf";
		next unless -e $in_file_path;
		next if -z $in_file_path; #print "in_file: $in_file_path\n";
		my $data = $goa-> parse_gpa ( $in_file_path, ); # no map - the input pre-filtered by refprot ACs (including isoforms)
		next unless $data;
		$goa-> gpa2rdf ( $data, $out_file_path, );
		$count++;
	}
	print "count: $count\n";
	$msg = "DONE $0 @ARGV"; benchmark ( $start_time, $msg, 1 );
}

######################### OBO ##########################################

## Note: currently only go-basic
if ( $label eq 'obo' ) {
	my $parser = OBO::Parser::OBOParser->new ( );
	print "STARTED $0 @ARGV ", __date, "\n"; $start_time = time;	
	my $obof = parsers::Obof->new ( );
	my $out_dir = "$bgw_dir/$label";
	my ( $input_dir, $in_file_path, $out_file_path, $onto );
	$input_dir = "$download_dir/go";
	unless ( -e $out_dir ) { mkdir $out_dir or croak "failed to create dir '$out_dir': $!"; }
	$in_file_path = "$input_dir/go-basic.obo";
	$out_file_path = "$out_dir/go-basic.rdf";
	print "parsing $in_file_path\n";
	$step_time = time;
	$onto = $parser->work ( $in_file_path );
	$msg = "> parsed $in_file_path"; benchmark ( $step_time, $msg, 0 );
	print "exporting to $out_file_path\n";
	$step_time = time;
	$obof-> obo2xml ( $onto, $out_file_path, 'rdfs' );
	$msg = "> exported into $out_file_path"; benchmark ( $step_time, $msg, 0 );
	$input_dir = "$download_dir/obo";
	$in_file_path = "$input_dir/ncbitaxon.obo";
	$out_file_path = "$out_dir/ncbitaxon.rdf";
	print "parsing $in_file_path\n";
	$step_time = time;
	$onto = $parser->work ( $in_file_path );
	$msg = "> parsed $in_file_path"; benchmark ( $step_time, $msg, 0 );
	print "exporting to $out_file_path\n";
	$step_time = time;
	$obof-> obo2xml ( $onto, $out_file_path, 'rdfs' );
	$msg = "> exported into $out_file_path"; benchmark ( $step_time, $msg, 0 );
	$msg = "DONE $0 @ARGV"; benchmark ( $start_time, $msg, 1 );
}

########################################################################
#~ if ( $label eq 'pazar' ) {
	 #~ # TODO remove hardcoding
	# print "Project: $project_name\n";
	#~ print 'CONVERTING PAZAR TO RDF ', __date; $start_time = time;
	#~ my $ncbi = 1;
	#~ my $in_dir = "$data_dir/$label";
	#~ my $out_dir = "$bgw_dir/$label";
	#~ my @fields = ( # to extract from UniProt idmapping.dot
	#~ 'UniProtKB-ID', 
	#~ 'NCBI_TaxID', 
	#~ 'GeneID', 
	#~ 'Ensembl_TRS', 
	#~ 'EnsemblGenome_TRS',
	#~ 'Ensembl', 
	#~ 'EnsemblGenome',
	#~ );
	#~ my $pazar = parsers::Pazar->new();
	# $step_time = time; # TODO test; move to download.pl ?
	# my $cmd = "mv $in_dir/idmapping.dat $in_dir/idmapping.dat~";
	#~ #system ( $cmd ) if -e "$in_dir/idmapping.dat";
	# map { my $cmd = "grep $_ $data_dir/uniprot/idmapping.dat >> $in_dir/idmapping.dat"; system ( $cmd ) } @fields;
	# $msg = "Extracted ID mappings from  data_up_dir/idmapping.dat to data_pazar_dir/edimapping.dat";
	# benchmark ( $step_time, $msg );
	#~ 
	#~ my %lookups;
#~ 
	#~ $step_time = time;
	#~ my $pathidmap = "$in_dir/idmapping.dat"; # testing
	#~ my $idmapping = $uniprot->parseIdMap ( $pathidmap, 2 );
	#~ my $trs = $idmapping->{$fields[3]};
	#~ my $genometrs = $idmapping->{$fields[4]};
	#~ my %transcripts;
	# $genometrs ? # for idmapping.hmr
	#~ %transcripts = ( %{$trs}, %{$genometrs} );
	# %transcripts = %{$trs};
	#~ 
	#~ $msg = "> Parsed $pathidmap";
	#~ benchmark ( $step_time, $msg, );
#~ 
	#~ $step_time = time;
	#~ my $ncbi_dir = "$data_dir/ncbi";
	#~ my $source_path = "$ncbi_dir/gene2ensembl";
	#~ my $entrez = parsers::Entrez->new ( );
	#~ my $gene2ensembl = $entrez->parse_gene2ensembl ( $source_path );
	#~ my $genes = $gene2ensembl->{'EnsemblGeneId'};
	#~ $msg = "> Parsed $source_path";
	#~ benchmark ( $step_time, $msg );
	#~ 
	#~ $lookups{'Transcripts'} = \%transcripts;
	#~ $lookups{'Genes'} = $genes;
	#~ 
	#~ $step_time = time;
	#~ my $pazar_file_path = "$in_dir/pazar.all";
	#~ my $pzr = $pazar->parse_pzr ( $pazar_file_path, \%lookups );
	#~ $msg = "> Parsed $pazar_file_path";
	#~ benchmark ( $step_time, $msg );
	#~ 
	#~ $step_time = time;	
	#~ my $pazar_rdf_path = "$out_dir/pazar.rdf";	
	#~ my $out = $pazar->pzr2rdf ( $pzr, \%lookups, $pazar_rdf_path, $base, $namespace, $ncbi );	
	#~ $msg = "> Generated $pazar_rdf_path";
	#~ benchmark ( $step_time, $msg );
	#~ 
	#~ $msg = "DONE $0 @ARGV";	benchmark ( $start_time, $msg, 1 );
#~ }	

