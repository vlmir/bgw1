# produces an sql for closures for a specified graph

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
add_priority_over_isa
add_transitivity
add_transitivity_over
);
use auxmod::UploadVars qw ( $sparql_prefixes );
$Carp::Verbose = 1;

my (
$graph, # with a suffix !!!
$dir, # full path for writing
) = @ARGV;

# boolean
my $supr_cl = 1; # boolean
my $ssmp_cl = 1; # boolean
my $trns_cl = 1; # boolean
my $trnsov_cl = 1; # boolean
my $provis_cl = 1; # boolean
my $final = 1;  # boolean
my %supr_rls = (
'obo:RO_0002212' => 'obo:RO_0002211',
'obo:RO_0002213', => 'obo:RO_0002211',
);
my @trns_rls = ( 'obo:BFO_0000050' );
my %trnsov_rls = ( 
'obo:RO_0002211' => 'obo:BFO_0000050', 
'obo:RO_0002212' => 'obo:BFO_0000050', 
'obo:RO_0002213' => 'obo:BFO_0000050', 
);
my ( $out_file, $SQL );
if ( $dir ) {
	$out_file = "$dir/close_$graph-$supr_cl$ssmp_cl$trns_cl$provis_cl$trnsov_cl$final.sql" ;
	open $SQL, '>', $out_file or croak "Failed to open file $out_file: $!";
}
#~ add_reflexive_closures ( $graph, $sparql_prefixes, $rfl_cl, $SQL, );
map {add_superproperties ( $graph, $_, $supr_rls{$_}, $sparql_prefixes, $SQL )} keys %supr_rls if $supr_cl;
add_subsumption ( $graph, $sparql_prefixes, $SQL ) if $ssmp_cl;
## add_transitivity should be repeated once after add_priority_over_isa
map {add_transitivity ( $graph, $_, $sparql_prefixes, $SQL)} @trns_rls if $trns_cl;
map {add_transitivity_over ( $graph, $_, $trnsov_rls{$_}, $sparql_prefixes, $SQL)} keys %trnsov_rls if $trnsov_cl;
## add_priority_over_isa shoiuld be repeated once after the second iteration of add_transitivity
add_priority_over_isa ( $graph, $sparql_prefixes, $SQL ) if $provis_cl;
map {add_transitivity ( $graph, $_, $sparql_prefixes, $SQL)} @trns_rls if $final;
add_priority_over_isa ( $graph, $sparql_prefixes, $SQL ) if $final;
# add_chains ( $graph, $sparql_prefixes, $cmpsn_cl, $SQL, );
close $SQL if $dir;
