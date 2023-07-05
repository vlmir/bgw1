use Carp;
use strict;
use warnings;

#  reads a tab delimited file from STDIN and prints a specified field to STDOUT
# arg:
# 1. field index, indexing starts at '0'
# 2. '1' to include line numbers, '0' or nothing otherwise
# empty and commented lines are skipped

my $field = shift;
croak 'enter field number' if ! $field;
my $ln = shift;
while ( <> ) {
	next if substr ( $_, 0, 1) eq "\n";
	next if substr ( $_, 0, 1) eq "#";
	chomp;
	my @fields = split ( "\t" );
	my $value = $fields[$field];
	#~ defined $value ? print $value,  "\n" : print 0, "\n";
	$ln ? print $.-1, "\t", $value, "\n" : print $value, "\n";
}
