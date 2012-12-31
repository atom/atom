fs = require("fs")
_ = require 'underscore'

module.exports =
class Theme
  @stylesheets: null

  @load: (name) ->
    TextMateTheme = require 'text-mate-theme'
    AtomTheme = require 'atom-theme'

    if fs.exists(name)
      path = name
    else
      path = fs.resolve(config.themeDirPaths..., name)
      path ?= fs.resolve(config.themeDirPaths..., name + ".tmTheme")

    throw new Error("No theme exists named '#{name}'") unless path

    theme =
      if TextMateTheme.testPath(path)
        new TextMateTheme(path)
      else
        new AtomTheme(path)

    theme.load()
    theme

  constructor: (@path) ->
    @stylesheets = {}

  load: ->
    for stylesheetPath, stylesheetContent of @stylesheets
      applyStylesheet(stylesheetPath, stylesheetContent)

  deactivate: ->
    for stylesheetPath, stylesheetContent of @stylesheets
      removeStylesheet(stylesheetPath)
