use Carp;
use strict;
use warnings;

# find max value for each category in a tab delimited file

my $field1 = shift; # the field with the categories
my $field2 = shift; # the filed with the values

my %scores; # { category => maxValue }
my %lines; # { category => [ lines ] }
while ( <> ) {
	next if substr ( $_, 0, 1) eq "\n";
	next if substr ( $_, 0, 1) eq "#";

	chomp;
	my @fields = split ( "\t" ); #print "$fields[4]\n";

	if ( ! $scores{$fields[$field1]} or ( $scores{$fields[$field1]} < $fields[$field2] )) {
		$scores{$fields[$field1]} = $fields[$field2];
		@{$lines{$fields[$field1]}} = ( $_ );
	}
	elsif ( $scores{$fields[$field1]} == $fields[$field2] ) {
		push @{$lines{$fields[$field1]}}, $_ ;
	}


}

map { my @print_lines =  @{$lines{$_}};  map { print "$_\n" } @print_lines } keys %lines;
