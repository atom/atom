fs = require 'fs'
path = require 'path'
_ = require 'underscore'
Git = require 'git'

class PathLoader
  asyncCallsInProgress: 0
  pathsChunkSize: 100
  paths: []
  repo: null
  rootPath: null
  ignoredNames: null

  constructor: (@rootPath, ignoreVcsIgnores=false, @ignoredNames=[]) ->
    @repo = Git.open(@rootPath, refreshOnWindowFocus: false) if ignoreVcsIgnores
    @ignoredNames.sort()

  isIgnored: (loadedPath) ->
    @repo?.isPathIgnored(loadedPath) or _.indexOf(@ignoredNames, path.basename(loadedPath), true) isnt -1

  asyncCallStarting: ->
    @asyncCallsInProgress++

  asyncCallDone: ->
    if --@asyncCallsInProgress is 0
      @repo?.destroy()
      callTaskMethod('pathsLoaded', @paths)
      callTaskMethod('pathLoadingComplete')

  pathLoaded: (path) ->
    @paths.push(path) unless @isIgnored(path)
    if @paths.length is @pathsChunkSize
      callTaskMethod('pathsLoaded', @paths)
      @paths = []

  loadPath: (path) ->
    @asyncCallStarting()
    fs.lstat path, (error, stats) =>
      unless error?
        if stats.isSymbolicLink()
          @asyncCallStarting()
          fs.stat path, (error, stats) =>
            unless error?
              @pathLoaded(path) if stats.isFile()
            @asyncCallDone()
        else if stats.isDirectory()
          @loadFolder(path) unless @isIgnored(path)
        else if stats.isFile()
          @pathLoaded(path)
      @asyncCallDone()

  loadFolder: (folderPath) ->
    @asyncCallStarting()
    fs.readdir folderPath, (error, children=[]) =>
      @loadPath(path.join(folderPath, childName)) for childName in children
      @asyncCallDone()

  load: ->
    @loadFolder(@rootPath)

module.exports =
  loadPaths: (rootPath, ignoreVcsIgnores, ignoredNames) ->
    pathLoader = new PathLoader(rootPath, ignoreVcsIgnores, ignoredNames)
    pathLoader.load()
