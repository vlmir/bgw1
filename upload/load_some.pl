BEGIN {
	push @INC, '/home/mironov/git/bgw';
}
use warnings;
use strict;
use Carp;
# use DBI;
use auxmod::UploadSubs qw ( add_triples clear_graph );
use auxmod::UploadVars qw ( $base $prefix $suffix );
$Carp::Verbose = 1;

# TODO transform into a function ?
# for loading specified files into individual graphs
# best run from the dir containing this script

my (
$dir, # for reading, MUST be full path !!
$ext, # file extension to use
@names, # graph names (file name minus extention)
) = @ARGV;

 # outputs to STDOUT

map { 
	my $graph_uri = "$base/$_";
	clear_graph ( $graph_uri, );
	add_triples ( "$dir/$_.$ext", $prefix, $graph_uri,  ); # outputs to STDOUT
	} @names;
	
	
map { 
	my $graph_uri = "$base/$_$suffix";
	clear_graph ( $graph_uri, );
	add_triples ( "$dir/$_.$ext", $prefix, $graph_uri,  ); # outputs to STDOUT
	} @names if $suffix;
	
