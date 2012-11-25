TomDoc
======

TomDoc is documentation for humans.  Using a few simple rules and zero
special syntax you can produce great looking documentation for both humans
and machines.

Just follow these four easy steps:

1. Describe your method
2. Optionally list and describe its arguments
3. Optionally list some examples
4. Explain what your method returns

Like this:

    # Duplicate some text an arbitrary number of times.
    #
    # text  - The String to be duplicated.
    # count - The Integer number of times to duplicate the text.
    #
    # Examples
    #   multiplex('Tom', 4)
    #   # => 'TomTomTomTom'
    #
    # Returns the duplicated String.
    def multiplex(text, count)
      text * count
    end

See [the manual][man] or [the spec][spec] for a more in-depth
analysis.


tomdoc.rb
---------

This repository contains tomdoc.rb, a Ruby library for parsing
TomDoc and generating pretty documentation from it.


Installation
------------

    easy_install Pygments
    gem install tomdoc

tomdoc.rb has been tested with Ruby 1.8.7.


Usage
-----

    $ tomdoc file.rb
    # Prints colored documentation of file.rb.

    $ tomdoc file.rb -n STRING
    # Prints methods or classes in file.rb matching STRING.

    $ tomdoc fileA.rb fileB.rb ...
    # Prints colored documentation of multiple files.

    $ tomdoc -f html file.rb
    # Prints HTML documentation of file.rb.

    $ tomdoc -i file.rb
    # Ignore TomDoc validation, print any methods we find.

    $ tomdoc -h
    # Displays more options.


Ruby API
--------

Fully TomDoc'd. Well, it will be.

For now:

    $ tomdoc lib/tomdoc/source_parser.rb


Formats
-------

### Console

    tomdoc lib/tomdoc/source_parser.rb -n token

![pattern](http://img.skitch.com/20100408-mnyxuxb4xrrg5x4pnpsmuth4mu.png)

### HTML

    tomdoc -f html lib/tomdoc/source_parser.rb | browser

or

    tomdoc -f html lib/tomdoc/source_parser.rb > doc.html
    open doc.html

![html](http://img.skitch.com/20100408-dbhtc4mef2q3ygmn63csxgh14w.png)

Local Dev
---------

Want to hack on tomdoc.rb? Of course you do.

    git clone http://github.com/defunkt/tomdoc.git
    cd tomdoc
    bundle install --local
    ruby -rubygems ./bin/tomdoc lib/tomdoc/source_parser.rb

[man]: https://github.com/defunkt/tomdoc/blob/tomdoc.rb/man/tomdoc.5.ronn
[spec]: https://github.com/defunkt/tomdoc/blob/tomdoc.rb/tomdoc.md
