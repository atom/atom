#!/usr/bin/env ruby

$: << "#{ENV['TM_SUPPORT_PATH']}/lib" if ENV.has_key?('TM_SUPPORT_PATH')
require "escape"

module RubyRequires
  module_function
  
  def build_requires( code, libs )
    libs.reject { |lib| code =~ /require\s*(['"])#{lib}\1/ }.
         map { |lib| "require \"#{lib}\"\n" }.join
  end

  def place_requires( code, new_reqs )
    return code unless new_reqs =~ /\S/

    code.dup.sub!(/(?:^[ \t]*require\s*(['"]).+?\1.*\n)+/, "\\&#{new_reqs}") ||
    code.sub(/\A(?:\s*(?:#.*)?\n)*/, "\\&#{new_reqs}\n")
  end

  def add_requires( code, reqs )
    new_reqs = build_requires(code, reqs)
    code     = place_requires(code, new_reqs)
    e_sn(code)
  end
end
