if RUBY_VERSION >= "1.9"
  class String
    alias :each :each_line
    include Enumerable
  end

  module Enumerable
    alias :enum_with_index :each_with_index
  end

  class Array
    alias :to_s :join
  end
end
