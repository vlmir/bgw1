
use Carp;
use strict;
use warnings;
$Carp::Verbose = 1;

my ( 
$base_url, # with a trailing slash
$url_file 
) = @_;

my @files = (
'Mut_zone1_l1_1.fq.bz2',
'Mut_zone1_l1_2.fq.bz2',
'Mut_zone2_l1_1.fq.bz2',
'Mut_zone2_l1_2.fq.bz2',
'Mut_zone3_l1_1.fq.bz2',
'Mut_zone3_l1_2.fq.bz2',
'WT_zone1_l1_1.fq.bz2',
'WT_zone1_l1_2.fq.bz2',
'WT_zone2_l1_1.fq.bz2',
'WT_zone2_l1_2.fq.bz2',
'WT_zone3_l1_1.fq.bz2',
'WT_zone3_l1_2.fq.bz2',
'md5.check',
'md5.txt',
'mock_l1_1.fq.bz2',
'mock_l1_2.fq.bz2',
);

my $location = 'ftp://cdts.genomics.hk/F13FTSEUHT1446_BENoogT_20140312/';
my $psw = 'BENoogT20140311';
my $usr = '20140311F13FTSEUHT1446';

foreach my $file ( @files ) {
  my $cmd = "nohup wget -b -o $file.log --user=$usr --password=$psw $location.$file";
  system ( $cmd );
}

# -c --continue to resume downloading a partially downloaded file !!!
my $cmd = "nohup wget -b -o $file.log --user=$usr --password=$psw -B $base_url -i $url_file";

