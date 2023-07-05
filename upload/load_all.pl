BEGIN {
push @INC, '/home/mironov/git/bgw';
}
use warnings;
use strict;
use Carp;
use DBI;
use auxmod::UploadSubs qw ( get_base_file_names add_triples clear_graph );
use auxmod::UploadVars qw ( $base $prefix $suffix );
$Carp::Verbose = 1;

# for loading an individual graph for each file in the dir
# generates a single sql per dir
 # outputs to STDOUT
 
my (
$dir, # for reading, MUST be full path !!
$ext, # file extension to use; e.g. rdf
) = @ARGV;

my @names = get_base_file_names ( $dir, $ext );

map { 
	my $graph_uri = "$base/$_";
	clear_graph ( $graph_uri ); 
	add_triples ( "$dir/$_.$ext", $prefix, $graph_uri ); # output to STDOUT
	} @names;

map { 
	my $graph_uri = "$base/$_$suffix";
	clear_graph ( $graph_uri ); 
	add_triples ( "$dir/$_.$ext", $prefix, $graph_uri ); # output to STDOUT
	} @names if $suffix;
	
	
