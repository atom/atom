ConfigPanel = require 'config-panel'

module.exports =
class GeneralConfigPanel extends ConfigPanel
  @content: ->
    @div class: 'config-panel', =>
      @div class: 'row', =>
        @label for: 'core.autosave', "Autosave on Unfocus:"
        @input id: 'core.autosave', type: 'checkbox'
