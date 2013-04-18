ConfigPanel = require 'config-panel'
{$$} = require 'space-pen'
$ = require 'jquery'
_ = require 'underscore'

module.exports =
class GeneralConfigPanel extends ConfigPanel
  @content: ->
    @div id: 'general-config-panel', class: 'config-panel', =>
      @div class: 'row', =>
        @label for: 'core.hideGitIgnoredFiles', "Hide files in .gitignore:"
        @input id: 'core.hideGitIgnoredFiles', type: 'checkbox'

      @div class: 'row', =>
        @label for: 'core.autosave', "Autosave on unfocus:"
        @input id: 'core.autosave', type: 'checkbox'

  populateThemeLists: ->
