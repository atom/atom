_ = require 'underscore'
fs = require 'fs'
mkdirp = require 'mkdirp'
Module = require 'module'
async = require 'async'
rimraf = require 'rimraf'
Path = require 'path'

module.exports =
  # Make the given path absolute by resolving it against the
  # current working directory.
  absolute: (path) ->
    return null unless path?

    if path.indexOf('~/') is 0
      if process.platform is 'win32'
        home = process.env.USERPROFILE
      else
        home = process.env.HOME
      path = "#{home}#{path.substring(1)}"
    try
      fs.realpathSync(path)
    catch e
      path

  # Returns true if the file specified by path exists
  exists: (path) ->
    path? and fs.existsSync(path)

  # Returns true if the file specified by path exists and is a
  # directory.
  isDirectorySync: (path) ->
    return false unless path?.length > 0
    try
      fs.statSync(path).isDirectory()
    catch e
      false

  isDirectory: (path, done) ->
    return done(false) unless path?.length > 0
    fs.exists path, (exists) ->
      if exists
        fs.stat path, (error, stat) ->
          if error?
            done(false)
          else
            done(stat.isDirectory())
      else
        done(false)

  # Returns true if the file specified by path exists and is a
  # regular file.
  isFileSync: (path) ->
    return false unless path?.length > 0
    try
      path? and fs.statSync(path).isFile()
    catch e
      false

  # Returns true if the specified path is exectuable.
  isExecutable: (path) ->
    try
      (fs.statSync(path).mode & 0o777 & 1) isnt 0
    catch e
      false

  # Returns an array with all the names of files contained
  # in the directory path.
  list: (rootPath, extensions) ->
    return [] unless @isDirectorySync(rootPath)
    paths = fs.readdirSync(rootPath)
    paths = @filterExtensions(paths, extensions) if extensions
    paths = paths.map (path) -> Path.join(rootPath, path)
    paths

  listAsync: (rootPath, rest...) ->
    extensions = rest.shift() if rest.length > 1
    done = rest.shift()
    fs.readdir rootPath, (err, paths) =>
      return done(err) if err
      paths = @filterExtensions(paths, extensions) if extensions
      paths = paths.map (path) -> Path.join(rootPath, path)
      done(null, paths)

  filterExtensions: (paths, extensions) ->
    extensions = extensions.map (ext) ->
      if ext is ''
        ext
      else
        '.' + ext.replace(/^\./, '')
    paths.filter (path) -> _.include(extensions, Path.extname(path))

  listTree: (rootPath) ->
    paths = []
    onPath = (path) =>
      paths.push(path)
      true
    @traverseTreeSync(rootPath, onPath, onPath)
    paths

  move: (source, target) ->
    fs.renameSync(source, target)

  # Remove a file at the given path. Throws an error if path is not a
  # file or a symbolic link to a file.
  remove: (pathToRemove) ->
    rimraf.sync(pathToRemove)

  # Open, read, and close a file, returning the file's contents.
  read: (path) ->
    String fs.readFileSync(path)

  # Returns an array of path components. If the path is absolute, the first
  # component will be an indicator of the root of the file system; for file
  # systems with drives (such as Windows), this is the drive identifier with a
  # colon, like "c:"; on Unix, this is an empty string "". The intent is that
  # calling "join.apply" with the result of "split" as arguments will
  # reconstruct the path.
  split: (path) ->
    path.split("/")

  # Open, write, flush, and close a file, writing the given content.
  write: (path, content) ->
    mkdirp.sync(Path.dirname(path))
    fs.writeFileSync(path, content)

  writeAsync: (path, content, callback) ->
    mkdirp Path.dirname(path), (error) ->
      if error?
        callback?(error)
      else
        fs.writeFile(path, content, callback)

  makeDirectory: (path) ->
    fs.mkdirSync(path)

  copy: (sourcePath, destinationPath, done) ->
    mkdirp Path.dirname(destinationPath), (error) ->
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

  # Creates the directory specified by "path" including any missing parent
  # directories.
  makeTree: (path) ->
    return unless path
    if not @exists(path)
      @makeTree(Path.dirname(path))
      @makeDirectory(path)

  traverseTreeSync: (rootPath, onFile, onDirectory) ->
    return unless @isDirectorySync(rootPath)

    traverse = (rootPath, prefix, onFile, onDirectory) ->
      prefix  = "#{prefix}/" if prefix
      for file in fs.readdirSync(rootPath)
        relativePath = "#{prefix}#{file}"
        absolutePath = Path.join(rootPath, file)
        stats = fs.statSync(absolutePath)
        if stats.isDirectory()
          traverse(absolutePath, relativePath, onFile, onDirectory) if onDirectory(absolutePath)
        else if stats.isFile()
          onFile(absolutePath)

    traverse(rootPath, '', onFile, onDirectory)

  traverseTree: (rootPath, onFile, onDirectory, onDone) ->
    fs.readdir rootPath, (error, files) ->
      if error
        onDone?()
      else
        queue = async.queue (path, callback) ->
          fs.stat path, (error, stats) ->
            if error
              callback(error)
            else if stats.isFile()
              onFile(path)
              callback()
            else if stats.isDirectory()
              if onDirectory(path)
                fs.readdir path, (error, files) ->
                  if error
                    callback(error)
                  else
                    for file in files
                      queue.unshift(Path.join(path, file))
                    callback()
              else
                callback()
        queue.concurrency = 1
        queue.drain = onDone
        queue.push(Path.join(rootPath, file)) for file in files

  md5ForPath: (path) ->
    contents = fs.readFileSync(path)
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
      candidatePath = Path.join(loadPath, pathToResolve)
      if extensions
        if resolvedPath = @resolveExtension(candidatePath, extensions)
          return resolvedPath
      else
        return @absolute(candidatePath) if @exists(candidatePath)
    undefined

  resolveOnLoadPath: (args...) ->
    loadPaths = Module.globalPaths.concat(module.paths)
    @resolve(loadPaths..., args...)

  resolveExtension: (path, extensions) ->
    for extension in extensions
      if extension == ""
        return @absolute(path) if @exists(path)
      else
        pathWithExtension = path + "." + extension.replace(/^\./, "")
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

  isReadmePath: (path) ->
    extension = Path.extname(path)
    base = Path.basename(path, extension).toLowerCase()
    base is 'readme' and (extension is '' or @isMarkdownExtension(extension))

  readPlist: (path) ->
    plist = require 'plist'
    plist.parseStringSync(@read(path))

  readPlistAsync: (path, done) ->
    plist = require 'plist'
    fs.readFile path, 'utf8', (err, contents) ->
      return done(err) if err
      try
        done(null, plist.parseStringSync(contents))
      catch err
        done(err)

  readObject: (path) ->
    CSON = require 'season'
    if CSON.isObjectPath(path)
      CSON.readFileSync(path)
    else
      @readPlist(path)

  readObjectAsync: (path, done) ->
    CSON = require 'season'
    if CSON.isObjectPath(path)
      CSON.readFile(path, done)
    else
      @readPlistAsync(path, done)
