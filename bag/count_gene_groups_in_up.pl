use strict;
use Carp;
use warnings;
{
	my  $uniprot_file  = shift;
	open my $FH, '<', $uniprot_file;
	local $/ = "\n//\n";
	while (<$FH>) {
#		my $count = s/^GN/^GN/xmsg;
		my $count = s/^DR\s\s\sGeneID/^DR\s\s\sGeneID/xmsg;
		/\AID\s+(\w+)/xms if $count > 1;
		print "$1: $count\n" if $count > 1;  
	}
	close $FH;
}
