#!/bin/perl -w

use strict;
use warnings;
use LWP::Simple;
use XML::RSS;
use JSON qw/decode_json/;
use URI qw/new_abs/;
use DateTime;

my @feeds;

if(@ARGV and $#ARGV + 1 != 1) {
	print STDERR "Usage: rsscreator.pl config.json\n";
	exit 1;
}

parseConfig();
createFeeds();

sub parseConfig {
	local $/;
	open(FILE, $ARGV[0]) or die "Unable to open config file " . $ARGV[0] . "\n";
	my $json = <FILE>;
	close FILE;

	my $decoded = decode_json($json);
	@feeds = @{ $decoded->{"feeds"} };
}

sub createFeeds {
	foreach my $item (@feeds) {
		print "Processing feed: " . $item->{"title"} . "\n";

		my $content = get($item->{"link"});
		if (not defined $content) {
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