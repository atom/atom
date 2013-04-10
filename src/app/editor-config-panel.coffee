ConfigPanel = require 'config-panel'

module.exports =
class EditorConfigPanel extends ConfigPanel
  @content: ->
    @div class: 'config-panel', =>
      @div class: 'row', =>
        @label for: 'editor.fontSize', "Font Size:"
        @input id: 'editor.fontSize', type: 'int', size: 2

      @div class: 'row', =>
        @label for: 'editor.fontFamily', "Font Family:"
        @input id: 'editor.fontFamily', type: 'string'

      @div class: 'row', =>
        @label for: 'editor.preferredLineLength', "Preferred Line Length:"
        @input name: 'editor.preferredLineLength', type: 'int', size: 2

      @div class: 'row', =>
        @label for: 'editor.autoIndent', "Auto Indent:"
        @input id: 'editor.autoIndent', type: 'checkbox'

      @div class: 'row', =>
        @label for: 'editor.autoIndentOnPaste', "Auto Indent on Paste:"
        @input id: 'editor.autoIndentOnPaste', type: 'checkbox'

      @div class: 'row', =>
        @label for: 'editor.autosave', "Autosave on Unfocus:"
        @input id: 'editor.autosave', type: 'checkbox'

      @div class: 'row', =>
        @label for: 'editor.showInvisibles', "Show Invisible Characters:"
        @input id: 'editor.showInvisibles', type: 'checkbox'
