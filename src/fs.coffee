# commonjs fs module
# http://ringojs.org/api/v0.8/fs/

module.exports =
  # Make the given path absolute by resolving it against the
  # current working directory.
  absolute: (path) ->
    if /~/.test path
      OSX.NSString.stringWithString(path).stringByExpandingTildeInPath
    else if path.indexOf('./') is 0
      "#{Chrome.appRoot}/#{path}"
    else
      path

  # Returns true if the file specified by path exists and is a
  # regular file.
  isFile: (path) ->
    isDir = new jscocoa.outArgument
    exists = OSX.NSFileManager.defaultManager.
      fileExistsAtPath_isDirectory path, isDir
    exists and not isDir.valueOf()

  # Open, read, and close a file, returning the file's contents.
  read: (path) ->
    OSX.NSString.stringWithContentsOfFile(@absolute path).toString()

  # Open, write, flush, and close a file, writing the given content.
  write: (path, content) ->
    str = OSX.NSString.stringWithString content
    str.writeToFile_atomically @absolute(path), true
