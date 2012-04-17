module.exports =
  initialize: (rootView) ->
    for buffer in rootView.project.buffers
      @stripTrailingWhitespaceBeforeSave(buffer)

    rootView.project.on 'new-buffer', (buffer) =>
      @stripTrailingWhitespaceBeforeSave(buffer)

  stripTrailingWhitespaceBeforeSave: (buffer) ->
    buffer.on 'before-save', ->
      buffer.scan /\s+$/, (match, range, { replace }) ->
        replace('')
