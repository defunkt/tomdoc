require 'test/helper'

class MethodsReporter < TomDoc::Reporters::Base
  def write_method(method, prefix = '')
    @buffer = [] if @buffer.is_a?(String)
    @buffer << method.name
  end
end

class GeneratorTest < TomDoc::Test

  def setup
    @generator = TomDoc::Generator.new(:report => MethodsReporter)
  end

  test "can ignore validation methods" do
    @generator.options[:validate] = false
    methods = @generator.generate(fixture(:chimney))
    assert_equal 47, methods.size
  end

  test "ignores invalid methods" do
    @generator.options[:validate] = true
    methods = @generator.generate(fixture(:chimney))
    assert_equal 39, methods.size
  end

  test "detects built-in constants" do
    assert @generator.constant?('Object')
    assert @generator.constant?('Kernel')
    assert @generator.constant?('String')
  end

  test "detects common constants" do
    assert @generator.constant?('Boolean')
    assert @generator.constant?('Test::Unit::TestCase')
  end

  test "picks up constants from the thing we're TomDocin'" do
    scope = { :Chimney => TomDoc::Scope.new('Chimney') }
    @generator.instance_variable_set(:@scopes, scope)
    assert @generator.constant?('Chimney')
  end

  test "ignores non-constants" do
    assert !@generator.constant?('Dog')
  end
end
