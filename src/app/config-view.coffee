{View} = require 'space-pen'

module.exports =
class ConfigView extends View
  @content: ->
    @div id: 'config-view', "Config View"

  initialize: ->
    document.title = "Atom Configuration"
