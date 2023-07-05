use Carp;
use strict;
use warnings;
$Carp::Verbose = 1;

# Note: orthomclAdjustFasta writes in the current directory
# Note: 5 char taxon labels are acceptable for OMCL2
# 

my ( 
$omcl_bin_dir, 
$fasta_dir, 
$index # proteinID field ( 1, 2 etc)
) = @ARGV;

foreach my  $file (`ls $fasta_dir`) {
	if ($file =~ /\.fasta/xms) {
		# TODO - use perl's readdir
		chomp ($file);
		# extracting unique taxon labels		 
		my ( $taxon, $ext ) = split /\./, $file;
		$file = "$fasta_dir/$file";
#		my $cmd = "$omcl_bin_dir/orthomclAdjustFasta $taxon $file $index 2>$taxon.err > $taxon.log";
		my $cmd = "$omcl_bin_dir/orthomclAdjustFasta $taxon $file $index";
		system ( $cmd );		
		
	}
}
