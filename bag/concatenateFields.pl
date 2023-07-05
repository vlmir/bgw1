use Carp;
use strict;
use warnings;

# concatenats lines from input files and print concatenated lines to STDOUT
# arg: 1. number of lines to read 2. list of file paths
# best run from the dir containing input files

my ( $n, @files ) = @ARGV ;
my %fhs;
#~ map { local *FH; open *FH, '<', $_; $fhs{$_} = *FH } @files; # works as well
map { open my $FH, '<', $_; $fhs{$_} = $FH } @files;

while ( $n ) {
	my $lines;
	map { my $line = readline ( $fhs{$_} ); chomp $line; $lines = $lines.$line;  } @files;
	print $lines, "\n";
	$lines = '';
	$n--;
}
