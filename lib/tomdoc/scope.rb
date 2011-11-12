module TomDoc
  # A Scope is a Module or Class.
  # It may contain other scopes.
  class Scope
    include Enumerable

    attr_accessor :name, :comment, :instance_methods, :class_methods
    attr_accessor :scopes

    def initialize(name, comment = '', instance_methods = [], class_methods = [])
      @name = name
      @comment = comment
      @instance_methods = instance_methods
      @class_methods = class_methods
      @scopes = {}
    end

    def tomdoc
      @tomdoc ||= TomDoc.new(@comment)
    end

    def description
      tomdoc.description
    end

    def examples
      tomdoc.examples
    end

    def [](scope)
      @scopes[scope]
    end

    def keys
      @scopes.keys
    end

    def each(&block)
      @scopes.each(&block)
    end

    def to_s
      inspect
    end

    def inspect
      scopes = @scopes.keys.join(', ')
      imethods = @instance_methods.inspect
      cmethods = @class_methods.inspect

      "<#{name} scopes:[#{scopes}] :#{cmethods}: ##{imethods}#>"
    end
  end
end
