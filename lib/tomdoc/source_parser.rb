module TomDoc
  class SourceParser
    # Converts Ruby code into a data structure.
    #
    # text - A String of Ruby code.
    #
    # Returns a Hash with each key a namespace and each value another
    #   Hash or a TomDoc::Scope.
    def self.parse(text)
      new.parse(text)
    end

    attr_accessor :parser, :scopes, :options

    # Each instance of SourceParser accumulates scopes with each
    # parse, making it easy to parse an entire project in chunks but
    # more difficult to parse disparate files in one go. Create
    # separate instances for separate global scopes.
    #
    # Returns an instance of TomDoc::SourceParser
    def initialize(options = {})
      @options = {}
      @parser  = Ruby19Parser.new
      @scopes  = {}
    end

    # Resets the state of the parser to a pristine one. Maintains options.
    #
    # Returns nothing.
    def reset
      initialize(@options)
    end

    # Converts Ruby code into a data structure. Note that at the
    # instance level scopes accumulate, which makes it easy to parse
    # multiple files in a single project but harder to parse files
    # that have no connection.
    #
    # text - A String of Ruby code.
    #
    # Examples
    #   @parser = TomDoc::SourceParser.new
    #   files.each do |file|
    #     @parser.parse(File.read(file))
    #   end
    #   pp @parser.scopes
    #
    # Returns a Hash with each key a namespace and each value another
    #   Hash or a TomDoc::Scope.
    def parse(text)
      process(tokenize(sexp(text)))
      @scopes
    end

    # Converts Ruby sourcecode into an AST.
    #
    # text - A String of Ruby source.
    #
    # Returns a Sexp representing the AST.
    def sexp(text)
      @parser.parse(text)
    end

    # Converts a tokenized Array of classes, modules, and methods into
    # Scopes and Methods, adding them to the @scopes instance variable
    # as it works.
    #
    # ast   - Tokenized Array produced by calling `tokenize`.
    # scope - An optional Scope object for nested classes or modules.
    #
    # Returns nothing.
    def process(ast, scope = nil)
      case Array(ast)[0]
      when :module, :class
        name = ast[1]
        new_scope = Scope.new(name, ast[2])

        if scope
          scope.scopes[name] = new_scope
        elsif @scopes[name]
          new_scope = @scopes[name]
        else
          @scopes[name] = new_scope
        end

        process(ast[3], new_scope)
      when :imethod
        ast.shift
        if !scope
          scope = (@scopes[:main] ||= Scope.new(:main))
        end
        scope.instance_methods << Method.new(*ast)
      when :cmethod
        ast.shift
        if !scope
          scope = (@scopes[:main] ||= Scope.new(:main))
        end
        scope.class_methods << Method.new(*ast)
      when Array
        ast.map { |a| process(a, scope) }
      end
    end

    # Converts a Ruby AST-style Sexp into an Array of more useful tokens.
    #
    # node - A Ruby AST Sexp or Array
    #
    # Examples
    #
    #   [:module, :Math, "",
    #     [:class, :Multiplexer, "# Class Comment",
    #       [:cmethod,
    #         :multiplex, "# Class Method Comment", [:text]],
    #       [:imethod,
    #         :multiplex, "# Instance Method Comment", [:text, :count]]]]
    #
    #   # In others words:
    #   # [ :type, :name, :comment, other ]
    #
    # Returns an Array in the above format.
    def tokenize(node)
      case Array(node)[0]
      when :module
        name = node[1]
        [ :module, name, node.comments, tokenize(node[2]) ]
      when :class
        name = node[1]
        [ :class, name, node.comments, tokenize(node[3]) ]
      when :defn
        name = node[1]
        args = args_for_node(node[2])
        [ :imethod, name, node.comments, args ]
      when :defs
        name = node[2]
        args = args_for_node(node[3])
        [ :cmethod, name, node.comments, args ]
      when :block
        tokenize(node[1..-1])
      when :scope
        tokenize(node[1])
      when Array
        node.map { |n| tokenize(n) }.compact
      end
    end

    # Given a method sexp, returns an array of the args.
    def args_for_node(node)
      Array(node)[1..-1].select { |arg| arg.is_a? Symbol }
    end
  end
end
