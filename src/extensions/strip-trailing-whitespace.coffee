module.exports =
  name: "strip trailing whitespace"

  activate: (rootView) ->
    for buffer in rootView.project.getBuffers()
      @stripTrailingWhitespaceBeforeSave(buffer)

    rootView.project.on 'new-buffer', (buffer) =>
      @stripTrailingWhitespaceBeforeSave(buffer)

  stripTrailingWhitespaceBeforeSave: (buffer) ->
    buffer.on 'before-save', ->
      buffer.scan /[ \t]+$/g, (match, range, { replace }) ->
        replace('')
