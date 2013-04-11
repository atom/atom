ConfigPanel = require 'config-panel'

module.exports =
class GeneralConfigPanel extends ConfigPanel
  @content: ->
    @div class: 'config-panel', =>
      @div class: 'row', =>
        @label for: 'core.hideGitIgnoredFiles', "Hide files in .gitignore:"
        @input id: 'core.hideGitIgnoredFiles', type: 'checkbox'

      @div class: 'row', =>
        @label for: 'core.autosave', "Autosave on unfocus:"
        @input id: 'core.autosave', type: 'checkbox'
