fs = require 'fs'
Theme = require 'theme'

module.exports =
class AtomTheme extends Theme
  constructor: (@path) ->
    super
    json = fs.read(fs.join(path, "package.json"))
    for stylesheetName in JSON.parse(json).stylesheets
      stylesheetPath = fs.join(@path, stylesheetName)
      @stylesheets[stylesheetPath] = fs.read(stylesheetPath)
