module TomDoc
  module Reporters
    class Base

      def initialize(generator)
        @generator = generator
        @buffer = ""
      end

      def write(*things)
        things.each do |thing|
          @buffer << "#{thing}\n"
        end
        nil
      end

      def output
        @buffer
      end

      def write_scope_header(scope, prefix = '')
        # Optional Implementation
      end

      def before_all_methods(scope, prefix)
        # Optional Implementation
      end

      def write_method(method, prefix = '')
        raise NotImplementedError
      end

      def after_all_methods(scope, prefix)
        # Optional Implementation
      end

      def write_scope_footer(scope, prefix)
        # Optional Implementation
      end

    end
  end
end
