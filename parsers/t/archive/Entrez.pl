# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl GoaParser.t'

#########################

use Test::More tests => 10;

#########################


use Carp;
use strict;
use warnings;

BEGIN {
	push @INC, '/home/mironov/git/bgw', '/norstore_osl/home/mironov/git/bgw';
	}

my $real_test = 0;

my $verbose = 1;
if ( $verbose ) {
	$Carp::Verbose = 1;
	use Data::Dumper;
};

use parsers::Entrez;
use OBO::Parser::OBOParser;
use parsers::Uniprot;
use auxmod::SharedSubs qw( print_obo read_map print_counts benchmark );

my ( $start_time, $step_time, $msg );
$start_time = time;

my $obo_parser = OBO::Parser::OBOParser-> new ( );
my $entrez = parsers::Entrez-> new ( );
# my $uniprot = parsers::Uniprot-> new ( );
ok ( $entrez );

my $data_dir = './t/data';
my $upgi_map_path = "$data_dir/up-gi.map";
ok ( my $gnid2upacs = read_map ( $upgi_map_path, 1 ) ); # [gnid => [upacs]}
print Dumper($gnid2upacs);
####################### parse_genes ######################################
my $source_path = "$data_dir/gene_info.30970";
my $data = {};
$step_time = time;
ok ( $data = $entrez-> parse_genes ( $source_path, $gnid2upacs ) ); 
# print Dumper ( $data );
print_counts ( $data ) if $verbose;

########################## entrez2onto #########################################

$source_path = "$data_dir/test.obo";
my $onto = $obo_parser-> work ( $source_path );
$onto->name('cco');
my $onto_name = $onto->name();
print_obo ( $onto, "$data_dir/test.0.obo" ) if $verbose;

ok ( my $genes = $entrez-> entrez2onto ( $onto, $data, $gnid2upacs ) );
ok ( my $gene = $onto-> get_term_by_name ( 'CG3038' ) );
my ( $rel, @heads );
$rel = $onto-> get_relationship_type_by_id ( 'inheres_in' );
@heads = @{$onto-> get_head_by_relationship_type ( $gene, $rel ) };
ok ( @heads = 1 );
$rel = $onto-> get_relationship_type_by_id ( 'is_a' );
@heads = @{$onto->get_head_by_relationship_type ( $gene, $rel ) };
ok ( @heads == 1 );
$rel = $onto-> get_relationship_type_by_id ( 'encodes' );
@heads = @{$onto-> get_head_by_relationship_type ( $gene, $rel ) };
ok ( @heads == 1 );

print_obo ( $onto, "$data_dir/test.6.obo" ) if $verbose;

######################### gene2accession ###############################
# !!! the test file contains already versioned UP ACs !!!
$step_time = time;
$source_path = "$data_dir/gene2accession.30970";
my $map_path = "$data_dir/gene2uniprot.30970";
my $map = read_map ( $map_path, 2 );
ok ( $data = $entrez-> parse_accs ( $source_path, $data, $map ) );
# print Dumper ( $data );
print_counts ( $data );
############################ gene2ensembl ##############################
$step_time = time;
$source_path = "$data_dir/gene2ensembl.30970";
ok ( $data = $entrez-> parse_ensembl ( $source_path, $data ) );
#~ print_counts ( $data );
########################################################################
## the expected counts after running the first 2 functions (the 3rd one does not add entries)
#~ GENES:geneId 1
#~ LOG:noUpAc 6
#~ PROTS:proteinAc 8
#~ RNAS:rnaAc 4
#~ TAXA:taxonId 1
#~ UNIPROT:UniProtAc 2
########################## entrez2rdf ##################################

my $out_path = "$data_dir/entrez.test.ttl;";
$entrez-> entrez2ttl ( $data, $out_path, );

############################## entrez2onto ##############################

