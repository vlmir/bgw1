use Carp;
use strict;
use warnings;

my $start_time = time;
print "Started: " . `date`;

# NOTE: delete dir pairs/ before running
# NOTE: delete tables before running
# NOTE: $working_dir/complientFasta/ dir is required!
my ( $working_dir, $omcl_bin_dir ) = @ARGV;
chdir $working_dir; # shell 'cd' does not work here
print `pwd` . "\n";

my @commands = (
	# orthomclAdjustFasta: use bag/adjust_fasta.pl; to be run from the complintFasta dir
	#"$omcl_bin_dir/orthomclFilterFasta compliantFasta 10 20",
	#VM "formatdb -i goodProteins.fasta -n goodProteins -p T",
	#VM "blastall -p blastp -i goodProteins.fasta -d goodProteins -e 1e-05 -o goodProteins.blast -m 8 -a 8 -v 100000 -b 100000 -F 'm S' ",
    
    "$omcl_bin_dir/orthomclBlastParser goodProteins.blast compliantFasta > similarSequences.txt",
	
	"rm -rf pairs",
	"bash ~/bin/drop_all_tables.sh orthomcl orthomcl orthomcl",

	"$omcl_bin_dir/orthomclInstallSchema orthomcl.config install_schema.log",
	"$omcl_bin_dir/orthomclLoadBlast orthomcl.config similarSequences.txt",
	"$omcl_bin_dir/orthomclPairs orthomcl.config orthomcl_pairs.log cleanup=yes",
	"$omcl_bin_dir/orthomclDumpPairsFiles orthomcl.config",
#	"mcl mclInput --abc -I 1.5 -o mclOutput > mcl.log",
#	"orthomclMclToGroups OG_ 1 < mclOutput > groups.txt"
	);

map {exec_cmd ($_)} @commands;
my $end_time = time;
print "Finished: " . `date`;
my $elapsed_time = $end_time - $start_time;
print "Elapsed time: $elapsed_time\n";

sub exec_cmd {
	print "Running $_[0] " . `date`;
	system ( $_[0] ); 
	print "Done: $_[0] " . `date`;
}
