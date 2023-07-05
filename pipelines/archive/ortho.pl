## Note: only for APOs
BEGIN {
	unshift @INC, '/norstore/user/mironov/git/bin/onto-perl/lib';
	push @INC, '/norstore/user/mironov/git/scripts';
}

use Carp;
use strict;
use warnings;
# use Date::Manip qw(ParseDate UnixDate);

my $verbose = 1;
if ( $verbose ) {
	$Carp::Verbose = 1;
	use Data::Dumper;
};
use IO::Handle;
*STDOUT->autoflush();


use auxmod::SharedSubs qw( 
open_read
open_write
print_obo 
read_map
extract_map
filter_tsv_by_map
print_counts 
benchmark
__date
);

use auxmod::SharedVars qw(
$projects_dir
$ortho_dir
$workspace_dir
%nss
%rls
%organisms
);

my $run_blast = 0;
my $run_orthagogue = 1;

# 
# my @apo_taxa = (
# 3702,
# 6239,
# 7227,
# 559292,
# 284812,
# 8364,
# 9606,
# 10090,
# 10116,
# );

my @apo_taxa = keys %organisms;

### Directories
# my $ortho_dir = $projects_dir . '/ortho';
# my $log_dir = $ortho_dir .'/log';
# my $dat_dir = "$ortho_dir/data";

unless ( -e $ortho_dir ) { mkdir $ortho_dir or croak "failed to create dir '$ortho_dir': $!"; }
chdir "$ortho_dir"; system ( 'pwd' );

#############################  blast ###########################################

# TODO move blast and orthagogue into shell scripts
# TODO implement filtering by UP ACs !!
if ( $run_blast ) {
	# filtering fasta file
# 	`orthomclFilterFasta fasta 10 20`; # ( $minLength, maxStopPercent ) # depricated

	my $fasta_file = "$ortho_dir/apo.fst"; # for writing
# 	map { my $file = "$projects_dir/data/uniprot/$_.fa";  `ls -l $file`; `cat $file >> $fasta_file` } @apo_taxa;
	my @src_files = map { "$projects_dir/data/uniprot/$_.fa"; } @apo_taxa; # TODO to be tested
	print "source files:\n";
	map { `ls -l $_` } @src_files;
	my $cmd = "cat @src_files > $fasta_file";
	system ( $cmd );
	print "APO fasta file:\n";
	`ls -l $fasta_file`;
	`scp $fasta_file kg:/work/mironov/mpiblast/apo`; # better empty the MPI dir beforehand, though not stricktly needed
}
# took < 3.5h on kg for apo
#############################  orthagogue ######################################
# TODO sort out the situation with the working dir
if ( $run_orthagogue ) {
	print "STARTED orthagogue\n"; my $start_time = time;
	my $data_path = "$ortho_dir/apo.blast";
	my $blast_file = 'kg:/work/mironov/outputs/mpiblast/apo/apo.blast';
	print "> fetching blast file: $blast_file\n";
	`scp $blast_file $data_path`;
	## Note: report_orthAgogue/ is always saved in ./
	`cd $ortho_dir; pwd`;
	print "> using blast file: $data_path\n";
# 	`orthAgogue -i $data_path -p 2 -o 50 -c 8  > $log_dir/orthagogue.out`; # takes no time
	`orthAgogue -i $data_path -p 2 -o 50 -c 8`; # takes no time
	`cat $ortho_dir/orthologs.abc $ortho_dir/co_orthologs.abc > $ortho_dir/all_orthologs.abc`;
	my $msg = "DONE "; benchmark ( $start_time, $msg, );
}
