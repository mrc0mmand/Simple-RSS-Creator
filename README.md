# Simple RSS Creator

Simple perl script which generates RSS feeds from given website(s) according to options defined in the configuration file.

## Usage

`rsscreator.pl -c config.file` 

If you want to test your regex without writing a config file, you can use script's test feature:

`rsscreator.pl -t -r "[y|Y]our(.*?)rege(x|xp)" -u https://url.for/rss/feed`

Optionally, you can specify number of items you want to parse with `-l xx` and limit strings length by `-s xx`.

## Configuration file
Every feed has its own section in configuration file which consists of:

* **type** - Type of RSS creation mode.
  * **article** - A RSS item is created for each website article parsed by **itemregex**. Used for blogs, news sites, etc.
  * **diff** - A RSS item is created for each change of website content. The **arearegex** can be used for specifying the area from which the diff is created.
* **title** - Title of feed.
* **link** - Link from which feed will be created.
* **description** - Feed description.
* **file** - Location and filename of created feed.
* **itemregex** - Usage of **itemregex** depends on specified feed **type**:
  * **article** - [Required] Regular expression of one feed item. Regex must have at least one capturing group (for title). The appropriate indexes below must be set to negative values if their capturing groups are omitted in the regex.
  * **diff** - [Not used] Replaced with **arearegex**
* **arearegex** - Usage of **arearegex** depends on specified feed **type**:
  * **article** - [Optional] If defined/not empty, given regex is used to specify the area from which the items will be parsed by **itemregex**.
  * **diff** - [Optional] If defined/not empty, given regex is used to specify the area for creating the final diff.
* **maxitems** - Max items for given feed (items above this limit will be ignored).

Options below are required only for **article** type:

* **titleidx** - Index of title capturing group in **itemregex** (counted from zero).
* **linkidx** - Index of link capturing group in **itemregex**. If set to negative value, **link** will be used.
* **descidx** - Index of description capturing group in **itemregex**. If set to negative value, empty description will be used.

The configuration file uses JSON format and allows you to have multiple feeds in one config file.

## Requirements:
- Switch
- XML::RSS
- JSON
- URI
- DateTime
- Getopt::Std
- DBI
- DBD::SQLite
- Digest::MD5
- Encode