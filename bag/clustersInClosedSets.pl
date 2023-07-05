use Carp;
use strict;
use warnings;
use Data::Dumper;


#~ my $field = shift;
my $kegg_file = shift;

my %counts = ();
my %clusters = ();
my %closed_sets;
open my $FH, '<', $kegg_file;
while ( <$FH> ) {
	next if substr ( $_, 0, 1) eq "\n";
	next if substr ( $_, 0, 1) eq "#";
	chomp;
	my ( $prot_id, $kegg_id ) = split ( "\t" );
	my ( $prot_ns, $ac ) = split ':', $prot_id;
	my ( $kegg_ns, $cluster ) = split ':', $kegg_id if $kegg_id;
	$clusters{$ac} = $cluster if $cluster;
}
while ( <> ) {
	next if substr ( $_, 0, 1) eq '#';
	next if substr ( $_, 0, 1) eq "\n";
	chomp;
	my @fields = split ( "\t" );
	$closed_sets{$fields[0]}{'set'} = $fields[1];
	$closed_sets{$fields[0]}{'size'} = $fields[2];
	$closed_sets{$fields[0]}{'freq'} = $fields[3];
	my @acs = split ' ', $fields[4];
	my %cluster_count;
	foreach my $ac ( @acs ) {
		$cluster_count{$clusters{$ac}}++ if $clusters{$ac};
	}
	$closed_sets{$fields[0]}{'clusters'} = \%cluster_count;

}
map { my @clust_ids = keys %{$closed_sets{$_}{'clusters'}}; print $_."\t".$closed_sets{$_}{'size'}."\t".$closed_sets{$_}{'freq'}."\t".@clust_ids."\t@clust_ids\n" } keys %closed_sets;

