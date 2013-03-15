# commonjs fs module
# http://ringojs.org/api/v0.8/fs/

_ = require 'underscore'

module.exports =
  # Make the given path absolute by resolving it against the
  # current working directory.
  absolute: (path) ->
    $native.absolute(path)

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
    return false unless path?
    $native.exists(path)

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
    $native.isDirectory path

  # Returns true if the file specified by path exists and is a
  # regular file.
  isFile: (path) ->
    return false unless path?
    $native.isFile(path)

  # Returns an array with all the names of files contained
  # in the directory path.
  list: (rootPath, extensions) ->
    paths = []
    if extensions
      onPath = (path) =>
        paths.push(path) if _.contains(extensions, @extension(path))
        false
    else
      onPath = (path) =>
        paths.push(path)
        false
    @traverseTree(rootPath, onPath, onPath)
    paths

  listTree: (rootPath) ->
    paths = []
    onPath = (path) =>
      paths.push(path)
      true
    @traverseTree(rootPath, onPath, onPath)
    paths

  move: (source, target) ->
    $native.move(source, target)

  # Remove a file at the given path. Throws an error if path is not a
  # file or a symbolic link to a file.
  remove: (path) ->
    $native.remove path

  # Open, read, and close a file, returning the file's contents.
  read: (path) ->
    $native.read(path)

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
    $native.write(path, content)

  makeDirectory: (path) ->
    $native.makeDirectory(path)

  # Creates the directory specified by "path" including any missing parent
  # directories.
  makeTree: (path) ->
    return unless path
    if not @exists(path)
      @makeTree(@directory(path))
      @makeDirectory(path)

  getAllFilePathsAsync: (rootPath, callback) ->
    $native.getAllFilePathsAsync(rootPath, callback)

  traverseTree: (rootPath, onFile, onDirectory) ->
    $native.traverseTree(rootPath, onFile, onDirectory)

  lastModified: (path) ->
    $native.lastModified(path)

  md5ForPath: (path) ->
    $native.md5ForPath(path)

  resolve: (args...) ->
    extensions = args.pop() if _.isArray(_.last(args))
    pathToResolve = args.pop()
    loadPaths = args

    for loadPath in loadPaths
      candidatePath = @join(loadPath, pathToResolve)
      if extensions
        if resolvedPath = @resolveExtension(candidatePath, extensions)
          return resolvedPath
      else
        return candidatePath if @exists(candidatePath)
    undefined

  resolveExtension: (path, extensions) ->
    for extension in extensions
      if extension == ""
        return path if @exists(path)
      else
        pathWithExtension = path + "." + extension.replace(/^\./, "")
        return pathWithExtension if @exists(pathWithExtension)
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

  isObjectPath: (path) ->
    extension = @extension(path)
    extension is '.cson' or extension is '.json'

  readObject: (path) ->
    contents = @read(path)
    if @extension(path) is '.cson'
      {CoffeeScript} = require 'coffee-script'
      CoffeeScript.eval(contents, bare: true)
    else
      JSON.parse(contents)

  writeObject: (path, object) ->
    if @extension(path) is '.cson'
      CSON = require 'cson'
      content = CSON.stringify(object)
    else
      content = JSON.stringify(object, undefined, 2)
    @write(path, "#{content}\n")

  readPlist: (path) ->
    plist = require 'plist'
    object = null
    plist.parseString @read(path), (e, data) ->
      throw new Error(e) if e
      object = data[0]
    object
