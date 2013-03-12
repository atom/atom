fs = require 'fs-utils'
CoffeeScript = require 'coffee-script'

# Settings file looks like:
#     editor: # name of class
#       theme: "twilight"
#       tabSize: 2
#       softTabs: true
#       showInvisibles: false
#
#     project:
#       ignorePattern: /x|y|z/
#
# Settings are applied to object x's settings variable by calling applyTo(x) on
# instance of Settings.
module.exports =
class Settings
  settings: {}

  load: (path) ->
    path = require.resolve path
    if not fs.isFile path
      console.warn "Could not find settings file '#{path}'"
      return

    try
      json = CoffeeScript.eval "return " + (fs.read path)

      for className, value of json
        @settings[@simplifyClassName className] = value
    catch error
      console.error "Can't evaluate settings at `#{path}`."
      console.error error

  applyTo: (object) ->
    if not object.settings
      console.warning "#{object.constructor.name}: Does not have `settings` varible"
      return

    classHierarchy = []

    # ICK: Using internal var __super to get the build heirarchy
    walker = object
    while walker
      classHierarchy.unshift @simplifyClassName walker.constructor.name
      walker = walker.constructor.__super__

    for className in classHierarchy
      for setting, value of @settings[className] ? {}
        object.settings[setting] = value

  # I don't care if you use camelCase, underscores or dashes. It should all
  # point to the same place
  simplifyClassName: (className) ->
    className.toLowerCase().replace /\W/, ''
