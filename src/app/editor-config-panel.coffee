ConfigPanel = require 'config-panel'

module.exports =
class EditorConfigPanel extends ConfigPanel
  @content: ->
    @form class: 'form-horizontal', =>
      @fieldset =>
        @legend "Editor Settings"

        @div class: 'control-group', =>
          @label class: 'control-label', for: 'editor.fontSize', "Font Size:"
          @div class: 'controls', =>
            @input id: 'editor.fontSize', type: 'int', style: 'width: 40px'

        @div class: 'control-group', =>
          @label class: 'control-label', for: 'editor.fontFamily', "Font Family:"
          @div class: 'controls', =>
            @input id: 'editor.fontFamily', type: 'string', style: 'width: 150px'

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
              @label for: 'editor.showLineNumbers', =>
                @input id: 'editor.showLineNumbers', type: 'checkbox'
                @text 'Show Line Numbers'

          @div class: 'controls', =>
            @div class: 'checkbox', =>
              @label for: 'editor.showInvisibles', =>
                @input id: 'editor.showInvisibles', type: 'checkbox'
                @text 'Show Invisible Characters'

        @div class: 'control-group', =>
          @label class: 'control-label', for: 'editor.preferredLineLength', "Preferred Line Length:"
          @div class: 'controls', =>
            @input id: 'editor.preferredLineLength', type: 'int', style: 'width: 40px'

        @div class: 'control-group', =>
          @label class: 'control-label', for: 'editor.nonWordCharacters', "Non-Word Characters:"
          @div class: 'controls', =>
            @input id: 'editor.nonWordCharacters', type: 'int'
