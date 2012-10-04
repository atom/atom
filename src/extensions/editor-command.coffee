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
      editor.on event, => @execute(editor, event)

  @replaceSelectedText: (editor, replace) ->
     selection = editor.getSelection()
     return false if selection.isEmpty()

     range = selection.getBufferRange()
     reverse = selection.isReversed()
     text = replace(editor.getTextInRange(range))
     return false if text is null or text is undefined
     editor.insertText(text)
     selection.setBufferRange(range, {reverse})
     true
