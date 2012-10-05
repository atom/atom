module.exports =
class EditorCommand

  @activate: (rootView) ->
    for editor in rootView.getEditors()
      @onEditor(editor)

    rootView.on 'editor-open', (e, editor) =>
      @onEditor(editor)

  @register: (editor, key, event, callback) ->
    binding = {}
    binding[key] = event
    window.keymap.bindKeys '.editor', binding
    editor.on event, =>
      callback(editor, event)

  @replaceSelectedText: (editor, replace) ->
     selection = editor.getSelection()
     return false if selection.isEmpty()

     text = replace(editor.getTextInRange(selection.getBufferRange()))
     return false if text is null or text is undefined

     editor.insertText(text, select: true)
     true
