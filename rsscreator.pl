#!/bin/perl -w

use strict;
use warnings;
use Switch;
use LWP::Simple;
use XML::RSS;
use JSON qw/decode_json/;
use URI qw/new_abs/;
use DateTime;
use Getopt::Std;
use DBI;

$Getopt::Std::STANDARD_HELP_VERSION = 1;
my $localTZ = DateTime::TimeZone->new(name => 'local');
my @feeds;
my %opts = ();

getopts('tc:r:u:l:', \%opts);

#TODO: -d param for description size

if($opts{"c"}) {
	parseConfig($opts{"c"});
	createFeeds();
} elsif($opts{"t"} and $opts{"r"} and $opts{"u"}) {
	testRegex($opts{"r"}, $opts{"u"}, (defined $opts{"l"} ? $opts{"l"} : 5));
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
	open(FILE, $_[0]) or die "[ERROR] Unable to open config file " . $_[0] . "\n";
	my $json = <FILE>;
	close FILE;

	my $decoded = decode_json($json);
	@feeds = @{$decoded->{"feeds"}};

	# Basic config file check
	foreach my $item (@feeds) {
		if($item->{"maxitems"} < 1) {
			die "[ERROR] Feed: \"" . $item->{"title"} . "\": maxitems is out of range (is: " . $item->{"maxitems"} . " | should be: > 0)\n";
		}
	}
}

# Creates feeds using info saved in @feeds
sub createFeeds {
	foreach my $item (@feeds) {
		print "Processing feed: " . $item->{"title"} . "\n";

		switch(lc $item->{"type"}) {
			case lc "article"	{ typeArticle($item); }
			case lc "diff"		{ typeDiff($item); }
			else { print STDERR "[ERROR] Feed: \"" . $item->{"title"} . "\": Unknown feed type \"" . $item->{"type"} . "\", skipping...\n"; }
		}
	}
}

# Used for feeds with defined type "article" in the config file.
# Parses given website and creates an item in RSS for each
# parsed article.
# Params:
# - $_[0] = The feed item from configuration file
sub typeArticle {
	my $item = $_[0];

	# Gets content of given website.
	my $content = get($item->{"link"});
	if(not defined $content) {
		print STDERR "[ERROR] Feed: \"" . $item->{"title"} . "\": Unable to open URL " . $item->{"link"} . ", skipping...\n"; 
		return;
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
			lastBuildDate => $dt->strftime("%a, %d %b %Y %H:%M:%S %z"));

	my @matches;
	my $limit = $item->{"maxitems"};

	# Escapes and uses regex from config file to parse $limit items from given URL's
	# content and saves them in two-dimensional array for easier access
	$item->{"itemregex"} =~ s/\//\\\//;
	push @matches, [$1, $2, $3] while $content =~ /$item->{"itemregex"}/gs and $limit-- > 0;

	$limit = $item->{"maxitems"};

	# Adds parsed items into new created RSS file
	foreach my $m (@matches) {
		# Compares processed item's title with the newest item's title from old
		# RSS file. In case of match breaks from the loop.
		last if(defined $lasttitle and $lasttitle eq @$m[$item->{"titleidx"}]);

		$rss->add_item(	
			title => @$m[$item->{"titleidx"}], 
			link => ($item->{"linkidx"} < 0) ? $item->{"link"} : ($base . @$m[$item->{"linkidx"}]), 
			description => ($item->{"descidx"} < 0) ? "" : @$m[$item->{"descidx"}],
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

# Used for feeds with defined type "diff" in the config file.
# Gets website's content and makes a diff with cached version.
# If the feed or the cached version doesn't exist, it creates
# the RSS file with initial item and makes initial content cache.
# Params:
# - $_[0] = The feed item from configuration file
sub typeDiff {
	my $item = $_[0];

	# Gets content of given website.
	my $content = get($item->{"link"});
	if(not defined $content) {
		print STDERR "[ERROR] Feed: \"" . $item->{"title"} . "\": Unable to open URL " . $item->{"link"} . ". Skipping...\n"; 
		return;
	}

	# If regex is defined or non-empty, apply it to the website's content
	if(defined $item->{"itemregex"} and $item->{"itemregex"} ne "") {
		$item->{"itemregex"} =~ s/\//\\\//;
		my (@m) = $content =~ /$item->{"itemregex"}/s;
		$content = join('', @m);
	}

	my $dt = DateTime->now(time_zone => $localTZ);
	my $rss = XML::RSS->new(version => '2.0');
	my $dbh = DBI->connect("dbi:SQLite:dbname=rsscreator.db", "", "", {RaiseError => 1}) or die $DBI::errstr;
	$dbh->do("CREATE TABLE IF NOT EXISTS data('url' VARCHAR PRIMARY KEY NOT NULL, 'content' VARCHAR);");

	my $sth = $dbh->prepare("SELECT content FROM data WHERE url = ?");
	$sth->bind_param(1, $item->{"link"});
	$sth->execute();

	my ($data) = $sth->fetchrow_array();

	# If the RSS file and cached data exist, do a diff of them.
	# Otherwise create both with initial data.
	if(-e $item->{"file"} and defined $data) {
		if($content ne $data) {
			my $diff = getDiff($data, $content);
			$rss->parsefile($item->{"file"});

			# Removes the oldest items from the RSS
			while(@{$rss->{"items"}} >= $item->{"maxitems"}) {
				pop(@{$rss->{'items'}})
			}

			$rss->add_item(
				title => "Content has changed! (" . $item->{"title"} . ")", 
				link => $item->{"link"}, 
				description => $diff,
				mode => "insert",
				pubDate => $dt->strftime("%a, %d %b %Y %H:%M:%S %z"));
			
			$rss->save($item->{"file"});
			$sth->finish();
			$sth = $dbh->prepare("REPLACE INTO data VALUES(?, ?);");
			$sth->bind_param(1, $item->{"link"});
			$sth->bind_param(2, $content);
			$sth->execute();
		}
	} else {
		$rss->channel(
				title => $item->{"title"},
				link => $item->{"link"},
				description => $item->{"description"},
				lastBuildDate => $dt->strftime("%a, %d %b %Y %H:%M:%S %z"));

		$rss->add_item(
			title => "Feed has been sucessfully created!", 
			link => $item->{"link"}, 
			description => "",
			pubDate => $dt->strftime("%a, %d %b %Y %H:%M:%S %z"));

		$rss->save($item->{"file"});
		$sth->finish();
		$sth = $dbh->prepare("REPLACE INTO data VALUES(?, ?);");
		$sth->bind_param(1, $item->{"link"});
		$sth->bind_param(2, $content);
		$sth->execute();
	} 

	$sth->finish();
	$dbh->disconnect();
}

# Gets changed content
# Params:
# - $_[0] = Old content
# - $_[1] = New content
sub getDiff {
	my @old = split('\n', $_[0]);
	my @new = split('\n', $_[1]);
	my %diff1;

	@diff1{@new} = @new;
	delete @diff1{@old};

	return join('', reverse (keys %diff1));
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
		die "[ERROR] Unable to open URL " . $url . "\n";
	}

	$regex =~ s/\//\\\//;
	while($content =~ /$regex/gs and $limit-- > 0) {
		print "\$0: $1\n\$1: $2\n\$2: " . substr($3, 0, 50) . "\n" . ('-' x 30) . "\n";
	}
}