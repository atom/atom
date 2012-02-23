# commonjs fs module
# http://ringojs.org/api/v0.8/fs/

_ = require 'underscore'
$ = require 'jquery'
jscocoa = require 'jscocoa'

module.exports =
  # Make the given path absolute by resolving it against the
  # current working directory.
  absolute: (path) ->
    $native.absolute(path)

  # Return the basename of the given path. That is the path with
  # any leading directory components removed. If specified, also
  # remove a trailing extension.
  base: (path, ext) ->
    base = path.split("/").pop()
    if ext then base.replace(RegEx(ext + "$"), "") else base

  # Return the dirname of the given path. That is the path with any trailing
  # non-directory component removed.
  directory: (path) ->
    if @isDirectory(absPath)
      absPath.replace(/\/?$/, '/')
    else
      absPath.replace(new RegExp("/#{@base(path)}$"), '/')

  # Returns true if the file specified by path exists
  exists: (path) ->
    $native.exists path

  join: (paths...) ->
    return paths[0] if paths.length == 1
    [first, rest...] = paths
    first.replace(/\/?$/, "/") + @join(rest...)

  # Returns true if the file specified by path exists and is a
  # directory.
  isDirectory: (path) ->
    $native.isDirectory path

  # Returns true if the file specified by path exists and is a
  # regular file.
  isFile: (path) ->
    $native.isFile path

  # Returns an array with all the names of files contained
  # in the directory path.
  list: (path) ->
    $native.list(path, false)

  # Returns an Array that starts with the given directory, and all the
  # directories relative to the given path, discovered by a depth first
  # traversal of every directory in any visited directory, not traversing
  # symbolic links to directories, in lexically sorted order within
  # directories.
  listDirectoryTree: (path) ->
    $native.list(path, true)

  # Remove a file at the given path. Throws an error if path is not a
  # file or a symbolic link to a file.
  remove: (path) ->
    $native.remove path

  # Open, read, and close a file, returning the file's contents.
  read: (path) ->
    $native.read(path)

  # Open, write, flush, and close a file, writing the given content.
  write: (path, content) ->
    str  = OSX.NSString.stringWithUTF8String content
    enc  = OSX.NSUTF8StringEncoding
    str.writeToFile_atomically_encoding_error path, true, enc, null

  async:
    listFiles: (path, recursive) ->
      deferred = $.Deferred()
      $atomController.fs.listFilesAtPath_recursive_onComplete path, recursive, (subpaths) ->
        deferred.resolve subpaths
      deferred

