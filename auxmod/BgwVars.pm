package auxmod::BgwVars;

## Note: Currently not used

use Carp;
use strict;
use warnings;
use Exporter;
$Carp::Verbose = 1;
our @ISA = qw ( Exporter );
# TODO clean up the list
our @EXPORT = qw (
	$project_name
	$lc_proj_name
	@closures
	@dirs
	@files
	@graphs
	
);
#
###################################################################
#
#		 the variables below do not normally need adjustment
#
###################################################################
our $project_name = 'Biogateway';
our $lc_proj_name = lc ( $project_name );

# TODO update the vars below
# eliminate arrays
# use data_dir and src_dir
### Directories
my $data_dir        = "/norstore/project/ssb/workspace/data";
my $project_dir = "$data_dir/$lc_proj_name";
my $obo_data_dir    = "$project_dir/obo_in_rdf";
my $owl_data_dir    = "$data_dir/download/owl";
my $ncbi_data_dir   = "$project_dir/ncbi_in_rdf";
my $uniprot_data_dir = "$project_dir/uniprot_in_rdf";
my $goa_data_dir   = "$project_dir/goa_in_rdf";
our @dirs = (
	$data_dir,
	$project_dir,
	$obo_data_dir,
	$owl_data_dir,
	$ncbi_data_dir,
	$uniprot_data_dir,
	$goa_data_dir
);

# Files
my $go_file   =  "$obo_data_dir/gene_ontology_edit.rdf";
my $ncbi_file   =  "$ncbi_data_dir/taxonomy.rdf";
my $sprot_file  = "$uniprot_data_dir/uniprot_sprot.rdf";
my $trembl_file = "$uniprot_data_dir/uniprot_trembl.rdf";

our @files = (
	$go_file,
	$ncbi_file,
	$sprot_file,
	$trembl_file
);

################################################################################################

# TODO all vars below should be eliminated

my $obo_closures = 1; # 0 - no closures
my $owl_closures = 1; # 0 - no closures
my $ncbi_closures = 1; # 0 - no closures
my $goa_closures = 1; # 0 - no closures
our @closures = (
	$obo_closures,
	$owl_closures,
	$ncbi_closures,
	$goa_closures
);

### Graphs -  not used anymore
#~ my $ssb_graph = 'SSB';
my $bgw_graph = 'BGW';
my $obo_graph = 'OBO';
my $owl_graph = 'OWL';
my $ncbitx_graph = 'ncbi';
my $sprot_graph = 'swissprot';
my $trembl_graph = 'trembl';
my $goa_graph = 'GOA';
my $go_graph = 'gene_ontology_edit';
my $metaonto_graph = 'metaonto';
our @graphs = ( 
	$bgw_graph,
	$obo_graph,
	$owl_graph,
	$ncbitx_graph,
	$sprot_graph,
	$trembl_graph,
	$goa_graph,
	$go_graph,
	$metaonto_graph
);

1;
