_ = require 'underscore'
fs = require 'fs'
mkdirp = require 'mkdirp'
Module = require 'module'
async = require 'async'
rimraf = require 'rimraf'
path = require 'path'

module.exports =
  # Make the given path absolute by resolving it against the
  # current working directory.
  absolute: (relativePath) ->
    return null unless relativePath?

    if relativePath is '~'
      relativePath = process.env.HOME
    else if relativePath.indexOf('~/') is 0
      relativePath = "#{process.env.HOME}#{relativePath.substring(1)}"

    try
      fs.realpathSync(relativePath)
    catch e
      relativePath

  # Returns true if a file or folder at the specified path exists.
  exists: (pathToCheck) ->
    pathToCheck? and fs.existsSync(pathToCheck)

  # Returns true if the specified path is a directory that exists.
  isDirectorySync: (directoryPath) ->
    return false unless directoryPath?.length > 0
    try
      fs.statSync(directoryPath).isDirectory()
    catch e
      false

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

  # Returns true if the specified path is a regular file that exists.
  isFileSync: (filePath) ->
    return false unless filePath?.length > 0
    try
      fs.statSync(filePath).isFile()
    catch e
      false

  # Returns true if the specified path is executable.
  isExecutableSync: (pathToCheck) ->
    return false unless pathToCheck?.length > 0
    try
      (fs.statSync(pathToCheck).mode & 0o777 & 1) isnt 0
    catch e
      false

  # Returns an array with the paths of the files and folders
  # contained in the directory path.
  listSync: (rootPath, extensions) ->
    return [] unless @isDirectorySync(rootPath)
    paths = fs.readdirSync(rootPath)
    paths = @filterExtensions(paths, extensions) if extensions
    paths = paths.map (childPath) -> path.join(rootPath, childPath)
    paths

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

  filterExtensions: (paths, extensions) ->
    extensions = extensions.map (ext) ->
      if ext is ''
        ext
      else
        '.' + ext.replace(/^\./, '')
    paths.filter (pathToCheck) -> _.include(extensions, path.extname(pathToCheck))

  listTreeSync: (rootPath) ->
    paths = []
    onPath = (childPath) ->
      paths.push(childPath)
      true
    @traverseTreeSync(rootPath, onPath, onPath)
    paths

  move: (source, target) ->
    fs.renameSync(source, target)

  # Remove the file or directory at the given path.
  remove: (pathToRemove) ->
    rimraf.sync(pathToRemove)

  # Open, read, and close a file, returning the file's contents.
  read: (filePath) ->
    fs.readFileSync(filePath, 'utf8')

  # Open, write, flush, and close a file, writing the given content.
  writeSync: (filePath, content) ->
    mkdirp.sync(path.dirname(filePath))
    fs.writeFileSync(filePath, content)

  write: (filePath, content, callback) ->
    mkdirp path.dirname(filePath), (error) ->
      if error?
        callback?(error)
      else
        fs.writeFile(filePath, content, callback)

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

  # Create a directory at the specified path including any missing parent
  # directories.
  makeTree: (directoryPath) ->
    mkdirp.sync(directoryPath) if directoryPath and not @exists(directoryPath)

  traverseTreeSync: (rootPath, onFile, onDirectory=onFile) ->
    return unless @isDirectorySync(rootPath)

    traverse = (directoryPath, onFile, onDirectory) ->
      for file in fs.readdirSync(directoryPath)
        childPath = path.join(directoryPath, file)
        stats = fs.lstatSync(childPath)
        if stats.isSymbolicLink()
          try
            stats = fs.statSync(childPath)
        if stats.isDirectory()
          traverse(childPath, onFile, onDirectory) if onDirectory(childPath)
        else if stats.isFile()
          onFile(childPath)

    traverse(rootPath, onFile, onDirectory)

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

  md5ForPath: (pathToDigest) ->
    contents = fs.readFileSync(pathToDigest)
    require('crypto').createHash('md5').update(contents).digest('hex')

  resolve: (args...) ->
    extensions = args.pop() if _.isArray(_.last(args))
    pathToResolve = args.pop()
    loadPaths = args

    if pathToResolve[0] is '/'
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

  resolveOnLoadPath: (args...) ->
    loadPaths = Module.globalPaths.concat(module.paths)
    @resolve(loadPaths..., args...)

  resolveExtension: (pathToResolve, extensions) ->
    for extension in extensions
      if extension == ""
        return @absolute(pathToResolve) if @exists(pathToResolve)
      else
        pathWithExtension = pathToResolve + "." + extension.replace(/^\./, "")
        return @absolute(pathWithExtension) if @exists(pathWithExtension)
    undefined

  isCompressedExtension: (ext) ->
    _.indexOf([
      '.gz'
      '.jar'
      '.tar'
      '.tgz'
      '.zip'
    ], ext, true) >= 0

  isImageExtension: (ext) ->
    _.indexOf([
      '.gif'
      '.jpeg'
      '.jpg'
      '.png'
      '.tiff'
    ], ext, true) >= 0

  isPdfExtension: (ext) ->
    ext is '.pdf'

  isMarkdownExtension: (ext) ->
    _.indexOf([
      '.markdown'
      '.md'
      '.mdown'
      '.mkd'
      '.mkdown'
      '.ron'
    ], ext, true) >= 0

  isBinaryExtension: (ext) ->
    _.indexOf([
      '.DS_Store'
      '.a'
      '.o'
      '.so'
      '.woff'
    ], ext, true) >= 0

  isReadmePath: (readmePath) ->
    extension = path.extname(readmePath)
    base = path.basename(readmePath, extension).toLowerCase()
    base is 'readme' and (extension is '' or @isMarkdownExtension(extension))

  readPlistSync: (plistPath) ->
    plist = require 'plist'
    plist.parseStringSync(@read(plistPath))

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

  readObjectSync: (objectPath) ->
    CSON = require 'season'
    if CSON.isObjectPath(objectPath)
      CSON.readFileSync(objectPath)
    else
      @readPlistSync(objectPath)

  readObject: (objectPath, done) ->
    CSON = require 'season'
    if CSON.isObjectPath(objectPath)
      CSON.readFile(objectPath, done)
    else
      @readPlist(objectPath, done)
