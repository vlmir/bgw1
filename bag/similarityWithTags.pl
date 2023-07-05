# input1: index \s tag
# input2: index1 \s index2 \s score (STD)
# output: index1 \s index2 \s score \s bolean (STD)
# function: prepares the data for ROC

use Carp;
use strict;
use warnings;
use Data::Dumper;

my $file = shift;
my %clusters = ();
open my $FH, '<', $file;
while ( <$FH> ) {
	#~ next if substr ( $_, 0, 1) eq "\n";
	chomp;
	my ( $ind, $val ) = split;
	#~ $val ? $clusters{$ind} = $val : $clusters{$ind} = ''; # does not work
	if ( $val ) { $clusters{$ind} = $val } else { $clusters{$ind} = '' };	
}

while ( <> ) {
	chomp;
	my @fields = split;
	my $left = $clusters{$fields[0]};
	next unless $left;
	my $right = $clusters{$fields[1]};
	next unless $right;

	if ( $left eq $right ) {
		print "@fields 1\n";		
	}
	else {
		print "@fields 0\n";		
	}
}
