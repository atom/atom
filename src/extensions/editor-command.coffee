module.exports =
class EditorCommand

  @activate: (rootView) ->
    keymaps = @getKeymaps()
    return unless keymaps

    window.keymap.bindKeys '.editor', keymaps

    for editor in rootView.getEditors()
      @subscribeToEditor(rootView, editor)

    rootView.on 'editor-open', (e, editor) =>
      @subscribeToEditor(rootView, editor)

  @subscribeToEditor: (rootView, editor) ->
    keymaps = @getKeymaps(rootView, editor)
    return unless keymaps

    for key, event of keymaps
      do (event) =>
        editor.on event, =>
          @execute(editor, event)

  @replaceSelectedText: (editor, replace) ->
     selection = editor.getSelection()
     return false if selection.isEmpty()

     text = replace(editor.getTextInRange(selection.getBufferRange()))
     return false if text is null or text is undefined

     editor.insertText(text, select: true)
     true
