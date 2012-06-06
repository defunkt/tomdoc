require File.dirname(__FILE__) + '/lib/tomdoc/version'

Gem::Specification.new do |s|
  s.name              = "tomdoc"
  s.version           = TomDoc::VERSION
  s.date              = Time.now.strftime('%Y-%m-%d')
  s.summary           = "A TomDoc library for Ruby."
  s.homepage          = "http://github.com/defunkt/tomdoc"
  s.email             = "chris@ozmm.org"
  s.authors           = [ "Tom Preston-Werner", "Chris Wanstrath" ]
  s.has_rdoc          = false

  s.files             = %w( README.md Rakefile LICENSE )
  s.files            += Dir.glob("lib/**/*")
  s.files            += Dir.glob("bin/**/*")
  s.files            += Dir.glob("man/**/*")
  s.files            += Dir.glob("test/**/*")
  s.executables       = %w( tomdoc )

  s.add_dependency   "ruby_parser",    ">= 3.0.0.a1"
  s.add_dependency   "colored"

  s.description       = <<desc
  TomDoc is flexible code documentation with human readers in
  mind. The tomdoc gem is a Ruby library to discover and display
  TomDoc'd methods and classes.

  Given a Ruby file with TomDoc'd methods, tomdoc can generate HTML or
  print to the console. You can use it to query up a single method or
  a group of methods, and it's usable from irb.

  If you're using TomDoc, tomdoc is for you.
desc
end
