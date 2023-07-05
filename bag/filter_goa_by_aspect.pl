# reads a GOA file from STDIN and writes filtered lines to a FILE
# Note: redirection of STDOUT to a file does not work if called from within another script !!!
use Carp;
use strict;
use warnings;

# define which aspects of GOA you want to use
my $p = shift; # biological process, 0 or 'P';
my $c = shift; # cellular component, 0 or 'C';
my $f = shift; # molecular function, 0 or 'F';
my $out_file = shift;

open my $FH, '>',  $out_file || croak "The log file couldn't be opened"; 
while (<>) {
	chomp;
	next if /\A!/xms; # !gaf-version: 2.0
	my @assoc = split(/\t/);
#	my @assoc = split; # didn't work ???
	foreach(@assoc){
		$_ =~ s/^\s+//; 
		$_ =~ s/\s+$//;		
	}
	print $FH "$_\n" if (($p and ($assoc[8] eq $p)) or ($c and ($assoc[8] eq $c)) or ($f and ($assoc[8] eq $f)));
}
