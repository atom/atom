require File.dirname(__FILE__) + '/test_helper'
require "rails/generate"

class TestBinGenerate < Test::Unit::TestCase
  def test_known_generators
    expected = %w[scaffold controller model mailer migration plugin]
    actual = Generator.known_generators.map { |gen| gen.name }
    assert_equal(expected, actual)
  end

  def test_find_generator_names
    list = Generator.find_generator_names
    assert_equal(Array, list.class)
    list.each do |name|
      assert_equal(String, name.class)
      assert_no_match(/[ \t\n]/, name, "generator names should not contain spaces")
    end
  end

  def test_generators
    generators = Generator.setup_generators
    assert(generators.length > 6, "Failure message.")
    assert_equal(Array, generators.class)
    generators.each do |gen|
      assert_equal(Generator, gen.class)
      assert_no_match(/[ \t\n]/, gen.name, "generator names should not contain spaces")
    end
  end
end