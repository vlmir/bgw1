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
# from: https://perlmaven.com/json
use 5.010; # needed even though perl 5.26 installed

# to install Cpanel::JSON::XS gcc and make are required
# then: cpan Cpanel::JSON::XS
use Cpanel::JSON::XS qw(encode_json decode_json);
use Data::Dumper;
use auxmod::SharedVars qw(
%olders
%props
%aprops
%uris
);

my %var = (
'Class' => \%olders,
'ObjectProperty' => \%props,
'AnnotationProperty' => \%aprops,
'uris' => \%uris
);
my $var = encode_json \%var;
say $var;

