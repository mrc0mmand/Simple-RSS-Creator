#!/bin/perl -w

use strict;
use warnings;
use LWP::Simple;
use XML::RSS;
use JSON qw/decode_json/;
use URI qw/new_abs/;
use DateTime;
use Getopt::Std;

$Getopt::Std::STANDARD_HELP_VERSION = 1;
my @feeds;
my %opts = ();

getopts('tc:r:u:m:', \%opts);

if($opts{"c"}) {
	parseConfig($opts{"c"});
	createFeeds();
} elsif($opts{"t"} and $opts{"r"} and $opts{"u"}) {
	testRegex($opts{"r"}, $opts{"u"}, ($opts{"m"} ? $opts{"t"} : 5));
} else {
	HELP_MESSAGE();
}

sub HELP_MESSAGE {
	print "Usage:\n".
			"  -c <config>\tReads feed options from config file\n" .
			"  -t\t\tTests given regex by -r against URL given by -u\n" .
			"  -r <regex>\tSpecifies regular expression for testing with -t option\n" .
			"  -u <url>\tSpecifies URL address for testing with -t option\n" .
			"  -m <limit>\t[Optional] Specifies item limit printed by -t option (default: 5)\n";
}

sub VERSION_MESSAGE {
	print "Version 0.1";
}

sub parseConfig {
	local $/;
	open(FILE, $_[0]) or die "Unable to open config file " . $_[0] . "\n";
	my $json = <FILE>;
	close FILE;

	my $decoded = decode_json($json);
	@feeds = @{ $decoded->{"feeds"} };
}

sub createFeeds {
	foreach my $item (@feeds) {
		print "Processing feed: " . $item->{"title"} . "\n";

		my $content = get($item->{"link"});
		if(not defined $content) {
			print "Unable to open URL " . $item->{"link"} . "\n"; 
			next;
		}

		my $dt = DateTime->now();
		my $rss = XML::RSS->new(version => '2.0');
		my $base = URI->new_abs("/", $item->{"link"})->as_string();
		$base =~ s/\/$//;

		$rss->channel(
				title => $item->{"title"},
				link => $item->{"link"},
				description => $item->{"description"},
				lastBuildDate => $dt->strftime("%a, %d %b %Y %H:%M:%S %z")
			);

		my @matches;
		my $cnt = $item->{"maxitems"};

		$item->{"itemregex"} =~ s/\//\\\//;
		push @matches, [$1, $2, $3] while $content =~ /$item->{"itemregex"}/gs and $cnt-- > 0;

		for my $m (@matches) {
			$rss->add_item(	title => @$m[$item->{"titleidx"}], 
							link => ($base . @$m[$item->{"linkidx"}]), 
							permaLink => ($base . @$m[$item->{"linkidx"}]),
							description => @$m[$item->{"descidx"}]);
		}

		$rss->save($item->{"file"});
	}
}

sub testRegex {
	my($regex, $url, $max) = @_;

	my $content = get($url);
	if (not defined $content) {
		print "Unable to open URL " . $url . "\n";
		exit 1;
	}

	$regex =~ s/\//\\\//;
	while($content =~ /$regex/gs and $max-- > 0) {
		print "\$0: $1\n\$1: $2\n\$2: " . substr($3, 0, 50) . "\n" . ('-' x 30) . "\n";
	}
}