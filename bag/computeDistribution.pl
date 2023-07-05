use Carp;
use strict;
use warnings;

#~ my ( $freq, $p_value ) = @ARGV;
my $field = shift;
# my $p_value = shift;
my %counts = ();
while ( <> ) {
	next if substr ( $_, 0, 1) eq '#';
	chomp;
	my @fields = split ( "\t" ); #print "$fields[4]\n";
	#~ print "$_\n" if $fields[4] < $p_value and $fields[3] == $freq ;
	#~ $p_value ? $counts{$fields[$field]}++  if $fields[4] < $p_value : $counts{$fields[$field]}++ ;
	$counts{$fields[$field]}++ ;

}
map { print "$_\t$counts{$_}\n" } keys %counts;

