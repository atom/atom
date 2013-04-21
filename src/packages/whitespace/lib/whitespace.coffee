module.exports =
  activate: ->
    rootView.eachEditSession (editSession) => @whitespaceBeforeSave(editSession)

  configDefaults:
    ensureSingleTrailingNewline: true

  whitespaceBeforeSave: (editSession) ->
    buffer = editSession.buffer
    buffer.on 'will-be-saved', ->
      buffer.transact ->
        buffer.scan /[ \t]+$/g, ({replace}) -> replace('')

        if config.get('whitespace.ensureSingleTrailingNewline')
          if buffer.getLastLine() is ''
            row = buffer.getLastRow() - 1
            while row and buffer.lineForRow(row) is ''
              buffer.deleteRow(row--)
          else
            selectedBufferRanges = editSession.getSelectedBufferRanges()
            buffer.append('\n')
            editSession.setSelectedBufferRanges(selectedBufferRanges)
