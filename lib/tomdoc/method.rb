module TomDoc
  # A Method can be instance or class level.
  class Method
    attr_accessor :name, :comment

    def initialize(name, comment = '', args = [])
      @name    = name
      @comment = comment
      @args    = args || []
    end
    alias_method :to_s, :name

    def tomdoc
      @tomdoc ||= TomDoc.new(@comment)
    end

    def description
      @tomdoc.description
    end

    def args
      @tomdoc.args
    end

    def returns
      @tomdoc.returns.last
    end

    def raises
      @tomdoc.raises
    end

    def examples
      @tomdoc.examples
    end

    def inspect
      "#{name}(#{args.join(', ')})"
    end
  end
end
