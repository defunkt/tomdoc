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

  class TomDoc
    attr_accessor :raw

    def initialize(text)
      @raw = text.to_s.strip
    end

    def to_s
      @raw
    end

    def self.valid?(text)
      new(text).valid?
    end

    def valid?
      validate
    rescue InvalidTomDoc
      false
    end

    def validate
      if !raw.include?('Returns')
        raise InvalidTomDoc.new("No `Returns' statement.")
      end

      if sections.size < 2
        raise InvalidTomDoc.new("No description section found.")
      end

      true
    end

    def tomdoc
      #raw
      clean = raw.split("\n").map do |line|
        line =~ /^(\s*# ?)/ ? line.sub($1, '') : nil
      end.compact.join("\n")
      clean
    end

    def sections
      @sections ||= tomdoc.split("\n\n")
    end

    def description
      sections.first
    end

    def args
      args = []
      last_indent = nil

      return args unless sections[1]

      sections[1].split("\n").each do |line|
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

      args
    end

    def examples
      if tomdoc =~ /(\s*Examples\s*(.+?)\s*(?:Returns|Raises))/m
        $2.split("\n\n")
      else
        []
      end
    end

    def returns
      if tomdoc =~ /^\s*(Returns.+)/m
        lines = $1.split("\n")
        statements = []

        lines.each do |line|
          next if line =~ /^\s*Raises/
          if line =~ /^\s+/
            statements.last << line.squeeze(' ')
          else
            statements << line
          end
        end

        statements
      else
        []
      end
    end

    def raises
      if tomdoc =~ /^\s*(Raises.+)/m
        lines = $1.split("\n")
        statements = []

        lines.each do |line|
          if line =~ /^\s+/
            statements.last << line.squeeze(' ')
          else
            statements << line
          end
        end

        statements
      else
        []
      end
    end
  end
end
