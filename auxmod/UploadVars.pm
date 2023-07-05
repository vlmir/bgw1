package auxmod::UploadVars;
# TODO used only in UploadSubs - $prefix and $sparql_prefixes -> UploadSubs

use Carp;
use strict;
use warnings;
use Exporter;
$Carp::Verbose = 1;

########################################################################
#
# Import of project specific variables
#
#~ use  auxmod::BgwVars; # not used currently
#~ use auxmod::ApoVars;
########################################################################

our @ISA = qw(Exporter);
our @EXPORT = qw (
$base 
$prefix 
$sparql_prefixes 
$suffix

);

################################################################################################

our $base = 'http://www.semantic-systems-biology.org';
our $prefix = ''; # used by Virtuoso to resolve relative URIs, no trailing '#' or '/'
our $sparql_prefixes = <<HEREDOC;
BASE   <$base/>
PREFIX obo:<http://purl.obolibrary.org/obo/>
HEREDOC
## Set a suffix to use - important !!!
#~ our $suffix = '-if';
our $suffix = '-inf';

1;
