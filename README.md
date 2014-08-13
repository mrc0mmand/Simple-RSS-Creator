# Simple RSS Creator

Simple perl script which generates RSS feeds from given website(s) according to options defined in the configuration file.

## Usage

`rsscreator.pl -c config.file` 

If you want to test your regex without writing a config file, you can use script's test feature:

`rsscreator.pl -t -r "[y|Y]our(.*?)rege(x|xp)" -u https://url.for/rss/feed`

Optionally you can specify number of items you want to parse with `-l xx`

## Configuration file
Every feed has its own section in configuration file which consists of:

* **type** - Type of RSS creation mode
  * **article** - A RSS item is created for each website article parsed by **itemregex**. Used for blogs, news sites, etc.
  * **diff** - A RSS item is created for each change of website content. The **itemregex** can be used for specifying the area from which the diff is created.
* **title** - Title of feed
* **link** - Link from which feed will be created
* **description** - Feed description
* **file** - Location and filename of created feed
* **itemregex** - Usage of **itemregex** depends on specified feed **type**
  * **article** - [Required] Regular expression of one feed item. Regex must have at least three matching groups (for title, link and description).
  * **diff** - [Optional] If not empty, given regex is used to specify the area for creating the final diff.
* **maxitems** - Max items for given feed (items above this limit will be ignored)

Options below are required only for **article** type:

* **titleidx** - Index of title matching group in **itemregex** (counted from zero)
* **linkidx** - Index of link matching group in **itemregex** 
* **descidx** - Index of description matching group in **itemregex** 

The configuration file uses JSON format and allows you to have multiple feeds in one config file.

## Requirements:
- Switch
- XML::RSS
- JSON
- URI
- DateTime
- Getopt::Std
- DBI