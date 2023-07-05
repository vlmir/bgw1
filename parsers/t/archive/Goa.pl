# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl GoaParser.t'

#########################

use Test::More tests => 19;

#########################

use Carp;
use strict;
use warnings;

BEGIN {
	push @INC, '/home/mironov/git/bgw', '/norstore_osl/home/mironov/git/bgw';
}

my $verbose = 1;
if ( $verbose ) {
	$Carp::Verbose = 1;
	use Data::Dumper;
};

use parsers::Goa;
use OBO::Parser::OBOParser;
use auxmod::SharedSubs qw( print_obo read_map print_counts benchmark );
use auxmod::SharedVars qw( 
%nss
);

my $PRTNS = $nss{'prt'};
our %taxon_labels = (
'9606' => 'human',
'10090' => 'mouse',
);

my ( $start_time, $step_time, $msg );
$start_time = time;

my $obo_parser = OBO::Parser::OBOParser-> new ( );
my $goa = parsers::Goa-> new ( );
ok ( $goa );

my $data_dir = "./t/data";
my $map_path = "$data_dir/up.map";
my $goa_path = "$data_dir/test.goa";
################################ filter ########################################
my $goa_p_path = "$data_dir/test.p.goa"; # for writing
my $goa_c_path = "$data_dir/test.c.goa"; # for writing
my $goa_f_path = "$data_dir/test.f.goa"; # for writing
$goa->  filter_by_aspect ($goa_path, $goa_p_path, 'P');
ok (1);
################################ parse #########################################
# $step_time = time;
# my $data = $goa-> parse_gaf ( $goa_path, read_map ( $map_path ) ); # print Dumper($data);
# print_counts ( $data );
# ok ( keys %{$data} == 3 );
# ok ( keys %{$data-> {'GOAs'}{'C'}} == 2 );
# ok ( keys %{$data-> {'GOAs'}{'F'}} == 1 );
# ok ( keys %{$data-> {'GOAs'}{'P'}} == 3 );

############################## gaf2onto ########################################

my $in_obo_path = "$data_dir/test.obo";
my $onto = $obo_parser-> work ( $in_obo_path );
$onto->name('cco');
my $onto_name = $onto->name();
print_obo ( $onto, "$data_dir/test.0.obo" ) if $verbose;

my ($asp, $rels, $result, $protein);

# ok ( my $gotm = $onto-> get_term_by_id ( "GO:0030308" ) );
# ok ( ! $onto-> get_term_by_id ( "$PRTNS:Q16647" ) );
# print_obo ( $onto, "$data_dir/test.0.obo" ) if $verbose;
# # Note: gaf2onto needs a SINGLE aspect/relation type !!
# 
# $asp = 'P';
# $result = $goa-> gaf2onto ( $onto, $data, $asp,);
# ok ( keys %{$result} != 0 );
# # print Dumper ( $result );
# ## terms
# ok ( $protein = $onto-> get_term_by_id ( "$PRTNS:Q16647" ) );
# 
# ok ( ! $onto-> get_term_by_id ( "$PRTNS:D3YT69" ) );
# # relations
# $rels = $onto-> get_relationships_by_source_term ( $protein, );
# ok ( @{$rels} == 2 );
# my $rltp = $onto-> get_relationship_type_by_name ( $rls{'prt2bp'}-> [1] );
# my @heads = @{$onto-> get_head_by_relationship_type ( $protein, $rltp )};
# my @tails = @{$onto-> get_tail_by_relationship_type ( $gotm, $rltp )};
# ok ( @heads == 1 );
# ok ( @tails == 1 );
# ok ( keys %{$result} != 0 );
# 
# #-------------------------------------------------------------------------------
# 
# $asp = 'F';
# ok ( $protein = $onto-> get_term_by_id ( "$PRTNS:Q16647" ) );
# $result = $goa-> gaf2onto ( $onto, $data, $asp,);
# ok ( keys %{$result} ); # sic
# $rels = $onto-> get_relationships_by_source_term ( $protein, );
# ok ( @{$rels} == 3 ); # sic, no rel to the term 'protein'
# print_obo ( $onto, "$data_dir/test._1.obo" ) if $verbose;


#=========================================================================
ok ( my $gotm1 = $onto-> get_term_by_id ( "GO:0005634" ) ); # for $gpa_data
ok ( my $gotm2 = $onto-> get_term_by_id ( "GO:0010468" ) ); # for $gpa_data #18
#================================================================================
my $gpi_path = "$data_dir/test.gpi";
my $gpi_map_path = "$data_dir/upac2taxid.map";
ok ( my $map = $goa-> parse_gpi( $gpi_path, $gpi_map_path, \%taxon_labels ) ); #print Dumper ($map);
my $gpa_path = "$data_dir/test.gpa";
$onto = $obo_parser-> work ( $in_obo_path );
# Note: gpa2onto needs a SINGLE aspect/relation type !!


## BP
ok ( my $gpa_p_data = $goa-> parse_gpa ( $gpa_path, $map ) );  print Dumper ( $gpa_p_data );
print_counts ( $gpa_p_data );
ok ( ! $onto-> get_term_by_id ( "$PRTNS:B2RUJ5" ) ); # for $gpa_data
my $gpa_p_result;
ok ( $gpa_p_result = $goa-> gpa2onto ( $onto, $gpa_p_data, 'prt2bp', ) ); # should stay here ! (not clear why)

ok ( my $prt = $onto-> get_term_by_id ( "$PRTNS:B2RUJ5" ) );
$rels = $onto-> get_relationships_by_source_term ( $prt ); # print Dumper($rels);
ok ( @{$rels} == 2 );
my $added_prts = keys %{$gpa_p_result};
ok ( $added_prts == 1 );

## CC
ok ( my $gpa_c_data = $goa-> parse_gpa ( $gpa_path, $map ) ); # print Dumper ( $gpa_c_data );
print_counts ( $gpa_c_data );
ok ( $onto-> get_term_by_id ( "$PRTNS:A2A288" ) ); # for $gpa_data
my $gpa_c_result;
ok ( $gpa_c_result = $goa-> gpa2onto ( $onto, $gpa_c_data, 'prt2cc', ) );
ok ( my $prt1 = $onto-> get_term_by_id ( "$PRTNS:A2A288" ) );
$rels = $onto-> get_relationships_by_source_term ( $prt1 ); # print Dumper($rels);
ok ( @{$rels} == 1 ); # no is_a; no involved_in - the corresponding GO:0000187 is absent in test.obo
$added_prts = keys %{$gpa_c_result};
ok ( $added_prts == 0 );
print_obo ( $onto, "$data_dir/test.1.obo" ) if $verbose;
############################### goa2rdf ########################################

ok ( my $gpa_data = $goa->  parse_gpa ( $gpa_path, $map ) ); #print Dumper ( $gpa_data );
print_counts ( $gpa_data );
my $ttl_path = "$data_dir/gpa.test.ttl";
ok ( my $ttl_out = $goa->  gpa2ttl ( $gpa_data, $ttl_path, ) );
