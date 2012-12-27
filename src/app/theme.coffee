fs = require("fs")
plist = require 'plist'
_ = require 'underscore'

module.exports =
class Theme
  @load: (name) ->
    if fs.exists(name)
      path = name
    else
      regex = new RegExp("#{_.escapeRegExp(name)}(\.[^.]*)?$", "i")
      path = _.find fs.list(config.themeDirPath), (path) -> regex.test(path)

    return null unless path

    if @isTextMateTheme(path)
      theme = @loadTextMateTheme(path)
    else
      theme = @loadAtomTheme(path)

    if theme
      theme.activate()
    else
      throw new Error("Cannot activate theme named '#{name}'")

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
    new Theme(path)

  @isTextMateTheme: (path) ->
    /\.(tmTheme|plist)$/.test(path)

  @stylesheets: null

  constructor: (@path) ->
    json = fs.read(fs.join(path, "package.json"))
    @stylesheets = {}
    for stylesheetName in JSON.parse(json).stylesheets
      stylesheetPath = fs.join(@path, stylesheetName)
      @stylesheets[stylesheetPath] = fs.read(stylesheetPath)

  activate: ->
    for stylesheetPath, stylesheetContent of @stylesheets
      applyStylesheet(stylesheetPath, stylesheetContent)

  deactivate: ->
    for stylesheetPath, stylesheetContent of @stylesheets
      window.removeStylesheet(stylesheetPath)