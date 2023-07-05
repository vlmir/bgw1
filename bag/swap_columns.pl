

use Carp;
use strict;
use warnings;
$Carp::Verbose = 1;

#use PipelineSubs.pm;

my ( $in_file, $out_file ) = @ARGV ;
open my $IN, '<', $in_file or croak "Can't open file '$in_file': $!";
open my $OUT, '>', $out_file or croak "Can't open file '$out_file': $!";
while (<$IN>) {
	chomp;
	my @fields = split /\t/;
	( $fields[0], $fields[1] ) = ( $fields[1], $fields[0] );
	print $OUT "$fields[0]\t$fields[1]\t$fields[2]\n";
}
close $IN; close $OUT;
