fs = require 'fs'
Theme = require 'theme'

module.exports =
class AtomTheme extends Theme
  load: ->
    json = fs.read(fs.join(@path, "package.json"))
    for stylesheetName in JSON.parse(json).stylesheets
      stylesheetPath = fs.join(@path, stylesheetName)
      @stylesheets[stylesheetPath] = fs.read(stylesheetPath)
    super
