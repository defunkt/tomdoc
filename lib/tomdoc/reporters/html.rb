module TomDoc
  module Reporters
    class HTML < Base

      #def highlight(text)
      #  pygments(text, '-l', 'ruby', '-f', 'html')
      #end

      def write_scope_header(scope, prefix)
        #write "<h1>#{scope.name}</h1>"
      end

      def before_all_methods(scope, prefix)
        write '<ul>'
      end

      def after_all_methods(scope, prefix)
        write '</ul>'
      end

      def write_method(method, prefix = '')
        if method.args.any?
          args = '(' + method.args.join(', ') + ')'
        end
        out = '<li>'
        out << "<b>#{prefix}#{method.to_s}#{args}</b>"

        out << '<pre>'
        out << method.tomdoc.tomdoc
        out << '</pre>'

        out << '</li>'
        write out
      end

    end
  end
end
