# usage: perl change_delimiter.pl '' ' ' < input.file > ouput.file

use Carp;
use strict;
use warnings;
$Carp::Verbose = 1;

my $original_delimiter = shift;
my $new_delimiter = shift;
while ( <> ) {
	print join $new_delimiter, split /$original_delimiter/;
}
