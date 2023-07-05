# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl NewIntact.t'

#########################

use Test::More tests => 20;

#########################
# TODO reduce the number of interactons in the input file ?

BEGIN {
	push @INC, '/home/mironov/git/bgw', '/datamap/home_mironov/git/bgw', '/norstore_osl/home/mironov/git/bgw';
}
use Carp;
use strict;
use warnings;
use OBO::Parser::OBOParser;
use parsers::Intact;

my $verbose = 1;
if ( $verbose ) {
	$Carp::Verbose = 1;
	use Data::Dumper;
};

use auxmod::SharedSubs qw( 
print_obo 
read_map
print_counts 
benchmark );
use auxmod::SharedVars qw( 
%nss
%uris
);
my $PPINS = $nss{'ppi'};
my $PRTNS = $nss{'prt'};

my $real_test = 0;
my $data_dir = "./t/data";
my $up_map_path = "$data_dir/up.map";
my $up_map = read_map ( $up_map_path );
my $protein;
my $obo_parser = OBO::Parser::OBOParser->new ( );

############################# processing tabular data #########################################	

# -------------------------------- parsing ----------------------------------------------------

my $intact = parsers::Intact->new ( );
ok ( $intact );
my $intact_file = "$data_dir/intact_short.tsv";
#~ my $intact_file = "$data_dir/intact_P11387.tsv";

my $data = $intact->parse_tab (
$intact_file,
$up_map
);
# print Dumper ( $data );
ok ( keys %{$data} == 4 );
ok ( keys %{$data->{'Interactions'}{'intact'}} == 1 );
ok ( keys %{$data->{'Participants'}{'uniprotkb'}} == 2 );

# -------------------------- intact2onto -------------------------------------------------------
my $in_obo_path = "$data_dir/test.obo"; # test.1.obo might be more informative for debugging
my $onto = $obo_parser->work ( $in_obo_path );
	$onto->name('cco');
	my $onto_name = $onto->name();

print_obo ( $onto, "$data_dir/test.0.obo" ) if $verbose;
ok ( ! $onto->get_term_by_id ( $PRTNS.':Q9BZD4' ) );
ok ( ! $onto->get_term_by_id ( $PRTNS.':O14777' ) );

ok ( ! $onto->get_term_by_id ( $PPINS.':EBI-2554618' ));
ok ( ! $onto->get_term_by_id ( $PRTNS.':Q9BZD4' ) );
ok ( ! $onto->get_term_by_id ( $PRTNS.':O14777' ) );

my $result;
$result = $intact->intact2onto (
$onto,
$data,
$up_map,
);
ok ( keys %{$result} == 2); # print Dumper ( $result);

#~ # terms
ok ( $protein = $onto->get_term_by_id ( $PRTNS.':Q9BZD4' ) );
ok ( $protein = $onto->get_term_by_id ( $PRTNS.':O14777' ) );
ok ( my $interaction = $onto->get_term_by_id ( $PPINS.':EBI-2554618' ));
# relations
ok ( my $rel_type = $onto->get_relationship_type_by_id( 'has_agent' )); # print Dumper($rel_type);
my @rels = $onto->get_relationships_by_source_term ( $interaction ); # print Dumper ( \@rels );
ok ( @rels = 3 );
my @tails = @{$onto->get_tail_by_relationship_type ( $protein, $rel_type )}; # print Dumper ( \@tails );
ok ( @tails == 1 );
my @heads = @{$onto->get_head_by_relationship_type ( $interaction, $rel_type )};
ok ( @heads == 2 );
@rels = $onto->get_relationships_by_source_term ( $interaction );
ok ( @rels = 2 ); #18

#------------------------- parsing without map ---------------------------------
$data = $intact->parse_tab (
$intact_file,
);
 print Dumper ( $data );

#--------------------------- intact2onto ---------------------------------------
$result = $intact->intact2onto (
$onto,
$data,
$up_map
);
ok ( keys %{$result}  == 2 ); #19 # 2 proteins added, now all the 4 participants included
print_obo ( $onto, "$data_dir/test.2.obo" ) if $verbose;	

# ----------------------------- intact2rdf -----------------------------------------------------

my $ttl_path = "$data_dir/intact.test.ttl";
ok ( $intact->intact2ttl ( $data, $ttl_path, ) ); #20

