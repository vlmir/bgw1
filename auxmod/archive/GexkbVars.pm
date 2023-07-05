
package auxmod::GexkbVars;

use Carp;
use strict;
use warnings;
use Exporter;
our @ISA = qw(Exporter);

my $verbose = 1;
if ( $verbose ) {
	$Carp::Verbose = 1;
	use Data::Dumper;
};

our @EXPORT = qw(
@sources
@slaves
$master
$master_id
$PRJ
$PRJNM
$ma
%taxon_labels
%organisms
%roots2adopters
$blast_file
$blast_db
);

########################################################################

# Adjust accordingly !!!
our $PRJ = 'GeXO';

########################################################################
our ( $PRJNM, %roots2adopters, %adopters, %adopter_ids, $ma );
$ma = 'p';
if ( $PRJ eq 'GeXO' ) {
	$PRJNM = 'Gene Expression Ontology';
	%roots2adopters = ( ## 'gene expression',
		'GO:0010467' => [ $PRJ.':0000001', 'gene expression process', ]
	);
# 	# sub-root id => adopter name
# 	%adopters = (
# 		'GO:0010467' => 'gene expression process',
# 	);
# 	# adopter name => adopter id
# 	%adopter_ids = (
# 		'gene expression process' => $PRJ.':0000001'
# 	);
}
elsif ( $PRJ eq 'ReXO' ) {
	$PRJNM = 'Regulation of Gene Expression Ontology';
	%roots2adopters = ( ## 'regulation of gene expression'
		'GO:0010468' => [ $PRJ.':0000001', 'regulation of gene expression process']
	);
}
elsif ( $PRJ eq 'ReTO' ) {
	$PRJNM = 'Regulation of Transcription Ontology';
	%roots2adopters = ( ## 'regulation of transcription, DNA-templated', 
		'GO:0006355' => [$PRJ.':0000001', 'process of regulation of DNA-templated transcription'],
	); ## Note: 'DNA-templated' refers to trnascription, rather then regulation !!
}

our $master_id = 'GO:0008150'; # biological_process
our $master = 'p';
our @slaves = ( 'c', 'f' );
# our @sources =  ( 'goa', 'intact', 'ortho', 'kegg', );
our @sources =  ( 'goa', 'intact', 'ortho', );

our %taxon_labels = ( ## used by apo.pl; 2015-12-8
	'9606' => 'human',
	'10090' => 'mouse',
	'10116' => 'rat',
);
our %organisms = ( ## used by  seed.pl and ortho.pl; 2015-12-8
	'9606' => [ 'Homo sapiens', 'An organism of the taxonomic rank Homo sapiens'],
	'10090' => [ 'Mus musculus', 'An organism of the taxonomic rank Mus musculus'],
	'10116' => [ 'Rattus Norvegicus', 'An organism of the taxonomic rank Rattus Norvegicus'],
);
# 
# our $ncbi_ids = { ## used for KEGG - dated
# 	'HSA' => '9606',
# 	'MMU' => '10090',
# 	'RNO' => '10116'
# };
# 
# our %genes_files = ( ## not used
# 	'9606' => 'h.sapiens',
# 	'10090' => 'm.musculus',
# 	'10116' => 'r.norvegicus'
# );

our $blast_file = 'gexkb.blast';
our $blast_db = 'gexkb';

1;
