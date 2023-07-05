#! /usr/bin/perl
BEGIN {
	my @homes = (
	'/home/mironov/git/usr/bgw', 
	);
	push @INC, @homes;
}
use Carp;
use strict;
use warnings;
use Test::More tests => 3;
my $verbose = 1;
if ( $verbose ) {
	$Carp::Verbose = 1;
	use Data::Dumper;
};
use parsers::Obof;
my $obof = parsers::Obof->new ( );
ok ( $obof );
my $base_dir = '../tdata';
my $data_dir = "$base_dir/obof";
my $map_dir = "$base_dir/maps";
my $file;
my $map_path;
my $map;
my $data;
###############################################################################

use OBO::Parser::OBOParser; # needed 
my $parser = OBO::Parser::OBOParser->new ( ); # needed 
$file = "$data_dir/tgo.obo";
my $onto = $parser-> work ( $file ); # needed 
substr($file, -3, 3) = 'ttl'; # the right way of changing exptentions !!
$map = $obof-> obo2ttl ( $onto, $file, 'rdfs' );
ok( $map );
# print Dumper ($map);
$file = "$data_dir/tmod.obo";
$map = $obof -> map2id ( $file, 'synonym', );
ok ( $map );
