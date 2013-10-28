_ = require 'underscore-plus'
fs = require 'fs'
mkdirp = require 'mkdirp'
Module = require 'module'
async = require 'async'
rimraf = require 'rimraf'
path = require 'path'

# Public: Useful extensions to node's built-in fs module
#
# Important, this extends Node's builtin in ['fs' module][fs], which means that you
# can do anything that you can do with Node's 'fs' module plus a few extra
# functions that we've found to be helpful.
#
# [fs]: http://nodejs.org/api/fs.html
fsExtensions =
  # Public: Make the given path absolute by resolving it against the current
  # working directory.
  #
  # * relativePath:
  #   The String containing the relative path. If the path is prefixed with
  #   '~', it will be expanded to the current user's home directory.
  #
  # Returns the absolute path or the relative path if it's unable to determine
  # it's realpath.
  absolute: (relativePath) ->
    return null unless relativePath?

    homeDir = process.env[if process.platform is 'win32' then 'USERPROFILE' else 'HOME']

    if relativePath is '~'
      relativePath = homeDir
    else if relativePath.indexOf('~/') is 0
      relativePath = "#{homeDir}#{relativePath.substring(1)}"

    try
      fs.realpathSync(relativePath)
    catch e
      relativePath

  # Public: Returns true if a file or folder at the specified path exists.
  exists: (pathToCheck) ->
    # TODO: rename to existsSync
    pathToCheck? and fs.statSyncNoException(pathToCheck) isnt false

  # Public: Returns true if the given path exists and is a directory.
  isDirectorySync: (directoryPath) ->
    return false unless directoryPath?.length > 0
    if stat = fs.statSyncNoException(directoryPath)
      stat.isDirectory()
    else
      false

  # Public: Asynchronously checks that the given path exists and is a directory.
  isDirectory: (directoryPath, done) ->
    return done(false) unless directoryPath?.length > 0
    fs.exists directoryPath, (exists) ->
      if exists
        fs.stat directoryPath, (error, stat) ->
          if error?
            done(false)
          else
            done(stat.isDirectory())
      else
        done(false)

  # Public: Returns true if the specified path exists and is a file.
  isFileSync: (filePath) ->
    return false unless filePath?.length > 0
    if stat = fs.statSyncNoException(filePath)
      stat.isFile()
    else
      false

  # Public: Returns true if the specified path is executable.
  isExecutableSync: (pathToCheck) ->
    return false unless pathToCheck?.length > 0
    if stat = fs.statSyncNoException(pathToCheck)
      (stat.mode & 0o777 & 1) isnt 0
    else
      false

  # Public: Returns an Array with the paths of the files and directories
  # contained within the directory path. It is not recursive.
  #
  # * rootPath:
  #   The absolute path to the directory to list.
  # * extensions:
  #   An array of extensions to filter the results by. If none are given, none
  #   are filtered (optional).
  listSync: (rootPath, extensions) ->
    return [] unless @isDirectorySync(rootPath)
    paths = fs.readdirSync(rootPath)
    paths = @filterExtensions(paths, extensions) if extensions
    paths = paths.map (childPath) -> path.join(rootPath, childPath)
    paths

  # Public: Asynchronously lists the files and directories in the given path.
  # The listing is not recursive.
  #
  # * rootPath:
  #   The absolute path to the directory to list.
  # * extensions:
  #   An array of extensions to filter the results by. If none are given, none
  #   are filtered (optional)
  # * callback:
  #   The function to call
  list: (rootPath, rest...) ->
    extensions = rest.shift() if rest.length > 1
    done = rest.shift()
    fs.readdir rootPath, (error, paths) =>
      if error?
        done(error)
      else
        paths = @filterExtensions(paths, extensions) if extensions
        paths = paths.map (childPath) -> path.join(rootPath, childPath)
        done(null, paths)

  # Private: Returns only the paths which end with one of the given extensions.
  filterExtensions: (paths, extensions) ->
    extensions = extensions.map (ext) ->
      if ext is ''
        ext
      else
        '.' + ext.replace(/^\./, '')
    paths.filter (pathToCheck) -> _.include(extensions, path.extname(pathToCheck))

  # Deprecated: No one currently uses this.
  listTreeSync: (rootPath) ->
    paths = []
    onPath = (childPath) ->
      paths.push(childPath)
      true
    @traverseTreeSync(rootPath, onPath, onPath)
    paths

  # Public: Moves the file or directory to the target synchronously.
  move: (source, target) ->
    # TODO: This should be renamed to moveSync
    fs.renameSync(source, target)

  # Public: Removes the file or directory at the given path synchronously.
  remove: (pathToRemove) ->
    # TODO: This should be renamed to removeSync
    rimraf.sync(pathToRemove)

  # Public: Open, read, and close a file, returning the file's contents
  # synchronously.
  read: (filePath) ->
    # TODO: This should be renamed to readSync
    fs.readFileSync(filePath, 'utf8')

  # Public: Open, write, flush, and close a file, writing the given content
  # synchronously.
  #
  # It also creates the necessary parent directories.
  writeSync: (filePath, content) ->
    mkdirp.sync(path.dirname(filePath))
    fs.writeFileSync(filePath, content)

  # Public: Open, write, flush, and close a file, writing the given content
  # asynchronously.
  #
  # It also creates the necessary parent directories.
  write: (filePath, content, callback) ->
    mkdirp path.dirname(filePath), (error) ->
      if error?
        callback?(error)
      else
        fs.writeFile(filePath, content, callback)

  # Public: Copies the given path asynchronously.
  copy: (sourcePath, destinationPath, done) ->
    mkdirp path.dirname(destinationPath), (error) ->
      if error?
        done?(error)
        return

      sourceStream = fs.createReadStream(sourcePath)
      sourceStream.on 'error', (error) ->
        done?(error)
        done = null

      destinationStream = fs.createWriteStream(destinationPath)
      destinationStream.on 'error', (error) ->
        done?(error)
        done = null
      destinationStream.on 'close', ->
        done?()
        done = null

      sourceStream.pipe(destinationStream)

  # Public: Create a directory at the specified path including any missing
  # parent directories synchronously.
  makeTree: (directoryPath) ->
    # TODO: rename to makeTreeSync
    mkdirp.sync(directoryPath) if directoryPath and not @exists(directoryPath)

  # Public: Recursively walk the given path and execute the given functions
  # synchronously.
  #
  # * rootPath:
  #   The String containing the directory to recurse into.
  # * onFile:
  #   The function to execute on each file, receives a single argument the
  #   absolute path.
  # * onDirectory:
  #   The function to execute on each directory, receives a single argument the
  #   absolute path (defaults to onFile)
  traverseTreeSync: (rootPath, onFile, onDirectory=onFile) ->
    return unless @isDirectorySync(rootPath)

    traverse = (directoryPath, onFile, onDirectory) ->
      for file in fs.readdirSync(directoryPath)
        childPath = path.join(directoryPath, file)
        stats = fs.lstatSync(childPath)
        if stats.isSymbolicLink()
          if linkStats = fs.statSyncNoException(childPath)
            stats = linkStats
        if stats.isDirectory()
          traverse(childPath, onFile, onDirectory) if onDirectory(childPath)
        else if stats.isFile()
          onFile(childPath)

    traverse(rootPath, onFile, onDirectory)

  # Public: Recursively walk the given path and execute the given functions
  # asynchronously.
  #
  # * rootPath:
  #   The String containing the directory to recurse into.
  # * onFile:
  #   The function to execute on each file, receives a single argument the
  #   absolute path.
  # * onDirectory:
  #   The function to execute on each directory, receives a single argument the
  #   absolute path (defaults to onFile)
  traverseTree: (rootPath, onFile, onDirectory, onDone) ->
    fs.readdir rootPath, (error, files) ->
      if error
        onDone?()
      else
        queue = async.queue (childPath, callback) ->
          fs.stat childPath, (error, stats) ->
            if error
              callback(error)
            else if stats.isFile()
              onFile(childPath)
              callback()
            else if stats.isDirectory()
              if onDirectory(childPath)
                fs.readdir childPath, (error, files) ->
                  if error
                    callback(error)
                  else
                    for file in files
                      queue.unshift(path.join(childPath, file))
                    callback()
              else
                callback()
        queue.concurrency = 1
        queue.drain = onDone
        queue.push(path.join(rootPath, file)) for file in files

  # Public: Hashes the contents of the given file.
  #
  # * pathToDigest:
  #   The String containing the absolute path.
  #
  # Returns a String containing the MD5 hexadecimal hash.
  md5ForPath: (pathToDigest) ->
    contents = fs.readFileSync(pathToDigest)
    require('crypto').createHash('md5').update(contents).digest('hex')

  # Public: Finds a relative path among the given array of paths.
  #
  # * loadPaths:
  #   An Array of absolute and relative paths to search.
  # * pathToResolve:
  #   The string containing the path to resolve.
  # * extensions:
  #   An array of extensions to pass to {resolveExtensions} in which case
  #   pathToResolve should not contain an extension (optional).
  #
  # Returns the absolute path of the file to be resolved if it's found and
  # undefined otherwise.
  resolve: (args...) ->
    extensions = args.pop() if _.isArray(_.last(args))
    pathToResolve = args.pop()
    loadPaths = args

    if process.platform is 'win32'
      isAbsolute = pathToResolve[1] is ':' # C:\ style
    else
      isAbsolute = pathToResolve[0] is '/' # /usr style

    if isAbsolute
      if extensions and resolvedPath = @resolveExtension(pathToResolve, extensions)
        return resolvedPath
      else
        return pathToResolve if @exists(pathToResolve)

    for loadPath in loadPaths
      candidatePath = path.join(loadPath, pathToResolve)
      if extensions
        if resolvedPath = @resolveExtension(candidatePath, extensions)
          return resolvedPath
      else
        return @absolute(candidatePath) if @exists(candidatePath)
    undefined

  # Deprecated:
  resolveOnLoadPath: (args...) ->
    loadPaths = Module.globalPaths.concat(module.paths)
    @resolve(loadPaths..., args...)

  # Public: Finds the first file in the given path which matches the extension
  # in the order given.
  #
  # * pathToResolve:
  #   The String containing relative or absolute path of the file in question
  #   without the extension or '.'.
  # * extensions:
  #   The ordered Array of extensions to try.
  #
  # Returns the absolute path of the file if it exists with any of the given
  # extensions, otherwise it's undefined.
  resolveExtension: (pathToResolve, extensions) ->
    for extension in extensions
      if extension == ""
        return @absolute(pathToResolve) if @exists(pathToResolve)
      else
        pathWithExtension = pathToResolve + "." + extension.replace(/^\./, "")
        return @absolute(pathWithExtension) if @exists(pathWithExtension)
    undefined

  # Public: Returns true for extensions associated with compressed files.
  isCompressedExtension: (ext) ->
    _.indexOf([
      '.gz'
      '.jar'
      '.tar'
      '.tgz'
      '.zip'
    ], ext, true) >= 0

  # Public: Returns true for extensions associated with image files.
  isImageExtension: (ext) ->
    _.indexOf([
      '.gif'
      '.jpeg'
      '.jpg'
      '.png'
      '.tiff'
    ], ext, true) >= 0

  # Public: Returns true for extensions associated with pdf files.
  isPdfExtension: (ext) ->
    ext is '.pdf'

  # Public: Returns true for extensions associated with binary files.
  isBinaryExtension: (ext) ->
    _.indexOf([
      '.DS_Store'
      '.a'
      '.o'
      '.so'
      '.woff'
    ], ext, true) >= 0

  # Public: Returns true for files named similarily to 'README'
  isReadmePath: (readmePath) ->
    extension = path.extname(readmePath)
    base = path.basename(readmePath, extension).toLowerCase()
    base is 'readme' and (extension is '' or @isMarkdownExtension(extension))

  # Private: Used by isReadmePath.
  isMarkdownExtension: (ext) ->
    _.indexOf([
      '.markdown'
      '.md'
      '.mdown'
      '.mkd'
      '.mkdown'
      '.ron'
    ], ext, true) >= 0

  # Public: Reads and returns CSON, JSON or Plist files and returns the
  # corresponding Object.
  readObjectSync: (objectPath) ->
    CSON = require 'season'
    if CSON.isObjectPath(objectPath)
      CSON.readFileSync(objectPath)
    else
      @readPlistSync(objectPath)

  # Public: Reads and returns CSON, JSON or Plist files and calls the specified
  # callback with the corresponding Object.
  readObject: (objectPath, done) ->
    CSON = require 'season'
    if CSON.isObjectPath(objectPath)
      CSON.readFile(objectPath, done)
    else
      @readPlist(objectPath, done)

  # Private: Used by readObjectSync.
  readPlistSync: (plistPath) ->
    plist = require 'plist'
    plist.parseStringSync(@read(plistPath))

  # Private: Used by readObject.
  readPlist: (plistPath, done) ->
    plist = require 'plist'
    fs.readFile plistPath, 'utf8', (error, contents) ->
      if error?
        done(error)
      else
        try
          done(null, plist.parseStringSync(contents))
        catch parseError
          done(parseError)

module.exports = _.extend({}, fs, fsExtensions)
