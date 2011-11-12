module TomDoc
  module Generators
    class HTML < Generator
      def highlight(text)
        pygments(text, '-l', 'ruby', '-f', 'html')
      end

      def write_scope_header(scope, prefix)
        write tag('h1', tag('code', "#{prefix}#{scope.name}"))
        write tag('p', scope.description)

        if scope.examples.any?
          write tag('h2', "Examples")
          scope.examples.each do |example|
            write highlight(example)
          end
        end
      end

      def write_scope_footer(scope, prefix)
      end

      def write_class_methods(scope, prefix)
        write tag('h2', "Class Methods")
        super.join
      end

      def write_instance_methods(scope, prefix)
        write tag('h2', "Instance Methods")
        super.join
      end

      def write_method(method, prefix = '')
        if method.args.any?
          args = '(' + method.args.map {|a| a.name }.join(', ') + ')'
        end
        out = tag('h3', tag('code', "#{prefix}#{method.to_s}#{args}"))

        out << tag('p', method.description)

        write_arg_list(out, method.args) if method.args.any?

        if method.examples.any?
          out << tag('h4', 'Examples')
          method.examples.each do |example|
            out << highlight(example)
          end
        end

        out << tag('p', method.returns)
        out << method.raises.map {|r| tag('p', r) }.join("\n")

        write out
      end

      private

      def write_arg_list(out, args)
        out << '<dl>'

        args.each do |arg|
          out << tag('dt', tag('code', arg.name))
          out << tag('dd', arg.description)
        end

        out << '</dl>'
      end

      def tag(name, content)
        "<#{name}>#{content}</#{name}>"
      end
    end
  end
end
