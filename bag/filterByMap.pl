use Carp;
use strict;
use warnings;

# filters STDIN by a map file

my $map_file = shift;
my $par1 = shift; # index or value
my $par2 = shift; # index or value

my %map;
open my $FH, '<', $map_file;
while ( <$FH> ) {
	next if substr ( $_, 0, 1) eq "\n";
	next if substr ( $_, 0, 1) eq "#";
	chomp;
	my @fields = split ( "\t" );
#	$map{$fields[$par1]} = $fields[$par1] if $fields[$par1] > $par2; # adjust comparison if needed
	$map{$fields[$par1]} = $fields[$par1]; # for single column map files
	#~ my $gene = shift @fields; map { $map{$_} = $gene } @fields; # [ rat_AC, mouse_AC, human_AC ] for TFs without TGs
}
while ( <> ) {
	next if substr ( $_, 0, 1) eq "\n";
	next if substr ( $_, 0, 1) eq "#";
	chomp;
	my @fields = split ( "\t" ); #print "$fields[4]\n";
	print "$_\n" if ! $map{$fields[$par2]}; # adjust the condition
	#~ print "$_\n" if ( $map{$fields[$par1]} and ( $fields[$par1] ne $fields[$par2] ) ); # for abc files
	#~ print "$_\n" if ($map{$fields[$par1]} or $map{$fields[$par2]}); # used for the initial filtering of abc files; should not be used
}
