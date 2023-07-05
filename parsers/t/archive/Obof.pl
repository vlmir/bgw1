#########################

use Test::More tests => 4;

#########################

BEGIN {
	push @INC, '/home/mironov/git/bgw', '/norstore_osl/home/mironov/git/bgw';
}

use Carp;
use strict;
use warnings;

my $verbose = 1;
if ( $verbose ) {
	$Carp::Verbose = 1;
	use Data::Dumper;
};

use parsers::Obof;
use OBO::Parser::OBOParser;
use auxmod::SharedSubs qw( print_obo read_map print_counts benchmark );
use auxmod::SharedVars qw( 
%nss
%uris
);

use auxmod::UploadVars qw( 
);

my ( $start_time, $step_time, $msg );
$start_time = time;

my $parser = OBO::Parser::OBOParser->new ( );
my $obof = parsers::Obof->new ( );
ok ( $obof );

my $data_dir = './t/data';
# my $basename = 'test';
my $basename = 'go.test';

# $basename = 'test.2';
my $in_file_path = "$data_dir/$basename.obo";
my $onto = $parser-> work ( $in_file_path );
my ( $out_file_path, $id_map );
$out_file_path = "$data_dir/$basename.rdf";
$id_map = $obof-> obo2xml ( $onto, $out_file_path, 'rdfs' );
ok( $id_map );
$out_file_path = "$data_dir/$basename.ttl";
$id_map = $obof-> obo2ttl ( $onto, $out_file_path, 'rdfs' );
ok( $id_map );
print Dumper ($id_map );
$out_file_path = "$data_dir/$basename.owl";
$id_map = $obof-> obo2xml ( $onto, $out_file_path, 'owl' );
ok( $id_map );

# print Dumper ($id_map);

$in_file_path = "$data_dir/mod_test.obo";
my $type = 'Term';
my $out = $obof -> map2id ( $in_file_path, 'synonym', );
# print Dumper ( $out );
