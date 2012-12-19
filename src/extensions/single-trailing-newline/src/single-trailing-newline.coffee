module.exports =
  name: "Add a single trailing newline"

  activate: (rootView) ->
    for buffer in rootView.project.getBuffers()
      @addSingleTrailingNewlineBeforeSave(buffer)

    rootView.project.on 'new-buffer', (buffer) =>
      @addSingleTrailingNewlineBeforeSave(buffer)

  addSingleTrailingNewlineBeforeSave: (buffer) ->
    buffer.on 'before-save', ->
      if buffer.getLastLine() is ''
        row = buffer.getLastRow()
        while row and buffer.lineForRow(--row) is ''
          buffer.deleteRow(row)
      else
        buffer.append('\n')
