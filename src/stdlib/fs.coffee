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

  # Set the current working directory to `path`.
  changeWorkingDirectory: (path) ->
    OSX.NSFileManager.defaultManager.changeCurrentDirectoryPath path

  # Return the dirname of the given path. That is the path with any trailing
  # non-directory component removed.
  directory: (path) ->
    if @isDirectory(absPath)
      absPath.replace(/\/?$/, '/')
    else
      absPath.replace(new RegExp("/#{@base(path)}$"), '/')

  # Returns true if the file specified by path exists
  exists: (path) ->
    OSX.NSFileManager.defaultManager.fileExistsAtPath_isDirectory path, null

  join: (paths...) ->
    return paths[0] if paths.length == 1
    [first, rest...] = paths
    first.replace(/\/?$/, "/") + @join(rest...)

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
    $atomController.fs.isFile path

  # Returns an array with all the names of files contained
  # in the directory path.
  list: (path) ->
    fm = OSX.NSFileManager.defaultManager
    $native.list(path, recursive)

  # Remove a file at the given path. Throws an error if path is not a
  # file or a symbolic link to a file.
  remove: (path) ->
    fm = OSX.NSFileManager.defaultManager
    paths = fm.removeItemAtPath_error path, null

  # Open, read, and close a file, returning the file's contents.
  read: (path) ->
    $native.read(path)

  # Open, write, flush, and close a file, writing the given content.
  write: (path, content) ->
    str  = OSX.NSString.stringWithUTF8String content
    enc  = OSX.NSUTF8StringEncoding
    str.writeToFile_atomically_encoding_error path, true, enc, null

  # Return the path name of the current working directory.
  workingDirectory: ->
    OSX.NSFileManager.defaultManager.currentDirectoryPath.toString()

  async:
    listFiles: (path, recursive) ->
      deferred = $.Deferred()
      $atomController.fs.listFilesAtPath_recursive_onComplete path, recursive, (subpaths) ->
        deferred.resolve subpaths
      deferred

