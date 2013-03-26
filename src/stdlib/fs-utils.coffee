# commonjs fs module
# http://ringojs.org/api/v0.8/fs/

_ = require 'underscore'
fs = require 'fs'
mkdirp = require 'mkdirp'
Module = require 'module'
async = require 'async'

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

  # Return the basename of the given path. That is the path with
  # any leading directory components removed. If specified, also
  # remove a trailing extension.
  base: (path, ext) ->
    base = path.replace(/\/$/, '').split("/").pop()
    if ext then base.replace(RegExp("#{_.escapeRegExp(ext)}$"), '') else base

  # Returns the path of a file's containing directory, albeit the
  # parent directory if the file is a directory. A terminal directory
  # separator is ignored.
  directory: (path) ->
    parentPath = path.replace(new RegExp("/#{@base(_.escapeRegExp(path))}\/?$"), '')
    return "" if path == parentPath
    parentPath

  # Returns true if the file specified by path exists
  exists: (path) ->
    path? and fs.existsSync(path)

  # Returns the extension of a file. The extension of a file is the
  # last dot (excluding any number of initial dots) followed by one or
  # more non-dot characters. Returns an empty string if no valid
  # extension exists.
  extension: (path) ->
    return '' unless typeof path is 'string'
    match = @base(path).match(/\.[^\.]+$/)
    if match
      match[0]
    else
      ""

  join: (paths...) ->
    return paths[0] if paths.length == 1
    [first, rest...] = paths
    first.replace(/\/?$/, "/") + @join(rest...)

  # Returns true if the file specified by path exists and is a
  # directory.
  isDirectory: (path) ->
    return false unless path?.length > 0
    try
      fs.statSync(path).isDirectory()
    catch e
      false

  isDirectoryAsync: (path, done) ->
    return done(false) unless path?.length > 0
    fs.exists path, (exists) ->
      if exists
        fs.stat path, (err, stat) ->
          done(stat?.isDirectory() ? false)
      else
        done(false)

  # Returns true if the file specified by path exists and is a
  # regular file.
  isFile: (path) ->
    return false unless path?.length > 0
    try
      path? and fs.statSync(path).isFile()
    catch e
      false

  # Returns an array with all the names of files contained
  # in the directory path.
  list: (rootPath, extensions) ->
    return unless @isDirectory(rootPath)
    paths = fs.readdirSync(rootPath)
    paths = @filterExtensions(paths, extensions) if extensions
    paths = paths.map (path) => @join(rootPath, path)
    paths

  listAsync: (rootPath, rest...) ->
    extensions = rest.shift() if rest.length > 1
    done = rest.shift()
    fs.readdir rootPath, (err, paths) =>
      return done(err) if err
      paths = @filterExtensions(paths, extensions) if extensions
      paths = paths.map (path) => @join(rootPath, path)
      done(null, paths)

  filterExtensions: (paths, extensions) ->
    extensions = extensions.map (ext) -> '.' + ext.replace(/^\./, '')
    paths.filter (path) => _.include(extensions, @extension(path))

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
  remove: (path) ->
    if @isFile(path)
      fs.unlinkSync(path)
    else if @isDirectory(path)
      removeDirectory = (path) =>
        for entry in fs.readdirSync(path)
          entryPath = @join(path, entry)
          stats = fs.statSync(entryPath)
          if stats.isDirectory()
            removeDirectory(entryPath)
          else if stats.isFile()
            fs.unlinkSync(entryPath)
        fs.rmdirSync(path)
      removeDirectory(path)

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
    mkdirp.sync(@directory(path))
    fs.writeFileSync(path, content)

  makeDirectory: (path) ->
    fs.mkdirSync(path)

  # Creates the directory specified by "path" including any missing parent
  # directories.
  makeTree: (path) ->
    return unless path
    if not @exists(path)
      @makeTree(@directory(path))
      @makeDirectory(path)

  traverseTreeSync: (rootPath, onFile, onDirectory) ->
    return unless @isDirectory(rootPath)

    traverse = (rootPath, prefix, onFile, onDirectory) =>
      prefix  = "#{prefix}/" if prefix
      for file in fs.readdirSync(rootPath)
        relativePath = "#{prefix}#{file}"
        absolutePath = @join(rootPath, file)
        stats = fs.statSync(absolutePath)
        if stats.isDirectory()
          traverse(absolutePath, relativePath, onFile, onDirectory) if onDirectory(absolutePath)
        else if stats.isFile()
          onFile(absolutePath)

    traverse(rootPath, '', onFile, onDirectory)

  traverseTree: (rootPath, onFile, onDirectory, onDone) ->
    fs.readdir rootPath, (error, files) =>
      if error
        onDone()
      else
        queue = async.queue (path, callback) =>
          fs.stat path, (error, stats) =>
            if error
              callback(error)
            else if stats.isFile()
              onFile(path)
              callback()
            else if stats.isDirectory()
              if onDirectory(path)
                fs.readdir path, (error, files) =>
                  if error
                    callback(error)
                  else
                    for file in files
                      queue.unshift(@join(path, file))
                    callback()
              else
                callback()
        queue.concurrency = 1
        queue.drain = onDone
        queue.push(@join(rootPath, file)) for file in files

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
      candidatePath = @join(loadPath, pathToResolve)
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
      '.woff'
    ], ext, true) >= 0

  isReadmePath: (path) ->
    extension = @extension(path)
    base = @base(path, extension).toLowerCase()
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
    cson = require 'cson'
    if cson.isObjectPath(path)
      cson.readObject(path)
    else
      @readPlist(path)

  readObjectAsync: (path, done) ->
    cson = require 'cson'
    if cson.isObjectPath(path)
      cson.readObjectAsync(path, done)
    else
      @readPlistAsync(path, done)

  watchPath: (path, callback) ->
    path = @absolute(path)
    watchCallback = (eventType, eventPath) =>
      path = @absolute(eventPath) if eventType is 'move'
      callback(arguments...)
    id = $native.watchPath(path, watchCallback)
    unwatch: -> $native.unwatchPath(path, id)
