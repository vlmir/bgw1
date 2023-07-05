# constructs closures for graphs corresponding to all rdf|ttl|owl in a specified dir
# the directory contains only one type of files

BEGIN {
	push @INC, '/home/mironov/git/bgw';
}
use warnings;
use strict;
use Carp;
use DBI;
use auxmod::UploadSubs qw ( 
add_superproperties
add_subsumption
add_transitivity
add_priority_over_isa
add_chains
get_graphs
);
use auxmod::UploadVars qw ( $sparql_prefixes $suffix );
$Carp::Verbose = 1;

# the number of iterations
my (
#~ $rfl_cl,# the number of iterations
$sprl_cl,# the number of iterations
$ssmp_cl,# the number of iterations
$trns_cl,# the number of iterations
$provis_cl,# the number of iterations
$cmpsn_cl,# the number of iterations
$dir,
#~ $suffix, # e.g. '-tc'
) = @ARGV;
# TODO replace 'get_graphs' with 'get_base_file_names'
my @graphs = get_graphs ( $dir ); # gets base file names for all .rdf, .owl, .ttl !!!
my $out_file = "$dir/close_all-$sprl_cl$ssmp_cl$trns_cl$provis_cl$cmpsn_cl.sql";

open my $SQL, '>', $out_file or croak "Failed to open file $out_file: $!";
#~ map { add_reflexive_closures ( $_.$suffix, $sparql_prefixes, $rfl_cl, $SQL, ) } @graphs;
map { add_superproperties ( $_.$suffix, $sparql_prefixes, $sprl_cl, $SQL, ) } @graphs;
map { add_subsumption ( $_.$suffix, $sparql_prefixes, $rfl_cl, $SQL, ) } @graphs;
map { add_transitivity ( $_.$suffix, $sparql_prefixes, $trns_cl, $SQL, ) } @graphs;
# the interface for the 2 subs below changed !!! 
# TODO test
map { add_priority_over_isa ( $_.$suffix, $sparql_prefixes, $provis_cl, $SQL, ) } @graphs;
map { add_chains ( $_.$suffix, $sparql_prefixes, $cmpsn_cl, $SQL, ) } @graphs;
close $SQL;
