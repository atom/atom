fs = require 'fs'
Theme = require 'theme'

module.exports =
class AtomTheme extends Theme

  loadStylesheet: (stylesheetPath)->
    @stylesheets[stylesheetPath] = fs.read(stylesheetPath)

  load: ->
    if /\.css$/.test(@path)
      @loadStylesheet @path
    else
      json = fs.read(fs.join(@path, "package.json"))
      for stylesheetName in JSON.parse(json).stylesheets
        stylesheetPath = fs.join(@path, stylesheetName)
        @loadStylesheet stylesheetPath
    super
