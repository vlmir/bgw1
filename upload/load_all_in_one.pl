BEGIN {
	push @INC, '/home/mironov/git/bgw';
}
use warnings;
use strict;
use Carp;
# use DBI;
use auxmod::UploadSubs qw ( get_base_file_names add_triples clear_graph );
use auxmod::UploadVars qw ( $base $prefix $suffix );
$Carp::Verbose = 1;

# a single graph for all files in the dir
# generates a single sql 

my (
$dir, # for reading, MUST be full path !!
$ext, # file extension to use
$graph, # graph name to load into (fragment), e.g. 'ontology'
) = @ARGV;
# generates one sql per dir
 # outputs to STDOUT

my @names = get_base_file_names ( $dir, $ext );

my $graph_uri = "$base/$graph$suffix";
clear_graph ( $graph_uri );

map {	 
	add_triples ( "$dir/$_.$ext", $prefix, $graph_uri );
	} @names;

	
	
