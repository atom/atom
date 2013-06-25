ConfigPanel = require './config-panel'
{$$} = require 'space-pen'
$ = require 'jquery'
_ = require 'underscore'

###
# Internal #
###

module.exports =
class GeneralConfigPanel extends ConfigPanel
  @content: ->
    @form id: 'general-config-panel', class: 'form-horizontal', =>
      @fieldset =>
        @legend "General Settings"

        @div class: 'control-group', =>
          @div class: 'checkbox', =>
            @label for: 'core.hideGitIgnoredFiles', =>
              @input id: 'core.hideGitIgnoredFiles', type: 'checkbox'
              @text 'Hide Git-Ignored Files'

          @div class: 'checkbox', =>
            @label for: 'core.autosave', =>
              @input id: 'core.autosave', type: 'checkbox'
              @text 'Auto-Save on Focus Change'
