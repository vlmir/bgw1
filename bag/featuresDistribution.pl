use Carp;
use strict;
use warnings;


my %counts = ();
while ( <> ) {
	next if substr ( $_, 0, 1) eq '#';
	next if substr ( $_, 0, 1) eq "\n";
	chomp;
	my @fields = split ( " " ); #print "$fields[4]\n";
	my $count = 0;
	map { $count++ if $_ } @fields;
	$counts{$count}++;

	#~ print "$_\n" if $fields[4] < $p_value and $fields[3] == $freq ;
	#~ $p_value ? $counts{$fields[$field]}++  if $fields[4] < $p_value : $counts{$fields[$field]}++ ;
	#~ $counts{$fields[$field]}++ ;

}
map { print "$_\t$counts{$_}\n" } keys %counts;

