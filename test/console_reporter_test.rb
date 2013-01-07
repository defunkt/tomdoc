require 'test/helper'

class ConsoleReporterTest < TomDoc::Test
  def setup
    @text = TomDoc::Generator.new(:report => TomDoc::Reporters::Console).generate(fixture(:simple))
  end

  test "works" do
    assert_equal <<text, @text
--------------------------------------------------------------------------------
\e[1mSimple#string(text)\e[0m

Just a simple method.

\e[32mtext\e[0m - The \e[36mString\e[0m to return.

Returns a \e[36mString\e[0m.
text
  end
end
