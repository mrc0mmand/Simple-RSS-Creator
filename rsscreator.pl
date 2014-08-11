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
my $localTZ = DateTime::TimeZone->new(name => 'local');
my @feeds;
my %opts = ();

getopts('tc:r:u:l:', \%opts);

if($opts{"c"}) {
	parseConfig($opts{"c"});
	createFeeds();
} elsif($opts{"t"} and $opts{"r"} and $opts{"u"}) {
	testRegex($opts{"r"}, $opts{"u"}, ($opts{"l"} ? $opts{"l"} : 5));
} else {
	HELP_MESSAGE();
}

sub HELP_MESSAGE {
	print "Usage:\n".
			"  -c <config>\tReads feed options from config file\n" .
			"  -t\t\tTests given regex by -r against URL given by -u\n" .
			"  -r <regex>\tSpecifies regular expression for testing with -t option\n" .
			"  -u <url>\tSpecifies URL address for testing with -t option\n" .
			"  -l <limit>\t[Optional] Specifies item limit printed by -t option (default: 5)\n";
}

sub VERSION_MESSAGE {
	print "Version 0.1\n";
}

# Parses configuration file and saves the feeds array
# from config into global array @feeds.
# Parameters: 
# - $_[0] = path to config file
sub parseConfig {
	local $/;
	open(FILE, $_[0]) or die "Unable to open config file " . $_[0] . "\n";
	my $json = <FILE>;
	close FILE;

	my $decoded = decode_json($json);
	@feeds = @{$decoded->{"feeds"}};
}

# Creates feeds using info saved in @feeds
sub createFeeds {
	foreach my $item (@feeds) {
		print "Processing feed: " . $item->{"title"} . "\n";

		# Gets content of given website.
		# In case of fail jumps to next feed in @feeds.
		my $content = get($item->{"link"});
		if(not defined $content) {
			print "Unable to open URL " . $item->{"link"} . "\n"; 
			next;
		}

		my $dt = DateTime->now(time_zone => $localTZ);
		my $rss = XML::RSS->new(version => '2.0');
		my $base = URI->new_abs("/", $item->{"link"})->as_string();
		my $oldrss;
		my $lasttitle;

		# Checks if old RSS file exists.
		# If so, then it loads title of the newest item to var $lasttitle.
		if(-e $item->{"file"}) {
			$oldrss = XML::RSS->new(version => '2.0');
			$oldrss->parsefile($item->{"file"});
			if(@{$oldrss->{"items"}}) {
				$lasttitle = @{$oldrss->{"items"}}[0]->{"title"};
			}
		}

		# Removes trailing slash from the base URL address
		$base =~ s/\/$//;

		# Adds channel info for new RSS file
		$rss->channel(
				title => $item->{"title"},
				link => $item->{"link"},
				description => $item->{"description"},
				lastBuildDate => $dt->strftime("%a, %d %b %Y %H:%M:%S %z")
			);

		my @matches;
		my $limit = $item->{"maxitems"};

		# Escapes and uses regex from config file to parse $limit items from given URL's
		# content and saves them in two-dimensional array for easier access
		$item->{"itemregex"} =~ s/\//\\\//;
		push @matches, [$1, $2, $3] while $content =~ /$item->{"itemregex"}/gs and $limit-- > 0;

		$limit = $item->{"maxitems"};

		# Adds parsed items into new created RSS file
		for my $m (@matches) {
			# Compares processed item's title with the newest item's title from old
			# RSS file. In case of match breaks from the loop.
			last if(defined $lasttitle and $lasttitle eq @$m[$item->{"titleidx"}]);

			$rss->add_item(	title => @$m[$item->{"titleidx"}], 
							link => ($base . @$m[$item->{"linkidx"}]), 
							permaLink => ($base . @$m[$item->{"linkidx"}]),
							description => @$m[$item->{"descidx"}],
							pubDate => $dt->strftime("%a, %d %b %Y %H:%M:%S %z"));
			$limit--;
		}

		# Adds items from the old RSS file at the end of the new one
		# and purges items above the remaining given limit.
		if(defined $oldrss and $limit > 0) {
			foreach my $item (@{$oldrss->{"items"}}) {
				last if ($limit-- == 0);
				push @{$rss->{"items"}}, $item;
			}
		}

		$rss->save($item->{"file"});
	}
}

# Tests given regex against given URL's content.
# In case of match prints $limit matches to standard output.
# Parameters:
# - $_[0] = Regular expression
# - $_[1] = URL address
# - $_[2] = Limit of results
sub testRegex {
	my($regex, $url, $limit) = @_;

	my $content = get($url);
	if (not defined $content) {
		print "Unable to open URL " . $url . "\n";
		exit 1;
	}

	$regex =~ s/\//\\\//;
	while($content =~ /$regex/gs and $limit-- > 0) {
		print "\$0: $1\n\$1: $2\n\$2: " . substr($3, 0, 50) . "\n" . ('-' x 30) . "\n";
	}
}