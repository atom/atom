require 'rails/text_mate'

TM_VARIABLE_DEFAULTS = {
  :bundle_path    => "~/Library/Application Support/TextMate/Bundles/TextMate.tmbundle",
  :bundle_support => "~/Library/Application Support/TextMate/Bundles/TextMate.tmbundle/Support",
  :columns        => "100",
  :column_number  => "1",
  :comment_end    => "",
  :comment_mode   => "line",
  :comment_start  => "# ",
  :current_line   => "",
  :directory      => "~/Library/Application Support/TextMate/Bundles/TextMate.tmbundle/Support/test",
  :filename       => "text_mate_mock.rb",
  :filepath       => "~/Library/Application Support/TextMate/Bundles/Rails.tmbundle/Support/test/text_mate_mock.rb",
  :line_index     => "0",
  :line_number    => "4",
  :mode           => "Ruby on Rails",
  :organization_name => "syncPEOPLE",
  :project_directory => "~/Library/Application Support/TextMate/Bundles/Rails.tmbundle",
  :project_filepath  => "~/Library/Application Support/TextMate/Bundles/Rails.tmbundle/Rails.tmproj",
  :scope          => "source.ruby.rails",
  :selected_file  => "~/Library/Application Support/TextMate/Bundles/Rails.tmbundle/Support/test/text_mate_mock.rb",
  :selected_files => "'~/Library/Application Support/TextMate/Bundles/Rails.tmbundle/Support/test/text_mate_mock.rb'",
  :selected_text  => "",
  :soft_tabs      => "YES",
  :support_path   => "~/Library/Application Support/TextMate/Support",
  :tab_size       => "2" }

module TextMate
  class <<self
    TM_VARIABLE_DEFAULTS.each_pair do |key, value|
      eval "@@#{key} = %q{#{value}}"
      eval "def #{key}; @@#{key} end" unless TextMate.methods.include?(key.to_s)
      eval "def #{key}=(v); @@#{key} = v end"
    end

    def open_url(url)
      "open \"#{url}\""
    end

    def env(var)
      TextMate.class_eval("@@#{var}")
    end
  end
end