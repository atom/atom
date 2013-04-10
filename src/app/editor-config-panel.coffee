{View} = require 'space-pen'

module.exports =
class EditorConfigPanel extends View
  @content: ->
    @div class: 'config-panel', =>
      @div class: 'row', =>
        @label for: 'editor.fontSize', "Font Size:"
        @input name: 'editor.fontSize', size: 2

      @div class: 'row', =>
        @label for: 'editor.fontFamily', "Font Family:"
        @input name: 'editor.fontFamily'
