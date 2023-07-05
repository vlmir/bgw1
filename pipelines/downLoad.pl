
BEGIN {
	push @INC, '/datamap/home_mironov/git/scripts', '/norstore_osl/home/mironov/git/scripts';
}

use Carp;
use strict;
use warnings;

my $verbose = 1;
if ( $verbose ) {
	$Carp::Verbose = 1;
	use Data::Dumper;
};
use auxmod::SharedVars qw ( 
$download_dir
$projects_dir
$gpi_src_file
$gpi_txn_lst
$pazar_src_file
);
use auxmod::SharedSubs qw( 
read_map 
print_counts 
benchmark
__date
extract_map
extract_hash
filter_tsv_by_map
);
## using $dat_dir in case want to have processed files outside of $download_dir
my $dat_dir = $download_dir; # TODO should be changed to $projects_dir/data
my $idmapping_dir = "$dat_dir/idmapping";
my $up_dat_dir = "$dat_dir/uniprot";
my $goa_dat_dir = "$dat_dir/goa";
my $entrez_dat_dir = "$dat_dir/entrez";
my $intact_dat_dir = "$dat_dir/intact";
my $pazar_dat_dir = "$dat_dir/pazar";
my $orthodb_dat_dir = "$dat_dir/orthodb";


# my $gpi_txn_lst = "$goa_dat_dir/gpi-txn.lst"; # imported
############################### not used ###############################
#use threads;
#~ use threads::shared;
#~ $Config{useithreads} or croak ('Recompile Perl with threads to run this program.');
#~ use Exporter;
#~ use DownloadVars;
########################################################################
# TODO
# proper handling of archives ?

my ( $label, ) = @ARGV;
################################################################################
## Note: trailing slashes for dirs in URIs are essential !!!
################################################################################
my $obof_uri = 'http://www.berkeleybop.org/ontologies/';
my $rejected = 'dc_cl*,obo_rel*,pgdso*,plant_ontology*,nif_dysfunction*';
my $go_uri = $obof_uri.'go/';
my $sio_uri = 'wget http://semanticscience.org/ontology/sio.owl';
my $taxon_uri = $obof_uri.'ncbitaxon/';
## alternative UP urls:
## http://ftp.ebi.ac.uk/pub/databases/uniprot
## http://ftp.expasy.org/databases/uniprot
my @entrez_uris = (
# 'ftp://ftp.ncbi.nlm.nih.gov/gene/DATA/gene_info.gz',
# 'ftp://ftp.ncbi.nlm.nih.gov/gene/DATA/gene2accession.gz',
# 'ftp://ftp.ncbi.nlm.nih.gov/gene/DATA/gene2ensembl.gz',
# # 'ftp://ftp.ncbi.nlm.nih.gov/gene/DATA/gene_refseq_uniprotkb_collab.gz',
# # 'ftp://ftp.ncbi.nlm.nih.gov/gene/DATA/gene2go.gz',
# 'ftp://ftp.ncbi.nlm.nih.gov/gene/DATA/README',
# 'ftp://ftp.ncbi.nlm.nih.gov/gene/DATA/README_ensembl',
'ftp://ftp.ncbi.nlm.nih.gov/refseq/release/release-catalog/release74.accession2geneid.gz',
);
my @idmapping_uris = (
'ftp://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase/idmapping/idmapping.dat.gz',
'ftp://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase/idmapping/idmapping_selected.tab.gz',
'ftp://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase/idmapping/README',
);

my @goa_uris = (
# 'ftp://ftp.ebi.ac.uk/pub/databases/GO/goa/UNIPROT/gene_association.goa_uniprot.gz',
'ftp://ftp.ebi.ac.uk/pub/databases/GO/goa/UNIPROT/gp_association.goa_ref_uniprot.gz',
'ftp://ftp.ebi.ac.uk/pub/databases/GO/goa/UNIPROT/gp_information.goa_ref_uniprot.gz',
'ftp://ftp.ebi.ac.uk/pub/databases/GO/goa/UNIPROT/README',
);
my @intact_uris = (
'ftp://ftp.ebi.ac.uk/pub/databases/intact/current/psimitab/intact.txt',
'ftp://ftp.ebi.ac.uk/pub/databases/intact/current/psimitab/README',
);
my @omim_uris = (
'ftp://anonymous:vladimir.n.mironov%40gmail.com@ftp.omim.org/OMIM/'
);
my @pazar_uris = (
'http://www.pazar.info/tftargets/tftargets.zip'
);
# TODO other sources of TG-TG data
# my @orthodb_uris = (
# 'ftp://cegg.unige.ch/OrthoDB8/Eukaryotes/Genes_to_OGs/ODB8_EukOGs_genes_ALL_levels.txt.gz',
# 'ftp://cegg.unige.ch/OrthoDB8/Eukaryotes/Annot_to_OGs/ODB8_EukOGs_annotations_ALL_levels.txt.gz',
# 'ftp://cegg.unige.ch/OrthoDB8/Prokaryotes/Genes_to_OGs/ODB8_ProkOGs_genes_ALL_levels.txt.gz',
# 'ftp://cegg.unige.ch/OrthoDB8/Prokaryotes/Annot_to_OGs/ODB8_ProkOGs_annotations_ALL_levels.txt.gz',
# ); 
# my @reactome_uris; # TODO
#
########################### Starting download #########################
my ( $start_time, $elapsed_time, $cmd, $msg );
my $log_dir = "$download_dir/log";
unless ( -e $log_dir ) { mkdir $log_dir or croak "failed to create dir '$log_dir': $!"; }
########################################################################
if ( $label eq 'goa' ) {
	print "STARTED $0 @ARGV ", __date, "\n"; $start_time = time;
	my $label_dir = "$download_dir/$label";
	unless ( -e $label_dir ) { mkdir $label_dir or croak "failed to create dir '$label_dir': $!"; }
	chdir $label_dir or croak "failed to change to dir '$label_dir' $!";
	$cmd = "wget -o $download_dir/log/$label.out @goa_uris";
	print "> $cmd\n"; system $cmd;	
	$cmd = 'gunzip *.gz';
	print "> $cmd\n"; system $cmd;
	## lists from the gpi_src_file; to be used for downloading UP
	# TODO the lists below should be replaced with a map {UPAC => taxon_id} to be used for GPA filtering in refprot.pl ! 
	my $gpi_upac_lst = "$goa_dat_dir/gpi-upac.lst";  # currently not used
	$cmd = "grep -v '^!' $gpi_src_file | cut -f 1 | sort -u > $gpi_upac_lst";
	print "\t>$cmd\n"; system $cmd;
	$cmd = "grep -v '^!' $gpi_src_file | cut -f 6 | cut -d ':' -f 2 | sort -u > $gpi_txn_lst"; 
	print "\t>$cmd\n"; system $cmd;
	$msg = "DONE $0 @ARGV "; benchmark ( $start_time, $msg, 1 );	
}

########################################################################
# IMPORTAING - must be downloaded after the completion of GOA dowload
## http://www.uniprot.org/uniprot/?query=keyword%3A%22Reference+proteome+[KW-1185]%22&sort=score # all ref proteomes
if ( $label eq 'uniprot' ) {
	print "STARTED $0 @ARGV ", __date, "\n"; $start_time = time;
	# UP is a special case - no meed for filtering, download in $dat_dir
	my $label_dir = "$download_dir/$label";
	unless ( -e $label_dir ) { mkdir $label_dir or croak "failed to create dir '$label_dir': $!"; }
	chdir $label_dir or croak "failed to change to dir '$label_dir' $!";
	my $map = extract_map ($gpi_txn_lst , 0 );
	## downloading
	my $format;
	$format = 'txt';
	get_updata_by_taxa ( $map, $format ); # downloading only refprots
	$format = 'fasta';
	get_updata_by_taxa ( $map, $format ); # downloading only refprots
	$msg = "DONE $0 @ARGV "; benchmark ( $start_time, $msg, 1 );
}
########################################################################
if ( $label eq 'idmapping' ) {
	print "STARTED $0 @ARGV ", __date, "\n"; $start_time = time;
	my $label_dir = "$download_dir/$label";
	unless ( -e $label_dir ) { mkdir $label_dir or croak "failed to create dir '$label_dir': $!"; }
	chdir $label_dir or croak "failed to change to dir '$label_dir' $!";

	my $cmd = "wget -o $download_dir/log/$label.out @idmapping_uris";
	print "> $cmd\n"; system $cmd;	
	$cmd = 'gunzip *.gz';
	print "> $cmd\n"; system $cmd;
	$msg = "DONE $0 @ARGV "; benchmark ( $start_time, $msg, 1 );	
}
########################################################################
if ( $label eq 'entrez' ) {
	print "STARTED $0 @ARGV ", __date, "\n"; $start_time = time;	
	my $label_dir = "$download_dir/$label";
	unless ( -e $label_dir ) { mkdir $label_dir or croak "failed to create dir '$label_dir': $!"; }
	chdir $label_dir or croak "failed to change to dir '$label_dir' $!";
	my $cmd = "wget -o $download_dir/log/$label.out @entrez_uris";
	print "> $cmd\n"; system $cmd;
	$cmd = 'gunzip *.gz';
	print "> $cmd\n"; system $cmd;
	
	my $map = extract_map ($gpi_txn_lst , 0 ); 
	my $release = 'test'; ## Attn. must be adjusted for each download !!!
	my $refseq2geneid = extract_hash ( "$label_dir/$release.accession2geneid", 0, 1 ); # taxid2gnid
	foreach my $taxon ( keys %{$refseq2geneid} ) {
		next unless $map->{$taxon};
		my $geneids = join ( ',', sort keys %{$refseq2geneid->{$taxon}} );
		get_docsums_by_list ( 'gene', $geneids, "$label_dir/$taxon.docsum" );
	}
	$msg = "DONE $0 @ARGV "; benchmark ( $start_time, $msg, 1 );	
}

########################################################################
if ( $label eq 'intact' ) {
	print "STARTED $0 @ARGV ", __date, "\n"; $start_time = time;	
	my $label_dir = "$download_dir/$label";
	unless ( -e $label_dir ) { mkdir $label_dir or croak "failed to create dir '$label_dir': $!"; }
	chdir $label_dir or croak "failed to change to dir '$label_dir' $!";
	$cmd = "wget -o $download_dir/log/$label.out @intact_uris";
	print "> $cmd\n"; system $cmd;	
	$msg = "DONE $0 @ARGV "; benchmark ( $start_time, $msg, 1 );	
}
########################################################################
if ( $label eq 'pazar' ) {
	print "STARTED $0 @ARGV ", __date, "\n"; $start_time = time;	
	my $label_dir = "$download_dir/$label";
	unless ( -e $label_dir ) { mkdir $label_dir or croak "failed to create dir '$label_dir': $!"; }
	chdir $label_dir or croak "failed to change to dir '$label_dir' $!";
	$cmd = "wget -o $download_dir/log/$label.out @pazar_uris";
	print "> $cmd\n"; system $cmd;
	$cmd = 'unzip tftargets.zip';
	print "> $cmd\n";   system $cmd;
	$cmd = 'cat *.csv > pazar.tsv';
	print "> $cmd\n"; system $cmd;
	$cmd = 'rm *.csv';
	print "> $cmd\n"; system $cmd;
	$cmd = 'rm *.zip';
	print "> $cmd\n"; system $cmd;
	$msg = "DONE $0 @ARGV "; benchmark ( $start_time, $msg, 1 );	
}

if ( $label eq 'omim' ) {
# 	wget -r -l 1 -np -nH -nd 'ftp://anonymous:vladimir.n.mironov%40gmail.com@ftp.omim.org/OMIM/';

}

########################################################################
# if ( $label eq 'orthodb' ) {
# 	print "STARTED $0 @ARGV ", __date, "\n"; $start_time = time;
# 	if (-e $label) {$cmd = "rm -rf $download_dir/$label";  print "\t>$cmd\n"; system $cmd;} 
# 	mkdir $label or croak "failed to create dir: '$download_dir/$label' $!";
# 	chdir "$download_dir/$label"; system ( 'pwd' );
# 	my $cmd = "wget -o $download_dir/log/$label.out @orthodb_uris";
# 	print "> $cmd\n"; system $cmd;
# 	$cmd = 'gunzip *.gz';
# 	print "> $cmd\n";   system $cmd;
# 	$msg = "DONE $0 @ARGV "; benchmark ( $start_time, $msg, 1 );	
# }
################################################################################
## Note: never use the '-b' option - Perl proceeds to execute immediately the rest of the code ?
################################################################################

if ( $label eq 'obo' ) {
	print "STARTED $0 @ARGV FROM BBOP ", __date, "\n"; $start_time = time;	
	my $label_dir = "$download_dir/$label";
	unless ( -e $label_dir ) { mkdir $label_dir or croak "failed to create dir '$label_dir': $!"; }
	chdir $label_dir or croak "failed to change to dir '$label_dir' $!";
	my $cmd = "wget -r -l 1 -np -nH -nd -A $label -R $rejected -o $download_dir/log/$label.out $obof_uri";
	print "> $cmd\n"; system $cmd;
	$cmd = "rm $download_dir/robots.txt;"; 
	print $cmd, "\n"; system $cmd; 
	$msg = "DONE $0 @ARGV "; benchmark ( $start_time, $msg, 1 );	
}
################################################################################
if ( $label eq 'owl' ) {
	print "STARTED $0 @ARGV ", __date, "\n"; $start_time = time;
	my $label_dir = "$download_dir/$label";
	unless ( -e $label_dir ) { mkdir $label_dir or croak "failed to create dir '$label_dir': $!"; }
	chdir $label_dir or croak "failed to change to dir '$label_dir' $!";
	my $cmd = "wget -r -l 1 -np -nH -nd -A $label,README* -R $rejected -o $download_dir/log/$label.out $obof_uri";
	print "> $cmd\n"; system $cmd;
	$cmd = "rm $download_dir/robots.txt"; 
	print $cmd, "\n"; system $cmd; 
	$cmd = "wget $sio_uri";
	$msg = "DONE $0 @ARGV "; benchmark ( $start_time, $msg, 1 );	
}
########################################################################$$$$$$$$
if ( $label eq 'go' ) {
	print "STARTED $0 @ARGV ", __date, "\n"; $start_time = time;	
	my $label_dir = "$download_dir/$label";
	unless ( -e $label_dir ) { mkdir $label_dir or croak "failed to create dir '$label_dir': $!"; }
	chdir $label_dir or croak "failed to change to dir '$label_dir' $!";
	my $cmd = "wget -r -np -nH --cut-dirs=2 -A owl,obo,README* -q -o $download_dir/log/$label.out $go_uri";
	print "> $cmd\n"; system $cmd;
	$cmd = "rm $download_dir/robots.txt"; # sic ! full path
	print $cmd, "\n"; system $cmd; 
	$msg = "DONE $0 @ARGV "; benchmark ( $start_time, $msg, 1 );	
}
########################################################################
# TODO
if ( $label eq 'taxon' ) {
	print "STARTED $0 @ARGV ", __date, "\n"; $start_time = time;	
	my $label_dir = "$download_dir/$label";
	unless ( -e $label_dir ) { mkdir $label_dir or croak "failed to create dir '$label_dir': $!"; }
	chdir $label_dir or croak "failed to change to dir '$label_dir' $!";
	my $cmd = "wget -r -np -nH --cut-dirs=2 -A owl,obo,README* -q -o $download_dir/log/$label.out $taxon_uri";
	print "> $cmd\n"; system $cmd;	
	$cmd = "rm $download_dir/$label/robots*"; # sic ! full path
	print $cmd, "\n"; system $cmd; 
	$msg = "DONE $0 @ARGV "; benchmark ( $start_time, $msg, 1 );	
}

########################################################################


if ( $label eq 'sio' ) {
	print "STARTED $0 @ARGV ", __date, "\n"; $start_time = time;	
	my $owl_dir = "$download_dir/owl";
	unless ( -e $owl_dir ) { mkdir $owl_dir or croak "failed to create dir '$owl_dir': $!"; }
	chdir $owl_dir or croak "failed to change to dir '$owl_dir' $!";
	$cmd = "wget -o $download_dir/log/$label.out $sio_uri";
	print "> $cmd\n"; system $cmd;	
	$msg = "DONE $0 @ARGV "; benchmark ( $start_time, $msg, 1 );	
}
########################################################################

if ( $label eq 'seal' ) {
	print "FINALIZING DOWNLOAD ", __date, "\n"; $start_time = time;
	chdir $download_dir; system ( 'pwd' );
	my @dirs = `ls`; chomp @dirs; print "@dirs\n";
	map { my $cmd = "tar -cjf $_.tar.bz2 $_/"; print "> $cmd\n"; system $cmd; } @dirs;
	$cmd = "chmod 444 *.bz2"; print "> $cmd\n"; system $cmd;
	$msg = "DONE $0 @ARGV "; benchmark ( $start_time, $msg, 1 );	
}
## http://www.uniprot.org/uniprot/?query=keyword%3A%22Reference+proteome+[KW-1185]%22&sort=score # all ref proteomes
if ( $label eq 'test' ) {
	print "STARTED $0 @ARGV ", __date, "\n"; $start_time = time;	
	my $label_dir = "$download_dir/$label";
	unless ( -e $label_dir ) { mkdir $label_dir or croak "failed to create dir '$label_dir': $!"; }
	chdir $label_dir or croak "failed to change to dir '$label_dir' $!";
	my $cmd = "wget -o $download_dir/log/$label.out @entrez_uris";
	print "> $cmd\n"; system $cmd;
	$cmd = 'gunzip *.gz';
	print "> $cmd\n"; system $cmd;
	
	my $map = extract_map ($gpi_txn_lst , 0 ); 
	my $release = 'test';
	my $refseq2geneid = extract_hash ( "$label_dir/$release.accession2geneid", 0, 1 ); # taxid2gnid
	foreach my $taxon ( keys %{$refseq2geneid} ) {
		next unless $map->{$taxon};
		my $geneids = join ( ',', sort keys %{$refseq2geneid->{$taxon}} );
		get_docsums_by_list ( 'gene', $geneids, "$label_dir/$taxon.docsum" );
	}
	
## 	$cmd = "mv gene_refseq_uniprotkb_collab ncbiac2upac";
## 	print "> $cmd\n"; system $cmd;
	$msg = "DONE $0 @ARGV "; benchmark ( $start_time, $msg, 1 );	
}
########################################################################
########################################################################

sub get_all_refprots {
# TODO the code was testede in the 'test' clause, to be tested as a function
	use LWP::UserAgent;
	use HTTP::Date;
	my $dir = '/norstore/project/ssb/workspace/data/test_download/refprot';
	my $file = 'refprot.dat';
	my $query = 'http://www.uniprot.org/uniprot/?query=keyword%3A%22Reference+proteome+[KW-1185]%22&sort=score&format=txt&include=yes'; # all ref proteomes
	my $contact = ''; # Please set your email address here to help us debug in case of problems.
	my $agent = LWP::UserAgent->new(agent => "libwww-perl $contact");
	my $response= $agent->mirror($query, $file);
		if ($response->is_success) {
			my $results = $response->header('X-Total-Results');
			my $release = $response->header('X-UniProt-Release');
# 			my $date = sprintf("%4d-%02d-%02d", HTTP::Date::parse_date($response->header('Last-Modified')));
# 			print "File $file: downloaded $results entries of UniProt release $release ($date)\n";
		}
		elsif ($response->code == HTTP::Status::RC_NOT_MODIFIED) {
			print "File $file: up-to-date\n";
		}
		else {
			croak 'Failed, got ' . $response->status_line .
				' for ' . $response->request->uri . "\n";
		}
}

sub get_updata_by_taxa {
	my ( 
	$taxa,  # ref to a map
  $format, # e.g.'txt', 'fasta'
	) = @_;
	use LWP::UserAgent;
	use HTTP::Date;
	my $reference = 1; # Toggle this to 1 if you want reference instead of complete proteomes.
# # 	my $proteome = $reference ? 'reference:yes' : 'complete:yes';
	my $keyword = $reference ? 'keyword:1185' : 'keyword:181';

	my $contact = ''; # Please set your email address here to help us debug in case of problems.
	my $agent = LWP::UserAgent->new(agent => "libwww-perl $contact");
	# For each taxon, mirror its proteome 
	foreach my $taxon ( keys %{$taxa} ) {
# 		my $file = $taxon . '.dat';
		my $file = "$taxon.$format";
# 		my $query_taxon = "http://www.uniprot.org/uniprot/?query=organism:$taxon+$keyword&format=txt&include=yes";
		my $query_taxon = "http://www.uniprot.org/uniprot/?query=organism:$taxon+$keyword&format=$format&include=yes";
		my $response_taxon = $agent->mirror($query_taxon, $file);

		if ($response_taxon->is_success) {
			my $results = $response_taxon->header('X-Total-Results');
			my $release = $response_taxon->header('X-UniProt-Release');
			my $date = sprintf("%4d-%02d-%02d", HTTP::Date::parse_date($response_taxon->header('Last-Modified')));
			print "File $file: downloaded $results entries of UniProt release $release ($date)\n";
		}
		elsif ($response_taxon->code == HTTP::Status::RC_NOT_MODIFIED) {
			print "File $file: up-to-date\n";
		}
		else {
			croak 'Failed, got ' . $response_taxon->status_line .
				' for ' . $response_taxon->request->uri . "\n";
		}
	}
}

sub get_refprots_by_tax_div {

	use LWP::UserAgent;
	use HTTP::Date;

	# Taxonomy identifier of top node for query, e.g. 2 for Bacteria, 2157 for Archea, etc.
	# (see http://www.uniprot.org/taxonomy)
	my ( $top_node ) = @_;

	my $reference = 1; # Toggle this to 1 if you want reference instead of complete proteomes.
	my $proteome = $reference ? 'reference:yes' : 'complete:yes';
	my $keyword = $reference ? 'keyword:1185' : 'keyword:181';

	my $contact = ''; # Please set your email address here to help us debug in case of problems.
	my $agent = LWP::UserAgent->new(agent => "libwww-perl $contact");

	# Get a list of all taxons below the top node with a complete/reference proteome.
	my $query_list = "http://www.uniprot.org/taxonomy/?query=ancestor:$top_node+$proteome&format=list";
	#http://www.uniprot.org/taxonomy/?query=ancestor:2157+reference:yes&format=list
	my $response_list = $agent->get($query_list);
	die 'Failed, got ' . $response_list->status_line .
		' for ' . $response_list->request->uri . "\n"
		unless $response_list->is_success;

	# For each taxon, mirror its proteome in FASTA format.
	for my $taxon (split(/\n/, $response_list->content)) {
		my $file = $taxon . '.dat';
# 		my $query_taxon = "http://www.uniprot.org/uniprot/?query=organism:$taxon+$keyword&format=fasta&include=yes";
		my $query_taxon = "http://www.uniprot.org/uniprot/?query=organism:$taxon+$keyword&format=txt&include=yes";
		my $response_taxon = $agent->mirror($query_taxon, $file);

		if ($response_taxon->is_success) {
			my $results = $response_taxon->header('X-Total-Results');
			my $release = $response_taxon->header('X-UniProt-Release');
			my $date = sprintf("%4d-%02d-%02d", HTTP::Date::parse_date($response_taxon->header('Last-Modified')));
			print "File $file: downloaded $results entries of UniProt release $release ($date)\n";
		}
		elsif ($response_taxon->code == HTTP::Status::RC_NOT_MODIFIED) {
			print "File $file: up-to-date\n";
		}
		else {
			die 'Failed, got ' . $response_taxon->status_line .
				' for ' . $response_taxon->request->uri . "\n";
		}
	}
}

sub get_refprots_by_list {

	my ( $list, $out_path ) = @_; # File containg list of UniProt identifiers.

	my $base = 'http://www.uniprot.org';
	my $tool = 'batch';

	my $contact = ''; # Please set your email address here to help us debug in case of problems.
	my $agent = LWP::UserAgent->new(agent => "libwww-perl $contact");
	push @{$agent->requests_redirectable}, 'POST';

	my $response = $agent->post("$base/$tool/",
															[ 'file' => [$list],
																'format' => 'txt',
															],
															'Content_Type' => 'form-data');

	while (my $wait = $response->header('Retry-After')) {
		print STDERR "Waiting ($wait)...\n";
		sleep $wait;
		$response = $agent->get($response->base);
	}
open my $outfh, '>', $out_path;
	$response->is_success ?
# 		print $response->content :
		print $outfh $response->content :
		croak 'Failed, got ' . $response->status_line .
			' for ' . $response->request->uri . "\n";
}

sub get_docsums_by_list {
# fetches DocSums from Entrez for each provided UID
	my ( 
	$db, # Entrez DB name, lower case
	$list,  # list of UIDs, comma separted, no spaces
	$out_path 
	) = @_;
	my $base = 'http://eutils.ncbi.nlm.nih.gov/entrez/eutils/';
	#assemble  the esummary URL as an HTTP POST call
	my $url = $base . "esummary.fcgi";
	my $url_params = "db=$db&retmode=json&id=$list&version=2.0";
	#create HTTP user agent
	my $agent = new LWP::UserAgent;
	$agent->agent("esummary/2.0 " . $agent->agent);
	#create HTTP request object
	my $req = new HTTP::Request POST => "$url";
	$req->content_type('application/x-www-form-urlencoded');
	$req->content("$url_params");
	#post the HTTP request
	my $response = $agent->request($req); 

	open my $outfh, '>', $out_path;
	$response->is_success ?
# 	print $response->content :
	print $outfh $response->content :
	croak 'Failed, got ' . $response->status_line .	' for ' . $response->request->uri . "\n";
}


sub _get_idmappings {
# 	TODO this is just a draft, try to finalize
# 	# retrieves by secondary ACs as well
# 	use strict;
# 	use warnings;
# 	use LWP::UserAgent;
# 
# 	my $base = 'http://www.uniprot.org';
# 	my $tool = 'mapping';
# 
# 	my $params = {
# 		from => 'ACC',
# 		to => 'P_REFSEQ_AC',
# 		format => 'tab',
# 		query => 'P31946 P62258 B3KY71'
# 	};
# 
# 	my $contact = ''; # Please set your email address here to help us debug in case of problems.
# 	my $agent = LWP::UserAgent->new(agent => "libwww-perl $contact");
# 	push @{$agent->requests_redirectable}, 'POST';
# 
# 	my $response = $agent->post("$base/$tool/", $params);
# 
# 	while (my $wait = $response->header('Retry-After')) {
# 		print STDERR "Waiting ($wait)...\n";
# 		sleep $wait;
# 		$response = $agent->get($response->base);
# 	}
# 
# 	$response->is_success ?
# 		print $response->content :
# 		die 'Failed, got ' . $response->status_line .
# 			' for ' . $response->request->uri . "\n";
}

########################################################################################################################
my @phenomes = (
'http://downloads.yeastgenome.org/curation/literature/phenotype_data.tab',
'http://flybase.org/static_pages/downloads/FB2012_06/alleles/allele_phenotypic_data_fb_2012_06.tsv.gz',
'ftp://ftp.informatics.jax.org/pub/reports/MGI_PhenoGenoMP.rpt',
'http://compbio.charite.de/hudson/job/hpo.annotations/lastStableBuild/artifact/misc/phenotype_annotation.tab',
'http://compbio.charite.de/hudson/job/hpo.annotations/lastStableBuild/artifact/misc/phenotype_annotation_hpoteam.tab',
'http://zfin.org/downloads/downloads/phenotype.txt',
##'http://www.wormbase.org/biomart/martview' # broken link
);

sub _wget {
	## works
	my $uri = shift;
	threads->detach();
	my $cmd = "wget $uri";
	system $cmd;
}

#######################################################################################################################

# http://www.tfacts.org/TFactS-new/TFactS-v2/tfacts/data/Catalogues.xls
# http://www.pazar.info/tftargets/tftargets.zip
# http://www.grnpedia.org/trrust/trrust_rawdata.txt
