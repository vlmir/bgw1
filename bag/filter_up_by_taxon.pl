use Carp;
use strict;
use warnings;

my  $taxon =shift;
my $dat_file = shift;
my $map_file = shift;
#my ($taxon, $dat_file, $map_file) = @ARGV; # this does not work
open my $DAT, '>', $dat_file or croak "File $dat_file cannot be opened\n";
open my $MAP, '>', $map_file or croak "File $dat_file cannot be opened\n";
my $count = 0;
if ($taxon =~ /\A\d+\z/xms) { # NCBI ID
	local $/ = "\n//\n";
	while (<>) {	  
		if ( /^OX\s+NCBI_TaxID=$taxon;/xms) {
			$count++;
			print $DAT "$_";
			/\AID\s+(\w+)/xms or carp "format problem\n";
			my $id = $1;
			/^AC\s+(\w+)/xms; # matches only the first AC
			my $ac = $1;
			print $MAP "$ac\t$id\n";
		}
	}
}
else { # UniProt taxon label, e.g. ARATH or arath
#	uc ($taxon); # did not work
	local $/ = "\n//\n";
	while (<>) {	  
		if ( /\AID\s+(\w+_$taxon)\s/xmsi ) {
			$count++;
			print $DAT "$_";
			my $id = $1;
			/^AC\s+(\w+)/xms; # matches only the first AC
			my $ac = $1;
			print $MAP "$ac\t$id\n";
		}	
	}
}
close $DAT;
close $MAP;
print "$taxon: $count\n";
