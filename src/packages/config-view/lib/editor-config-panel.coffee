ConfigPanel = require './config-panel'
Editor = require 'editor'

###
# Internal #
###

module.exports =
class EditorConfigPanel extends ConfigPanel
  @content: ->
    @form class: 'form-horizontal', =>
      @fieldset =>
        @legend "Editor Settings"

        @div class: 'control-group', =>
          @label class: 'control-label', "Font Size:"
          @div class: 'controls', =>
            @subview "fontSizeEditor", new Editor(mini: true, attributes: {id: 'editor.fontSize', type: 'int', style: 'width: 4em'})

        @div class: 'control-group', =>
          @label class: 'control-label', "Font Family:"
          @div class: 'controls', =>
            @subview "fontFamilyEditor", new Editor(mini: true, attributes: {id: 'editor.fontFamily', type: 'string'})

        @div class: 'control-group', =>
          @div class: 'controls', =>
            @div class: 'checkbox', =>
              @label for: 'editor.autoIndent', =>
                @input id: 'editor.autoIndent', type: 'checkbox'
                @text 'Auto-Indent'

          @div class: 'controls', =>
            @div class: 'checkbox', =>
              @label for: 'editor.autoIndentOnPaste', =>
                @input id: 'editor.autoIndentOnPaste', type: 'checkbox'
                @text 'Auto-Indent on Paste'

          @div class: 'controls', =>
            @div class: 'checkbox', =>
              @label for: 'editor.normalizeIndentOnPaste', =>
                @input id: 'editor.normalizeIndentOnPaste', type: 'checkbox'
                @text 'Normalize Indent on Paste'

          @div class: 'controls', =>
            @div class: 'checkbox', =>
              @label for: 'editor.showLineNumbers', =>
                @input id: 'editor.showLineNumbers', type: 'checkbox'
                @text 'Show Line Numbers'

          @div class: 'controls', =>
            @div class: 'checkbox', =>
              @label for: 'editor.showInvisibles', =>
                @input id: 'editor.showInvisibles', type: 'checkbox'
                @text 'Show Invisible Characters'

          @div class: 'controls', =>
            @div class: 'checkbox', =>
              @label for: 'editor.showIndentGuide', =>
                @input id: 'editor.showIndentGuide', type: 'checkbox'
                @text 'Show Indent Guide'

        @div class: 'control-group', =>
          @label class: 'control-label', for: 'editor.preferredLineLength', "Preferred Line Length:"
          @div class: 'controls', =>
            @subview "preferredLineLengthEditor", new Editor(mini: true, attributes: {id: 'editor.preferredLineLength', type: 'int', style: 'width: 4em'})

        @div class: 'control-group', =>
          @label class: 'control-label', for: 'editor.nonWordCharacters', "Non-Word Characters:"
          @div class: 'controls', =>
            @subview "nonWordCharactersEditor", new Editor(mini: true, attributes: {id: 'editor.nonWordCharacters', type: 'string'})
