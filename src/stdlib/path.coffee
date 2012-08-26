# node.js path module
# http://nodejs.org/docs/v0.6.0/api/path.html

_ = require 'underscore'

module.exports =
  # Return the last portion of a path. Similar to the Unix basename command.
  basename: (filepath) ->
    _.last filepath.split '/'

  # Return the extension of the path, from the last '.' to end of string in
  # the last portion of the path. If there is no '.' in the last portion of
  # the path or the first character of it is '.', then it returns an empty string.
  extname: (filepath) ->
    _.last filepath.split '.'
