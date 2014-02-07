# Your init script
#
# Atom will evaluate this file each time a new window is opened. It is run
# after packages are loaded/activated and after the previous editor state
# has been restored.
#
# An example hack to make opened Markdown files have larger text:
#
# path = require 'path'
#
# atom.workspaceView.eachEditorView (editorView) ->
#   if path.extname(editorView.getEditor().getPath()) is '.md'
#     editorView.setFontSize(24)
