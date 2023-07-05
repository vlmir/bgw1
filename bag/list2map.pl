use strict;
use warnings;
use Carp;
$Carp::Verbose = 1;

while ( <> ) {
	print $.-1, qq/\t/, $_;
}
