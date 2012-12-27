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
      throw new Error("I only know how to load textmate themes!")

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

  @isTextMateTheme: (path) ->
    /\.(tmTheme|plist)$/.test(path)

  constructor: (@path) ->

  activate: ->
    applyStylesheet(@path, @getStylesheet())

  getStylesheet: ->
    fs.read(@path)