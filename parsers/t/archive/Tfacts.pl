
#! /usr/bin/perl
BEGIN {
	push @INC, '/home/mironov/git/bgw', '/datamap/home_mironov/git/bgw', '/norstore_osl/home/mironov/git/bgw';
}
use Carp;
use strict;
use warnings;
# from: https://perlmaven.com/json
use 5.010; # needed even though perl 5.26 installed
# to install Cpanel::JSON::XS gcc and make are required
# then: cpan Cpanel::JSON::XS
use Cpanel::JSON::XS qw(encode_json decode_json);
use Test::More tests => 2;

use auxmod::SharedSubs qw( 
print_obo 
read_map 
print_counts 
benchmark 
open_write
);
# TODO rls => relas
use auxmod::SharedVars qw( 
%uris
%nss
);

my $verbose = 1;
if ( $verbose ) {
	$Carp::Verbose = 1;
	use Data::Dumper;
}

use OBO::Parser::OBOParser;
use parsers::Tfacts;


my $obo_parser = OBO::Parser::OBOParser->new ( );
my $tfacts = parsers::Tfacts->new ( );
ok ( $tfacts );

my $data_dir = '/home/mironov/git/bgw/parsers/t/data';
my $tfacts_file = "$data_dir/tfacts_signsensitive_test.csv";
my $gene_info_file = "$data_dir/gene_info_tfacts.csv";
my $data = $tfacts-> parse ( $tfacts_file, $gene_info_file, );
ok ( %{$data} );
my $var = encode_json $data;
say $var;

