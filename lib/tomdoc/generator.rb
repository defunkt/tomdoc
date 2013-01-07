module TomDoc
  class Generator
    attr_reader :options, :scopes, :report

    # Creates a Generator.
    #
    # options - Optional Symbol-keyed Hash:
    #             :validate - Whether or not to validate TomDoc.
    #
    # scopes - Optional Symbol-keyed Hash.
    #
    # Returns an instance of TomDoc::Generator
    def initialize(options = {}, scopes = {})
      @options = {
        :validate => true
      }
      @options.update(options)

      @report = @options.fetch(:report, Reporters::Console)
      @report = @report.new(self)

      @scopes = {}
    end

    def self.generate(text_or_sexp)
      new.generate(text_or_sexp)
    end

    def generate(text_or_sexp)
      if text_or_sexp.is_a?(String)
        sexp = SourceParser.parse(text_or_sexp)
      else
        sexp = text_or_sexp
      end

      process(sexp)
    end

    def process(scopes = {}, prefix = nil)
      old_scopes = @scopes
      @scopes = scopes
      scopes.each do |name, scope|
        write_scope(scope, prefix)
        process(scope, "#{name}::")
      end

      report.output
    ensure
      @scopes = old_scopes || {}
    end

    def write_scope(scope, prefix)
      report.write_scope_header(scope, prefix)

      report.before_all_methods(scope, prefix)
      write_class_methods(scope, prefix)
      write_instance_methods(scope, prefix)
      report.after_all_methods(scope, prefix)

      report.write_scope_footer(scope, prefix)
    end

    def write_class_methods(scope, prefix = nil)
      prefix ="#{prefix}#{scope.name}."

      scope.class_methods.map do |method|
        next if !valid?(method, prefix)
        report.write_method(method, prefix)
      end.compact
    end

    def write_instance_methods(scope, prefix = nil)
      prefix = "#{prefix}#{scope.name}#"

      scope.instance_methods.map do |method|
        next if !valid?(method, prefix)
        report.write_method(method, prefix)
      end.compact
    end

    def pygments(text, *args)
      out = ''

      Open3.popen3("pygmentize", *args) do |stdin, stdout, stderr|
        stdin.puts text
        stdin.close
        out = stdout.read.chomp
      end

      out
    end

    def constant?(const)
      const = const.split('::').first if const.include?('::')
      constant_names.include?(const.intern) || Object.const_defined?(const)
    end

    def constant_names
      name = @scopes.name if @scopes.respond_to?(:name)
      [ :Boolean, :Test, name ].compact + @scopes.keys
    end

    def valid?(object, prefix)
      matches_pattern?(prefix, object.name) && valid_tomdoc?(object.tomdoc)
    end

    def matches_pattern?(prefix, name)
      if pattern = options[:pattern]
        # "-n hey" vs "-n /he.+y/"
        if pattern =~ /^\/.+\/$/
          pattern = pattern.sub(/^\//, '').sub(/\/$/, '')
          regexp = Regexp.new(pattern)
        else
          regexp = Regexp.new(Regexp.escape(pattern))
        end

        regexp =~ name.to_s || regexp =~ prefix.to_s
      else
        true
      end
    end

    def valid_tomdoc?(comment)
      options[:validate] ? TomDoc.valid?(comment) : true
    end
  end
end
