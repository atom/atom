module.exports =
  activate: ->
    rootView.eachBuffer (buffer) => @whitespaceBeforeSave(buffer)

  whitespaceBeforeSave: (buffer) ->
    buffer.on 'will-be-saved', ->
      buffer.transact ->
        buffer.scan /[ \t]+$/g, (match, range, { replace }) -> replace('')

        if config.get('whitespace.singleTrailingNewline')
          if buffer.getLastLine() is ''
            row = buffer.getLastRow() - 1
            while row and buffer.lineForRow(row) is ''
              buffer.deleteRow(row--)
          else
            buffer.append('\n')
