# from: https://perlmaven.com/json
use strict;
use warnings;
use 5.010;
 
use Cpanel::JSON::XS qw(encode_json decode_json);

BEGIN {
	push @INC, '/home/mironov/git/bgw' ;
}
 
use Data::Dumper;
use auxmod::SharedSubs qw(
open_read
open_write
);

my $IN = open_read('sharvars.json');
my $sharvars = '';
while (<$IN>) {$sharvars .= $_};
my $var = decode_json $sharvars;
print Dumper($var);
