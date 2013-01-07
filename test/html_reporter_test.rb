require 'test/helper'

class HTMLReporterTest < TomDoc::Test
  def setup
    @html = TomDoc::Generator.new(:report => TomDoc::Reporters::HTML).generate(fixture(:simple))
  end

  test "works" do
    assert_equal <<html, @html
<ul>
<li><b>Simple#string(text)</b><pre>Just a simple method.

text - The String to return.

Returns a String.</pre></li>
</ul>
html
  end
end
