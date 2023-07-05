BEGIN {
	#~ unshift @INC, '/norstore/user/mironov/workspace/onto-perl/ONTO-PERL-1.37/lib';
	unshift @INC, '/norstore/project/ssb/workspace/onto-perl/lib';
}
use Carp;
use strict;
use warnings;
$Carp::Verbose = 1;
use OBO::Util::Ontolome;
use OBO::XO::OBO_ID_Term_Map;
use OBO::Parser::OBOParser;
use Data::Dumper;

my $start = `date`;
chomp $start;
my $obo_parser = OBO::Parser::OBOParser->new();
my ( $dir, $obo_file ) = @ARGV;

my $onto =  $obo_parser->work ( "$dir/$obo_file" );
my  $depth = find_depth ( $onto, get_leaves ( $onto ));
my $end = `date`;
chomp $end;
print "$obo_file\t$depth\t$start\t$end\n";

sub get_leaves {
	my ( $onto ) = @_;
	my @all_terms = @{$onto->get_terms_sorted_by_id()};
	my @leaves = ();
	foreach my $term (@all_terms) {
		push @leaves, $term if ( @{$onto->get_child_terms ( $term )} == 0 ); 
	}
	return \@leaves;
}

sub find_depth {
	my ( $onto, $leaves ) = @_;	
	my $depth = 0;
	my @roots = @{$onto->get_root_terms ()};
	foreach my $root ( @roots ) {
		foreach my $leaf ( @{$leaves} ) {
			my @paths = $onto->get_paths_term1_term2 ( $leaf->id (), $root->id () );
			foreach my $path ( @paths ) {
				my @rels = @{$path};
				my $length = @rels;
				$depth = $length if ( $length > $depth );				
			}
		}		
	}
	return $depth;
}
