use Carp;
use strict;
use warnings;
use Data::Dumper;


#~ my $field = shift;
my $kegg_file = shift;

my %counts = ();
my %keggClusters = ();
my %semaClusters; # semantic cluster id => { KEGG cluster id => count }
open my $FH, '<', $kegg_file;
while ( <$FH> ) {
	next if substr ( $_, 0, 1) eq "\n";
	next if substr ( $_, 0, 1) eq "#";
	chomp;
	my ( $prot_id, $kegg_id ) = split ( "\t" );
	my ( $prot_ns, $ac ) = split ':', $prot_id;
	my ( $kegg_ns, $cluster ) = split ':', $kegg_id if $kegg_id;
	$keggClusters{$ac} = $cluster if $cluster;
}
while ( <> ) {
	next if substr ( $_, 0, 1) eq '#';
	next if substr ( $_, 0, 1) eq "\n";
	chomp;
	my @fields = split ( "\t" );
	#~ $semaClusters{$fields[0]}{'set'} = $fields[2];
	#~ $semaClusters{$fields[0]}{'size'} = $fields[2];
	#~ $semaClusters{$fields[0]}{'freq'} = $fields[3];
	#~ my @acs = split ' ', $fields[4];
	#~ my %cluster_count;
	#~ foreach my $ac ( @acs ) {
		#~ $cluster_count{$keggClusters{$ac}}++ if $keggClusters{$ac};
	#~ }
	#~ $semaClusters{$fields[0]}{'keggClusters'} = \%cluster_count;
	
	$semaClusters{$fields[0]}{'kegg'}{$keggClusters{$fields[1]}}++ if $keggClusters{$fields[1]};
	

}
#~ map { my @clust_ids = keys %{$semaClusters{$_}{'keggClusters'}}; print $_."\t".$semaClusters{$_}{'size'}."\t".$semaClusters{$_}{'freq'}."\t".@clust_ids."\t@clust_ids\n" } keys %semaClusters;
map { my @clust_ids = keys %{$semaClusters{$_}{'kegg'}}; print $_."\t".@clust_ids."\t@clust_ids\n" } keys %semaClusters; # semantic cluster ID
