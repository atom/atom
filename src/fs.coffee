# commonjs fs module
# http://ringojs.org/api/v0.8/fs/

_ = require 'underscore'

jscocoa = require 'jscocoa'

module.exports =
  # Make the given path absolute by resolving it against the
  # current working directory.
  absolute: (path) ->
    if /~/.test path
      OSX.NSString.stringWithString(path).stringByExpandingTildeInPath
    else if path.indexOf('./') is 0
      throw "absolute: ./ not yet implemented"
    else
      path

  # Set the current working directory to `path`.
  changeWorkingDirectory: (path) ->
    OSX.NSFileManager.defaultManager.changeCurrentDirectoryPath path

  # Returns true if the file specified by path exists and is a
  # directory.
  isDirectory: (path) ->
    isDir = new jscocoa.outArgument
    exists = OSX.NSFileManager.defaultManager.
      fileExistsAtPath_isDirectory path, isDir
    exists and isDir.valueOf()

  # Returns true if the file specified by path exists and is a
  # regular file.
  isFile: (path) ->
    isDir = new jscocoa.outArgument
    exists = OSX.NSFileManager.defaultManager.
      fileExistsAtPath_isDirectory path, isDir
    exists and not isDir.valueOf()

  # Returns an array with all the names of files contained
  # in the directory path.
  list: (path, recursive) ->
    path = @absolute path
    fm = OSX.NSFileManager.defaultManager
    if recursive
      paths = fm.subpathsAtPath path
    else
      paths = fm.contentsOfDirectoryAtPath_error path, null
    _.map paths, (entry) -> "#{path}/#{entry}"

  # Return an array with all directories below (and including)
  # the given path, as discovered by depth-first traversal. Entries
  # are in lexically sorted order within directories. Symbolic links
  # to directories are not traversed into.
  listDirectoryTree: (path) ->
    @list path, true

  # Open, read, and close a file, returning the file's contents.
  read: (path) ->
    path = @absolute path
    enc  = OSX.NSUTF8StringEncoding
    OSX.NSString.stringWithContentsOfFile_encoding_error(path, enc, null)
    .toString()

  # Open, write, flush, and close a file, writing the given content.
  write: (path, content) ->
    str  = OSX.NSString.stringWithUTF8String content
    path = @absolute path
    enc  = OSX.NSUTF8StringEncoding
    str.writeToFile_atomically_encoding_error path, true, enc, null

  # Return the path name of the current working directory.
  workingDirectory: ->
    OSX.NSFileManager.defaultManager.currentDirectoryPath.toString()