# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Uniprot.t'
#########################

use Test::More tests => 6;

#########################
# Attn: adjust the path to the bgw directory below !!
BEGIN {
	push @INC, '/home/mironov/git/bgw';
# 	push @INC, '$HOME/git/bgw'; # doesnt't work 
# 	push @INC, '~/git/bgw'; # doesnt't work 
}
use Carp;
use strict;
use warnings;
use 5.010;
use Cpanel::JSON::XS qw(encode_json decode_json);
# TODO rls => relas
use auxmod::SharedVars qw( 
%uris
%prns
%rls
%relas
);

my $verbose = 1;
if ( $verbose ) {
	$Carp::Verbose = 1;
	use Data::Dumper;
}

my $json = encode_json \%uris;
say $json;

use parsers::Pazar;

# ---------------------------------------------------------------------------------------------------------------------

my $pazar = parsers::Pazar->new ( );
ok ( $pazar ); #1
my ($data_dir, $dat_path, $map_path, $data, $out,);
$data_dir = "./t/data";
# $map_path = "$data_dir/pazar.map";

$dat_path = "$data_dir/pazar_test.tsv";
ok ( $data = $pazar -> parse ( $dat_path ) );
ok ( keys %{$data} == 3 ); 
ok ( keys %{$data->{'Pairs'}} == 3 ); 
ok ( keys %{$data->{'Pairs'}{'ENST00000219069-ENSG00000226061'}{'ExperimentalEvidence'}} == 2 );
print Dumper($data);
my $fs = '_';
my %prns = (
'gn' => ['SIO'.$fs.'010035', 'gene'],
'mrna' => ['SIO'.$fs.'010099', 'messanger RNA'], # TODO Integrate in APOs
);

my $out_path = "$data_dir/pazar_test.ttl";
ok ( $out = $pazar -> pzr2ttl ( $data, \%rls, \%uris, \%prns, ) );
print $out;
