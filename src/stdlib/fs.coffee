# commonjs fs module
# http://ringojs.org/api/v0.8/fs/

_ = require 'underscore'
$ = require 'jquery'
jscocoa = require 'jscocoa'

module.exports =
  # Make the given path absolute by resolving it against the
  # current working directory.
  absolute: (path) ->
    atom.native.absolute(path)

  # Return the basename of the given path. That is the path with
  # any leading directory components removed. If specified, also
  # remove a trailing extension.
  base: (path, ext) ->
    base = path.split("/").pop()
    if ext then base.replace(RegEx(ext + "$"), "") else base

  # Return the dirname of the given path. That is the path with any trailing
  # non-directory component removed.
  directory: (path) ->
    if @isDirectory(path)
      path.replace(/\/?$/, '/')
    else
      path.replace(new RegExp("/#{@base(path)}$"), '/')

  # Returns true if the file specified by path exists
  exists: (path) ->
    atom.native.exists path

  join: (paths...) ->
    return paths[0] if paths.length == 1
    [first, rest...] = paths
    first.replace(/\/?$/, "/") + @join(rest...)

  # Returns true if the file specified by path exists and is a
  # directory.
  isDirectory: (path) ->
    atom.native.isDirectory path

  # Returns true if the file specified by path exists and is a
  # regular file.
  isFile: (path) ->
    not atom.native.isDirectory path

  # Returns an array with all the names of files contained
  # in the directory path.
  list: (path) ->
    atom.native.list(path, false)

  listTree: (path) ->
    atom.native.list(path, true)

  # Remove a file at the given path. Throws an error if path is not a
  # file or a symbolic link to a file.
  remove: (path) ->
    atom.native.remove path

  # Open, read, and close a file, returning the file's contents.
  read: (path) ->
    atom.native.read(path)

  # Open, write, flush, and close a file, writing the given content.
  write: (path, content) ->
    atom.native.write(path, content)

  async:
    list: (path) ->
      deferred = $.Deferred()
      atom.native.asyncList path, false, (subpaths) ->
        deferred.resolve subpaths
      deferred

    listTree: (path) ->
      deferred = $.Deferred()
      atom.native.asyncList path, true, (subpaths) ->
        deferred.resolve subpaths
      deferred

