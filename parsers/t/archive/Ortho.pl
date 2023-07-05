# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl NewIntact.t'

#########################

use Test::More tests => 10;

#########################

BEGIN {
	push @INC, '/home/mironov/git/bgw', '/norstore_osl/home/mironov/git/bgw';
}
use Carp;
use strict;
use warnings;
use OBO::Parser::OBOParser;
use parsers::Ortho;

my $verbose = 1;
if ( $verbose ) {
	$Carp::Verbose = 1;
	use Data::Dumper;
};

use auxmod::SharedSubs qw( print_obo read_map print_counts benchmark );
use auxmod::SharedVars qw( 
%nss
);
my $PRTNS = $nss{'prt'};

my $real_test = 0;
my $data_dir = "./t/data";
my $up_map_path = "$data_dir/up.map";
#~ my $up_map_path = '/norstore/project/git/workspace/data/uniprot/up.map';
$up_map_path = '/norstore/project/git/workspace/data/uniprot/up.map' if $real_test;
my $up_map = read_map ( $up_map_path );
my $protein;
my $obo_parser = OBO::Parser::OBOParser->new ( );
my ( $start_time, $step_time, $msg );
############################# processing abc data ##############################

# -------------------------------- parsing -------------------------------------

my $ortho = parsers::Ortho->new ( );
ok ( $ortho );
# my $fs = ':'; ## Should NOT ever be changed !!!

my $ortho_file = "$data_dir/ortho.abc";
my $key = 'orl2orl';
my $data = $ortho-> parse_abc(
$ortho_file,
# $key,
# $up_map
);
# print Dumper ( $data );
ok ( keys %{$data->{$PRTNS}} == 5 );
ok ( keys %{$data->{$PRTNS}{'Q6Q0N3'}{$PRTNS}} == 2 );
print_counts ( $data, 2 );
#-------------------------- ortho2onto -----------------------------------------

my $in_obo_path = "$data_dir/test.obo";
my $onto = $obo_parser->work ( $in_obo_path );
print_obo ( $onto, "$data_dir/test.0.obo" ) if $verbose;
ok ( ! $onto-> get_term_by_id ( $PRTNS.':Q86UY8' ) );
ok ( ! $onto-> get_term_by_id ( $PRTNS.':Q6Q0N3' ) );

my $result = $ortho-> ortho2onto (
$onto,
$data,
$key,
$up_map
);
ok ( keys %{$result} == 3 );
my ( $prt, @rels);
ok ( $prt = $onto-> get_term_by_id ( $PRTNS.':Q86UY8' ) );
@rels = $onto->get_relationships_by_source_term ( $prt ); #print Dumper ( \@rels );
ok ( @rels = 3 );

ok ( $prt = $onto-> get_term_by_id ( $PRTNS.':Q6Q0N3' ) );
@rels = $onto->get_relationships_by_source_term ( $prt ); #print Dumper ( \@rels );
ok ( @rels = 5 );

print_obo ( $onto, "$data_dir/test.3.obo" ) if $verbose;
$msg = 'OK'; benchmark ( $start_time, $msg, 0 ) if $real_test;

