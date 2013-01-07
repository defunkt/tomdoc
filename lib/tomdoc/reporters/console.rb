module TomDoc
  module Reporters
    class Console < Base

      def write_scope_header(scope, prefix = '')
        return if scope.tomdoc.to_s.empty?
        write_method(scope, prefix)
      end

      def write_method(method, prefix = '')
        write '-' * 80
        write "#{prefix}#{method.name}#{args(method)}".bold, ''
        write format_comment(method.tomdoc)
      end

      protected

      def args(method)
        return '' if !method.respond_to?(:args)
        if method.args.any?
          '(' + method.args.join(', ') + ')'
        else
          ''
        end
      end

      def highlight(text)
        @generator.pygments(text, '-l', 'ruby')
      end

      def format_comment(comment)
        comment = comment.to_s

        # Strip leading comments
        comment.gsub!(/^# ?/, '')

        # Example code
        comment.gsub!(/(\s*Examples\s*(.+?)\s*Returns)/m) do
          $1.sub($2, highlight($2))
        end

        # Param list
        comment.gsub!(/^(\s*(\w+) +- )/) do
          param = $2
          $1.sub(param, param.green)
        end

        # true/false/nil
        comment.gsub!(/(true|false|nil)/, '\1'.magenta)

        # Strings
        comment.gsub!(/('.+?')/, '\1'.yellow)
        comment.gsub!(/(".+?")/, '\1'.yellow)

        # Symbols
        comment.gsub!(/(\s+:\w+)/, '\1'.red)

        # Constants
        comment.gsub!(/(([A-Z]\w+(::)?)+)/) do
          if @generator.constant?($1.strip)
            $1.split('::').map { |part| part.cyan }.join('::')
          else
            $1
          end
        end

        comment
      end

    end
  end
end
