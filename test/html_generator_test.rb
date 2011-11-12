require 'test/helper'

class HTMLGeneratorTest < TomDoc::Test
  def setup
    @html = TomDoc::Generators::HTML.generate(fixture(:simple))
  end

  test "works" do
    assert_equal <<html, @html
<ul>
<li><code>Simple#string(text)</code><p>Public: Just a simple method.</p>

<dl>
<dt><code>text</code></dt>
<dd>The String to return.</dd>
</dl>

<p>Returns a String.</p></li></ul>
html
  end
end
