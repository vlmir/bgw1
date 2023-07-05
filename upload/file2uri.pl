BEGIN {
push @INC, '/home/mironov/git/bgw';
}
use warnings;
use strict;
use Carp;
use auxmod::SharedSubs qw ( open_write );
use auxmod::UploadSubs qw ( get_base_file_names );
use auxmod::UploadVars qw ( $base );
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
	my $graph_uri = "$base/$ext/$_";
	my $fh = open_write ( "$dir/$_.$ext.graph" ); 
	print $fh "$graph_uri\n";
	close $fh;
} @names;
