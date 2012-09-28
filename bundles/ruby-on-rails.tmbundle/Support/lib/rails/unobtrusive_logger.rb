# Copyright:
#   (c) 2006 syncPEOPLE, LLC.
#   Visit us at http://syncpeople.com/
# Author: Duane Johnson (duane.johnson@gmail.com)
# Description:
#   Simple delegate class for Logger.  Its purpose is to prevent littering the
#   home directory with log files.  Useful for testing / development of bundles.

require 'logger'

class UnobtrusiveLogger
  attr_accessor :filename, :logger
  def initialize(filename)
    @filename = filename
    @logger = nil
  end
  def method_missing(method, *args)
    @logger = Logger.new(@filename) unless @logger
    @logger.send(method, *args)
  end
end

$logger = UnobtrusiveLogger.new("/tmp/textmate_rails_bundle.log")
