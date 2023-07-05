
package auxmod::CcoVars;

use Carp;
use strict;
use warnings;
use Exporter;
our @ISA = qw(Exporter);

$Carp::Verbose = 1;

our @EXPORT = qw(
$PRJ
$PRJNM
$ma
%taxon_labels
%roots2adopters
);
our $ma = 'p';
our $PRJ = 'CCO';
our $PRJNM = 'Cell Cycle Ontology';
our %roots2adopters = (
'GO:0007049' => ['GO:0022402', 'cell cycle process'], # 'cell cycle',
'GO:0051301' => [$PRJ.':0000001', 'cell division process'], # 'cell division',
'GO:0008283' => [$PRJ.':0000002', 'cell proliferation process'], # 'cell proliferation',
'GO:0006261' => [$PRJ.':0000003', 'DNA-dependent DNA replication process'], # 'DNA-dependent DNA replication', 
);
# 'GO:0006260' => 'DNA replication'

# TODO eliminate this hash, %roots2adopters suffices
# our %adopters = (
# 'GO:0007049' => 'cell cycle process',
# 'GO:0051301' => 'cell division process',
# 'GO:0008283' => 'cell proliferation process',
# 'GO:0006261' => 'DNA-dependent DNA replication process',
# );
# 'GO:0006260' => 'DNA replication process'
# 
# our %adopter_ids = (
# 'cell division process' => $PRJ.':0000001',
# 'cell proliferation process' => $PRJ.':0000002',
# 'DNA-dependent DNA replication process' => $PRJ.':0000003',
# );
# # 'DNA replication process' => $PRJ.':0000003',


our %taxon_labels = (
'3702' => 'arath',
'6239' => 'caeel',
'7227' => 'drome',
'9606' => 'human',
'10090' => 'mouse',
'284812' => 'schpo',
'559292' => 'yeast',
# '4896' => 'schpo',
# '4932' => 'yeast',
# '8355' => 'xenla',
'8364' => 'xentr',
);

1;
