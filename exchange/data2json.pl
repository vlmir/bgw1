#! /usr/bin/perl
##  script should be run from the log dir: ??
BEGIN {
	my @homes = (
	'/home/mironov/git/usr/bgw', 
	);
	push @INC, @homes;
}
use strict;
use warnings;
use Carp;
use parsers::Intact;
use parsers::Goa;
use auxmod::SharedSubs qw( 
open_write
extract_map
read_map
benchmark
__date
);
use auxmod::SharedVars qw(
$gpi_txn_lst
);
my $verbose = 1;
if ( $verbose ) {
	$Carp::Verbose = 1;
	use Data::Dumper;
};

my (
$data_dir,
$bgw_dir,
$label,
) = @ARGV;

my (
$start_time,
$msg,
);

my @taxa = keys %{extract_map ($gpi_txn_lst, 0) };
my $maps_dir = "$bgw_dir/gnid2upac/";
unless ( -e $maps_dir ) { mkdir $maps_dir or croak "failed to create dir '$maps_dir': $!"; }
my $parser;
$parser = parsers::Intact->new ( ) if $label eq 'intact';
$parser = parsers::Goa->new ( ) if $label eq 'goa';
print "STARTED $0 @ARGV ", __date, "\n"; $start_time = time;
my $input_dir = "$data_dir/$label";
my $out_dir = "$bgw_dir/$label";
unless ( -e $out_dir ) { mkdir $out_dir or croak "failed to create dir '$out_dir': $!"; }
my $ext;
$ext = '2rp' if $label eq 'intact';
$ext = 'gpa' if $label eq 'goa';
my $count = 0;
foreach my $txn ( @taxa ) {
	my $in_file_path = "$input_dir/$txn.$ext";
	my $out_file_path = "$out_dir/$txn.json";
	next unless -e $in_file_path;
	next if -z $in_file_path; # an empty file
	my $data = $parser-> parse ( $in_file_path, $out_file_path ); # no map - the input pre-filtered by refprot ACs
	next unless $data;
	$count++;
}
print "count: $count\n";
$msg = "DONE $0 @ARGV"; benchmark ( $start_time, $msg, 1 );

