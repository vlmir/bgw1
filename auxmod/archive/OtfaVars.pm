
package OtfaVars;

use Carp;
use strict;
use warnings;
use Exporter;
our @ISA = qw(Exporter);
$Carp::Verbose = 1;


our @EXPORT = qw(
@sources
@slaves
$master
$master_id
$project_name
$proj_long_name

%taxon_labels
%organisms
%branch_names
%adopters
%adopter_ids
$ncbi_ids
%genes_files

$blast_db
);

our $project_name = 'OTFa';
our $proj_long_name = 'Ontology of Transcription Factors';
our %branch_names = (
	'GO:0003700' => 'sequence-specific DNA binding transcription factor activity'
);
# sub-root id => adopter name
our %adopters = (
	'GO:0003700' => 'transcription factor function'
);
# adopter name => adopter id
our %adopter_ids = (
	'transcription factor function'=> $project_name.':0000001'
);

our $master_id = 'GO:0003674'; # molecular_function
our $master = 'f';
our @slaves = ( 'c', 'p' );
our @sources =  ( 'goa', 'intact', 'ortho', 'kegg', );
our %taxon_labels = (
	'9606' => 'human',
	'10090' => 'mouse',
	'10116' => 'rat',
);
our %organisms = (
	'9606' => [ 'Homo sapiens', 'An organism of the taxonomic rank Homo sapiens'],
	'10090' => [ 'Mus musculus', 'An organism of the taxonomic rank Mus musculus'],
	'10116' => [ 'Rattus Norvegicus', 'An organism of the taxonomic rank Rattus Norvegicus'],
);
# used for KEGG
our $ncbi_ids = {
	'HSA' => '9606',
	'MMU' => '10090',
	'RNO' => '10116'
};
our %genes_files = (
	'9606' => 'h.sapiens',
	'10090' => 'm.musculus',
	'10116' => 'r.norvegicus'
);

#~ our $blast_file = 'gexkb.blast';
our $blast_db = 'gexkb';

1;
