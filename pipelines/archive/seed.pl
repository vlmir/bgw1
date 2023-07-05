###################### ! Change before running ! ###############################
# OBOParser.pm
#  - line 235: my $r_db_acc     = qr/\s+(\w+:\S+)/o; # vlmir
################################################################################

# TODO use go-simple iso go-basic ?
BEGIN {
# 	unshift @INC, '/norstore/user/mironov/git/bin/onto-perl/lib';
	push @INC, '/datamap/home_mironov/git/scripts', '/norstore_osl/home/mironov/git/scripts';
}

use Carp;
use strict;
use warnings;

my $verbose = 1;
if ( $verbose ) {
	$Carp::Verbose = 1;
	use Data::Dumper;
};
use IO::Handle;
*STDOUT-> autoflush();

use OBO::Util::Ontolome;
use OBO::Parser::OBOParser;
use auxmod::SharedSubs qw( 
open_read
open_write
print_obo 
read_map 
print_counts 
benchmark 
);

use auxmod::SharedVars qw( 
$download_dir
$projects_dir
$workspace_dir
%organisms
);
#-------------------------- project variables ----------------------------------
# change appropriately
# must be the same as in apo.pl
use auxmod::CcoVars; 
# use auxmod::GexkbVars; 
#--------------------------- global variablel ----------------------------------
my $prj = lc $PRJ; # acronym
my $prjnm = lc $PRJNM; # full name
my @aspects = ( 'P', 'F', 'C' );
my $MA = shift @aspects; # master|major aspect to filter by
my $ma_id = $go_roots{$MA};
my $ma = lc $MA; # now imported from project specific Vars

my %go_roots = (
'P' => 'GO:0008150',
'C' => 'GO:0005575',
'F' => 'GO:0003674',
);

# Defs without xrefs for descriptions
# ('name', 'parent_id'; 'definition')
## TODO make use of %prnts !!!
our %ulo_terms = (
	'SIO:000000' => [ 'entity', 'SIO:000000', 'An entity is either a type that has zero or more physical manifestations or is an individual that exists in spacetime.' ],
	# top level
	'SIO:000003' => [ 'physical entity', 'SIO:000000', 'A physical entity is an entity that is spatio-temporally located (is or occupies some part of spacetime) and only has physical entities as parts.' ],
	'SIO:000260' => [ 'abstract entity', 'SIO:000000', 'An abstract entity is an entity that exhibits zero, one or more physical manifestations.' ],
	## high level
	'SIO:000002' => [ 'processual entity', 'SIO:000003', 'A processual entity is a physical entity that exists soley in time (occupies some part or parts of time), only has processual parts, and  necessarily involves some non-processual physical entity as a participant.' ],
	'SIO:000004' => [ 'material entity', 'SIO:000003', 'A material entity is a physical entity that is spatially extended, exists as a whole at any point in time and has mass.' ],
	'SIO:000614' => [ 'attribute', 'SIO:000260', 'An attribute is an abstract entity that describes some aspect of an entity.' ],
	###
	'SIO:000006' => [ 'process', 'SIO:000002', 'A process is a processual entity that is a maximally connected spatiotemporal whole, has a temporal start and end.' ],
	'SIO:010004' => [ 'chemical entity', 'SIO:000004', 'A chemical entity is a material entity that pertains to chemistry.' ],
	'SIO:010046' => [ 'biological entity', 'SIO:000004', 'a biological entity is a heterogeneous substance that contains genomic material or is the product of a biological process.' ],
	'SIO:000340' => [ 'realizable entity', 'SIO:000614', 'A realizable entity is an attribute that is exhibited under some condition and is realized in some process.' ],
	####
	'SIO:011125' => [ 'molecule', 'SIO:010004', 'A molecule is the mereological maximal sum of a collection of covalently bonded atoms.' ],
	'SIO:010441' => [ 'submolecule', 'SIO:010004', 'A submolecule is a mereological sum of a collection of covalently bonded atoms.', 'SIO:011125' ],
	'SIO:000112' => [ 'capability', 'SIO:000340', 'A capability is a realizable entity whose basis lies in one or more parts or qualities and reflects possility of an entity to act in a specified way under certain conditions or in response to a certain stimulus (trigger).' ],
	'SIO:010001' => [ 'cell', 'SIO:010046', 'a cell is a biological entity that is contained by a plasma membrane.', 'SIO:010000' ],
	##### the extra ID after the description is a 'part_of' parent
	'SIO:010074' => [ 'amino acid residue', 'SIO:010441', 'an amino acid residue is a part of a molecule that is derived from an amino acid molecule.', 'SIO:010043' ],
	'SIO:000017' => [ 'function', 'SIO:000112', 'A function is a capability that simultaneously satisfies some agentive design or natural selection.' ],
	'SIO:000014' => [ 'disposition', 'SIO:000112', 'A disposition is the tendency of a capability to be exhibited under certain conditions or in response to a certain stimulus (trigger)' ],
	### interface
	'MI:0190' => [ 'interaction type', 'SIO:000006', 'Connection between molecules.' ],
# 	the extra ID after the description is a 'part_of' parent
	'GO:0005575' => [ 'cellular component', 'SIO:010046', 'The part of a cell or its extracellular environment in which a gene product is located. A gene product may be located in one or more parts of a cell and its location may be as specific as a particular macromolecular complex, that is, a stable, persistent association of macromolecules that function together.', 'SIO:010001' ],
	'GO:0008150' => [ 'biological process', 'SIO:000006', 'Biological entities that unfold themselves in successive temporal phases.' ],
	'GO:0003674' => [ 'molecular function', 'SIO:000017', 'Elemental activities, such as catalysis or binding, describing the actions of a gene product at the molecular level. A given gene product may exhibit one or more molecular functions.' ],
	### parents
	'SIO:010043' => [ 'protein', 'SIO:011125', 'a protein is an organic polymer that is composed of one or more linear polymers of amino acids.' ],
	'PR:000025513' => [ 'modified amino-acid residue', 'SIO:010074', 'An amino-acid residue that is covalently modified by chemical alteration to the side chain or backbone atoms.' ],
# 	the extra ID after the description is a 'part_of' parent
	'SIO:010035' => [ 'gene', 'SIO:010441', 'A gene is part of a nucleic acid that contains all the necessary elements to encode a functional transcript.', 'GO:0005694' ],
# 	'OBI:0100026' => [ 'organism', 'SIO:010046', 'A material entity that is an individual living system, such as animal, plant, bacteria or virus, that is capable of replicating or reproducing, growth and maintenance in the right environment. An organism may be unicellular or made up, like humans, of many billions of cells divided into specialized tissues and organs.' ],
	'SIO:010000' => [ 'organism', 'SIO:010046', 'a biological organisn is a biological entity that consists of one or more cells and is capable of genomic replication (independently or not).' ],
	'OGMS:0000031' => [ 'disease', 'SIO:000014', 'A disposition (i) to undergo pathological processes that (ii) exists in an organism because of one or more disorders in that organism.' ],
);
my %xrefs4rels = (
'negatively_regulates' => 'RO:0002212',
'part_of' => 'BFO:0000050',
'positively_regulates' => 'RO:0002213',
'regulates', => 'RO:0002211',
);
### Directories
my $prj_dir = "$projects_dir/$prj";
my $dat_dir = "$prj_dir/data";
# my $ortho_dir = "$prj_dir/ortho";
my $maps_dir = "$prj_dir/maps";
my $log_dir = "$prj_dir/logs";
my $tmp_dir = "$prj_dir/tmp";
my $fin_dir = "$prj_dir/final";
my $upload_dir = "$prj_dir/upload";
my @dirs = ( 
$prj_dir, 
$dat_dir, 
$maps_dir, 
$log_dir, 
$tmp_dir, 
$fin_dir, 
$upload_dir 
);
### Files
my $go_path = "$download_dir/go/go-basic.obo";
my $mi_path = "$download_dir/obo/mi.obo";
my $mod_path = "$download_dir/obo/mod.obo";
my $seed_path = "$prj_dir/tmp/seed.obo";
my $go_map_path = "$prj_dir/maps/go-$ma.map";
my $fs = ':';
my $prj_ref = $prj.$fs.'team';
my %ontos;

############################### START! #########################################
my ( $start_time, $step_time, $cmd, $msg );
my $ome = OBO::Util::Ontolome->new();
my $obo_parser = OBO::Parser::OBOParser->new();

############################## seed ############################################
map { mkdir $_ or carp "Failed to create dir: $_" } @dirs unless (-e $prj_dir);
`ls -l $prj_dir`;

print 'CONSTRUCTING SEED ONTOLOGY ', `date`; $start_time = time;
my $ma_term; # necessary, don't know why; WARNING - there's been some mess with this  variable !!!
my (
	$go_core,
# 	$go_p,
# 	$go_f,
# 	$go_c,
	$int_types,
);
my $ulo = build_ulo ( \%ulo_terms ); # no relations yet;
$ontos{'ulo'} = $ulo;
print "> Getting core terms from $go_path\n"; $step_time = time;
my $go =  $obo_parser-> work($go_path);
## get branches from GO
my %branches;
my %go_map;
foreach my $sub_root_id (keys %roots2adopters) {
	my $root_term = $go-> get_term_by_id ($sub_root_id) || croak "The term for $sub_root_id is not defined";
	my $branch = $go-> get_subontology_from ($root_term); # by all relation types !!! TODO confirm
# 			my $branch = $go-> get_subontology_from ($root_term, $rel_types);
	# collecitng ids and names:
	my $terms = $branch->get_terms (); # array ref
	foreach my $term ( @{$terms} ) {
		$go_map{$term-> id ()} = $term-> name();
	}
	my $branch_name = $root_term-> name();
	my $adopter_id = $roots2adopters{$sub_root_id}->[0];
	my $adopter_name = $roots2adopters{$sub_root_id}->[1];
		my $adopter;
	if ($adopter = $branch-> get_term_by_id ($adopter_id)) {
		adopt_orphans($branch, $adopter, $root_term);
	}
	else {
		# adopter terms are created here
		$adopter = create_term ($adopter_id, $adopter_name, "Any process related to $branch_name.", $prj_ref) if $ma eq 'p';
		$adopter = create_term ($adopter_id, $adopter_name, "Any function related to $branch_name.", $prj_ref) if $ma eq 'f';
		$adopter = create_term ($adopter_id, $adopter_name, "Any component related to $branch_name.", $prj_ref) if $ma eq 'c';
		
		$branch->add_term($adopter);
		adopt_orphans ( $branch, $adopter, $root_term );
	}
	$branches{$sub_root_id} = $branch;
}
$go_core = $ome->union( values %branches );
# open my $GO_MAP, '>', "$go_map_path" || croak "The file '$go_map_path' couldn't be opened: $!";
my $GO_MAP = open_write ( $go_map_path );

foreach my $go_core_id ( sort keys %go_map ) {
	print $GO_MAP "$go_core_id\t$go_map{$go_core_id}\n";
}
close $GO_MAP;
$ontos{'core'} = $go_core;
$msg = "> Extracted core terms from $go_path"; benchmark ( $step_time, $msg );

foreach my $asp ( @aspects ) {
	print "> Getting terms for aspect $asp from: $go_path\n"; $step_time = time;
	my $root_term = $go-> get_term_by_id ( $go_roots{$asp} );
	my $sub =  $go-> get_subontology_from ($root_term, );
	$msg = "> Extracted terms for aspect $asp from: $go_path"; benchmark ( $step_time, $msg );
	$ontos{$asp} = $sub;
}

print "> Getting interaction types from $mi_path\n"; $step_time = time;
my $psi_mi = $obo_parser-> work ($mi_path);
my  $root_term = $psi_mi-> get_term_by_id ('MI:0190'); # interaction type
$int_types =  $psi_mi-> get_subontology_from ($root_term, ); # no names at this point
$ontos{'mi'} = $int_types;
$msg = "> Extracted interaction types from $mi_path"; benchmark ( $step_time, $msg );

# TODO
# print "> Getting PTM types from $mod_path\n"; $step_time = time;
# my $psi_mi = $obo_parser-> work ($mod_path);
# my  $root_term = $psi_mi-> get_term_by_id ('MI:0190'); # interaction type
# $int_types =  $psi_mi-> get_subontology_from ($root_term, ); # no names at this point
# $ontos{'mi'} = $int_types;
# $msg = "> Extracted PTM types from $mod_path"; benchmark ( $step_time, $msg );

print "> Merging branches\n"; $step_time = time;
my $seed = $ome->union( values %ontos ) or croak "failed to merge: $!";

$seed-> id ( $prj );
$seed->{REMARKS}->clear();
( my $default_namespace = $prjnm ) =~ tr/ /_/;
$seed-> default_namespace ( $default_namespace );
my $mi_root = $seed-> get_term_by_id ( 'MI:0190' ); # interaction type
$mi_root-> name ( 'molecular interaction' ); # changing 'interaction type' => 'molecular interaction'
$msg = "> Merged ontologies"; benchmark ( $step_time, $msg );

# adding xrefs to rel types
map {my $rltp = $seed-> get_relationship_type_by_id($_); 
	$rltp-> xref_set_as_string("[$xrefs4rels{$_}]")} keys %xrefs4rels;

print "> Creating relations\n"; $step_time = time;
foreach my $child_id ( keys %ulo_terms ) {
	my $parent_id = $ulo_terms{ $child_id }->[1];
	my $parent_term = $seed-> get_term_by_id( $parent_id) or croak "Term for '$parent_id' not found: $!";
	my $child_term = $seed-> get_term_by_id( $child_id ) or croak "Term for '$child_id' not found: $!";
	$seed-> create_rel ($child_term, 'is_a',   $parent_term);
	if ( $parent_id = $ulo_terms{ $child_id }->[3] ) {
		$parent_term = $seed-> get_term_by_id( $parent_id) or croak "Term for '$parent_id' not found: $!";
		$seed-> create_rel ($child_term, 'part_of',   $parent_term);
	}
}

# project specific relations
$ma_term = $seed-> get_term_by_id ( $ma_id ) or croak "Term for '$ma_id' not found: $!";
# foreach my $root_id ( keys %adopters ) { # subroot terms ids
foreach my $root_id ( keys %roots2adopters ) { # subroot terms ids
	my $root = $seed-> get_term_by_id ( $root_id ) or croak "Term for '$root_id' not found: $!";
# 	my $adopter_name = $adopters{$root_id};
	my $adopter_name = $roots2adopters{$root_id}->[1];
	my $adopter_id = $roots2adopters{$root_id}->[0];

# 	my $adopter_name = $branch_names{$root_id}.' process';
	my $adopter = $seed-> get_term_by_id( $adopter_id ) or croak "Term for '$adopter_id ! $adopter_name' not found: $!";
	$seed-> create_rel ( $root, 'is_a', $ma_term );
	$seed-> create_rel ( $adopter, 'is_a', $ma_term );
	$seed-> create_rel ( $adopter, 'part_of', $root );
}
$msg = "> Created relations"; benchmark ( $step_time, $msg );

$seed-> name($prj);
	$step_time = time;
	my $props = $seed-> get_relationship_types();
	foreach my $rltp ( @{$props} ) {
		my $name = $rltp-> name ();
		$name =~ tr/_/ /;
		$rltp-> name ( $name );
	}
	$msg = "> Trimmed names of TypeDefs in $seed_path"; benchmark ( $step_time, $msg, 0 );

print "> Saving seed ontology\n"; $step_time = time;
print_obo ($seed, $seed_path);
$msg = "> Saved $seed_path"; benchmark ( $step_time, $msg );
$msg = "DONE $0"; benchmark ( $start_time, $msg, 1 );

#################################### SUBS ######################################


sub build_ulo {
	# creates terms without relations
	my ( $ulo_terms ) = @_;
	my $onto = OBO::Core::Ontology->new();
	foreach my $id ( sort keys %{$ulo_terms} ) {
		my $term = create_term ( $id, $ulo_terms->{$id}[0], $ulo_terms->{$id}[2],  );
		$onto-> add_term ($term);
	}
	return $onto;
}

# Functin: makes terms without an outgoing 'is_a' children of Arg2
# Args:
# 1. OBO::Core::Ontology
# 2. OBO::Core::Term - the adopter
# 3. OBO::Core::Term - the root of Arg1
sub adopt_orphans {
	my ($onto, $adopter, $root ) = @_;
	my $root_id = $root->id ();
	my @terms = @{ $onto->get_terms("GO:") } or croak "cannot get GO terms: $!"; # get the GO terms
	foreach my $term (@terms) {
		next if ( $term->id () eq $root_id ); # TODO to be tested
		my @rels = @{$onto->get_relationships_by_source_term( $term )};
		my $link_found = 0;
		foreach my $r (@rels) {
			if ( $r->type() eq 'is_a' ) { # there is at least one parent
				$link_found = 1;
				last;
			}
		}
		if ( !$link_found ) {    # if there is no 'is_a'
			$onto-> create_rel( $term, 'is_a', $adopter ) or croak " cannot create relation: $!";
		}
	}
}

sub create_term {
	# $name and $def_id are optional
	# the OBOParser will throw a warning if no $name
	my (
	$id, 
	$name, 
	$def, 
	$xref # optional
	) = @_;
	$xref ||= '';
	my $term = OBO::Core::Term->new();
	$term-> id ($id);
	$term-> name ($name) if $name;
	$term->def_as_string( $def, "[$xref]" ) if $def;
	
	return $term;
}

