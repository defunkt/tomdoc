require 'optparse'

module TomDoc
  class CLI
    #
    # DSL Magics
    #

    def self.options(&block)
      block ? (@options = block) : @options
    end

    def options
      OptionParser.new do |opts|
        opts.instance_eval(&self.class.options)
      end
    end

    def pp(*args)
      require 'pp'
      super
    end


    #
    # Define Options
    #

    options do
      @options = {}

      self.banner = "Usage: tomdoc [options] FILE1 FILE2 ..."

      separator " "
      separator "Examples:"
      separator <<example
  $ tomdoc file.rb
  # Prints colored documentation of file.rb.

  $ tomdoc file.rb -n STRING
  # Prints methods or classes in file.rb matching STRING.

  $ tomdoc -f html file.rb
  # Prints HTML documentation of file.rb.
example

      separator " "
      separator "Options:"

      on "-c", "--colored", "Pass -p, -s, or -t output to Pygments." do
        ARGV.delete('-c') || ARGV.delete('--colored')
        exec "#{$0} #{ARGV * ' '} | pygmentize -l ruby"
      end

      on "-t", "--tokens", "Parse FILE and print the tokenized form." do
        sexp = SourceParser.new.sexp(argf.read)
        pp SourceParser.new.tokenize(sexp)
        exit
      end

      on "-s", "--sexp", "Parse FILE and print the AST's sexps." do
        pp RubyParser.new.parse(argf.read).to_a
        exit
      end

      on "-n", "--pattern=PATTERN",
        "Limit results to strings matching PATTERN." do |pattern|

        @options[:pattern] = pattern
      end

      on "-f", "--format=FORMAT",
        "Parse FILE and print the TomDoc as FORMAT." do |format|

        if format.to_s.downcase == "html"
          @options[:report] = Reporters::HTML
          puts Generator.new(@options).generate(argf.read)
          exit
        end
      end

      on "-i", "--ignore",
        "Ignore validation, print all methods we find with comments.." do

        @options[:validate] = false
      end

      separator " "
      separator "Common Options:"

      on "-v", "--version", "Print the version" do
        puts "TomDoc v#{VERSION}"
        exit
      end

      on "-h", "--help", "Show this message" do
        puts self
        exit
      end

      on_tail do
        puts Generator.new(@options).generate(argf.read)
        exit
      end

      separator ""
    end


    #
    # Actions
    #

    def self.parse_options(args)
      new.parse_options(args)
    end

    def parse_options(args)
      options.parse(args)
    end
  end
end

class OptionParser
  # ARGF faker.
  def argf
    buffer = ''

    ARGV.select { |arg| File.exists?(arg) }.each do |file|
      buffer << File.read(file)
    end

    require 'stringio'
    StringIO.new(buffer)
  end
end


#
# Main
#

# Help is the default.
ARGV << '-h' if ARGV.empty? && $stdin.tty?

# Process options
TomDoc::CLI.parse_options(ARGV) if $stdin.tty?

# Still here - process ARGF
TomDoc::CLI.process_files(ARGF)

