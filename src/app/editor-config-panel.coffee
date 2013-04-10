ConfigPanel = require 'config-panel'

module.exports =
class EditorConfigPanel extends ConfigPanel
  @content: ->
    @div class: 'config-panel', =>
      @div class: 'row', =>
        @label for: 'editor.fontSize', "Font Size:"
        @input name: 'editor.fontSize', type: 'integer', size: 2

      @div class: 'row', =>
        @label for: 'editor.fontFamily', "Font Family:"
        @input name: 'editor.fontFamily', type: 'string'
