fs = require("fs")
plist = require 'plist'
_ = require 'underscore'

module.exports =
class Theme
  @stylesheets: null

  @load: (names) ->
    if typeof(names) == "string"
      [@loadTheme(names)]
    else
      names.map (name) => @loadTheme(name)

  @loadTheme: (name) ->
    if fs.exists(name)
      path = name
    else
      path = fs.resolve(config.themeDirPaths..., name)
      path ?= fs.resolve(config.themeDirPaths..., name + ".tmTheme")

    if @isTextMateTheme(path)
      theme = @loadTextMateTheme(path)
    else
      theme = @loadAtomTheme(path)

    throw new Error("Cannot activate theme named '#{name}' located at '#{path}'") unless theme
    theme.activate()
    theme

  @loadTextMateTheme: (path) ->
    TextMateTheme = require("text-mate-theme")
    plistString = fs.read(path)
    theme = null
    plist.parseString plistString, (err, data) ->
      throw new Error("Error loading theme at '#{path}': #{err}") if err
      theme = new TextMateTheme(path, data[0])
    theme

  @loadAtomTheme: (path) ->
    AtomTheme = require('atom-theme')
    new AtomTheme(path)

  @isTextMateTheme: (path) ->
    /\.(tmTheme|plist)$/.test(path)

  constructor: (@path) ->
    @stylesheets = {}

  activate: ->
    for stylesheetPath, stylesheetContent of @stylesheets
      applyStylesheet(stylesheetPath, stylesheetContent)

  deactivate: ->
    for stylesheetPath, stylesheetContent of @stylesheets
      window.removeStylesheet(stylesheetPath)