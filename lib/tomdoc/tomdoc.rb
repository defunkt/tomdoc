module TomDoc

  # TomDoc class needs Arg class.
  if RUBY_VERSION > '1.9'
    require_relative 'arg'
  else
    require 'tomdoc/arg'
  end

  class InvalidTomDoc < RuntimeError
    # Create new InvalidTomDoc object.
    #
    # doc - document string
    #
    def initialize(doc)
      @doc = doc
    end

    # Provide access to document string.
    #
    # Returns String.
    def message
      @doc
    end

    # Provide access to document string.
    #
    # Returns String.
    def to_s
      @doc
    end
  end

  #
  # TODO: Instead of having TomDoc::TomDoc, lets consider renaming this
  #       class TomDoc::Comment or something.
  #
  class TomDoc
    attr_accessor :raw

    # Public: Initialize a TomDoc object.
    #
    # text - The raw text of a method or class/module comment.
    #
    # Returns new TomDoc instance.
    def initialize(text, options={})
      @raw = text.to_s.strip

      @arguments        = []
      @examples         = []
      @returns          = []
      @raises           = []
      @signatures       = []
      @signature_fields = []

      parse unless @raw.empty?
    end

    def to_s
      @raw
    end

    # Validate given comment text.
    #
    # Returns true if comment is valid, otherwise false.
    def self.valid?(text)
      new(text).valid?
    end

    # Validate raw comment.
    #
    # Returns true if comment is valid, otherwise false.
    def valid?
      return false if !raw.include?('Returns')
      return false if sections.size < 2
      true
    end

    # Validate raw comment.
    #
    # Returns true if comment is valid.
    # Raises InvalidTomDoc if comment is not valid.
    def validate
      if !raw.include?('Returns')
        raise InvalidTomDoc.new("No `Returns' statement.")
      end

      if sections.size < 2
        raise InvalidTomDoc.new("No description section found.")
      end

      true
    end

    # The raw comment text cleaned-up and ready for section parsing.
    #
    # Returns cleaned-up comment String.
    def tomdoc
      lines = raw.split("\n")

      # remove remark symbol
      if lines.all?{ |line| /^\s*#/ =~ line }
        lines = lines.map do |line|
          line =~ /^(\s*#)/ ? line.sub($1, '') : nil
        end
      end

      # for some reason the first line is coming in without indention
      # regardless, so we temporary remove it
      first = lines.shift

      lines = deindent(lines)

      # put first line back
      unless first.nil?
        lines.unshift(first.sub(/^\s*/,''))
      end

      lines.compact.join("\n")
    end

    # List of comment sections. These are divided simply on "\n\n".
    #
    # Returns Array of comment sections.
    def sections
      parsed {
        @sections
      }
    end

    # Description of method or class/module.
    #
    # Returns description String.
    def description
      parsed {
        @description
      }
    end

    # Description of method or class/module.
    #
    # Returns description String.
    def arguments
      parsed {
        @arguments
      }
    end
    alias args arguments

    # List of use examples of a method or class/module.
    #
    # Returns String of examples.
    def examples
      parsed {
        @examples
      }
    end

    # Description of a methods yield procedure.
    #
    # Returns String decription of yield procedure.
    def yields
      parsed {
        @yields
      }
    end

    # The list of retrun values a method can return.
    #
    # Returns Array of method return descriptions.
    def returns
      parsed {
        @returns
      }
    end

    # A list of errors a method might raise.
    #
    # Returns Array of method raises descriptions.
    def raises
      parsed {
        @raises
      }
    end

    # A list of alternate method signatures.
    #
    # Returns Array of signatures.
    def signatures
      parsed {
        @signatures 
      }
    end

    # A list of signature fields.
    #
    # Returns Array of field definitions.
    def signature_fields
      parsed {
        @signature_fields
      }
    end

    # Check if method is public.
    #
    # Returns true if method is public.
    def public?
      parsed {
        @status == 'Public'
      }
    end

    # Check if method is internal.
    #
    # Returns true if method is internal.
    def internal?
      parsed {
        @status == 'Internal'
      }
    end

    # Check if method is deprecated.
    #
    # Returns true if method is deprecated.
    def deprecated?
      parsed {
        @status == 'Deprecated'
      }
    end

  private

    def deindent(lines)
      # remove indention
      spaces = lines.map do |line|
        next if line.strip.empty?
        md = /^(\s*)/.match(line)
        md ? md[1].size : nil
      end.compact

      space = spaces.min || 0
      lines.map do |line|
        if line.empty?
          line.strip
        else
          line[space..-1]
        end
      end
    end

    # Has the comment been parsed yet?
    def parsed(&block)
      parse unless @parsed
      block.call
    end

    # Internal: Parse the Tomdoc formatted comment.
    #
    # Returns true if there was a comment to parse.
    def parse
      @parsed = true

      @sections = tomdoc.split("\n\n")
      sections  = @sections.dup

      return false if sections.empty?

      parse_description(sections.shift)

      if sections.first && sections.first =~ /^\w+\s+\-/m
        parse_arguments(sections.shift)
      end

      current = sections.shift
      while current
        case current
        when /^Examples/
          parse_examples(current, sections)
        when /^Yields/
          parse_yields(current)
        when /^(Returns|Raises)/
          parse_returns(current)
        when /^Signature/
          parse_signature(current, sections)
        end
        current = sections.shift
      end

      return @parsed
    end

    # Parse description.
    #
    # section - String containig description.
    #
    # Returns nothing.
    def parse_description(section)
      if md = /^([A-Z]\w+\:)/.match(section)
        @status      = md[1].chomp(':')
        @description = md.post_match.strip
      else
        @description = section.strip
      end   
    end

    # Parse arguments section. Arguments occur subsequent to
    # the description.
    #
    # section - String contaning agument definitions.
    #
    # Returns nothing.
    def parse_arguments(section)
      args = []
      last_indent = nil

      section.split("\n").each do |line|
        next if line.strip.empty?
        indent = line.scan(/^\s*/)[0].to_s.size

        if last_indent && indent > last_indent
          args.last.description += line.squeeze(" ")
        else
          param, desc = line.split(" - ")
          args << Arg.new(param.strip, desc.strip) if param && desc
        end

        last_indent = indent
      end

      @arguments = args
    end

    # Parse examples.
    #
    # section  - String starting with `Examples`.
    # sections - All sections subsequent to section.
    #
    # Returns nothing.
    def parse_examples(section, sections)
      examples = []

      section = section.sub('Examples', '').strip

      examples << section unless section.empty?
      while sections.first && sections.first !~ /^\S/
        lines = sections.shift.split("\n")
        examples << deindent(lines).join("\n")
      end

      @examples = examples
    end

    # Parse yields section.
    #
    # section - String contaning Yields line.
    #
    # Returns nothing.
    def parse_yields(section)
      @yields = section.strip
    end

    # Parse returns section.
    #
    # section - String contaning Returns and/or Raises lines.
    #
    # Returns nothing.
    def parse_returns(section)
      returns, raises, current = [], [], []

      lines = section.split("\n")  
      lines.each do |line|
        case line
        when /^Returns/
          returns << line
          current = returns
        when /^Raises/
          raises << line
          current = raises
        when /^\s+/
          current.last << line.squeeze(' ')
        else
          current << line  # TODO: What to do with non-compliant line?
        end
      end

      @returns, @raises = returns, raises
    end

    # Parse signature section.
    #
    # section  - String starting with `Signature`.
    # sections - All sections subsequent to section.
    #
    # Returns nothing.
    def parse_signature(section, sections=[])
      signatures = []

      section = section.sub('Signature', '').strip

      signatures << section unless section.empty?

      while sections.first && sections.first !~ /^\S/
        sigs = sections.shift
        sigs.split("\n").each do |s|
          signatures << s.strip
        end
      end

      @signatures = signatures

      if sections.first && sections.first =~ /^\w+\s*\-/m
        parse_signature_fields(sections.shift)
      end
    end

    # Subsequent to Signature section there can be field
    # definitions.
    #
    # section  - String subsequent to signatures.
    #
    # Returns nothing.
    def parse_signature_fields(section)
      args = []
      last_indent = nil

      section.split("\n").each do |line|
        next if line.strip.empty?
        indent = line.scan(/^\s*/)[0].to_s.size

        if last_indent && indent > last_indent
          args.last.description += line.squeeze(" ")
        else
          param, desc = line.split(" - ")
          args << Arg.new(param.strip, desc.strip) if param && desc
        end

        last_indent = indent
      end

      @signature_fields = args
    end

  end
end
