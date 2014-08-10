# Simple RSS Creator

Simple perl script which generates RSS feeds from given website(s) according to options defined in the configuration file.

## Configuration file
Every feed has its own section in configuration file which consists of:
* _title_ - Title of feed
* _link_ - Link from which feed will be created
* _description_ - Feed description
* _file_ - Location and filename of created feed
* _itemregex_ - Regular expression of one feed item. Regex must have at least three matching groups (for title, link and description).
* _maxitems_ - Max items for given feed (items above this limit will be ignored)
* _titleidx_ - Index of title matching group in _itemregex_ (counted from zero)
* _linkidx_ - Index of link matching group in _itemregex_ 
* _descidx_ - Index of description matching group in _itemregex_ 

The configuration file uses JSON format and allows you to have multiple feeds in one config file.

## Requirements:
- XML::RSS
- JSON
- URI
- DateTime
- Getopt::Std