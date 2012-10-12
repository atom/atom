# Adapted from https://github.com/mxcl/homebrew/pull/11776/files

require 'formula'

class GypFormula < Formula
  homepage 'http://code.google.com/p/gyp/'
  url 'http://gyp.googlecode.com/svn/trunk', :revision => 1518
  version 'trunk-1518'
  head 'http://gyp.googlecode.com/svn/trunk'

  def install
    system "python", "setup.py", "install",
      "--prefix=#{prefix}", "--install-purelib=#{libexec}",
      "--install-platlib=#{libexec}", "--install-scripts=#{bin}"

    mv bin + 'gyp', bin + 'gyp.py'
    mv Dir[bin + '*'], libexec

    bin.install_symlink "#{libexec}/gyp.py" => "gyp"
  end
end
