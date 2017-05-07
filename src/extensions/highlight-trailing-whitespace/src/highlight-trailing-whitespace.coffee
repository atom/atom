module.exports =
  name: "highlight trailing whitespace"

  activate: (rootView) ->
    for buffer in rootView.project.getBuffers()
      @highlightTrailingWhitespace(buffer)

    rootView.project.on 'new-buffer', (buffer) =>
      @highlightTrailingWhitespace(buffer)

  deactivate: (rootView) ->
    for buffer in rootView.project.getBuffers()
      @dehighlightTrailingWhitespace(buffer)

  highlightTrailingWhitespace: (buffer) ->
    # get the buffer's editor
    # find all lines with trailing whitespace /[ \t]+$/g
    # update their html to wrap trailing whitespace in span.whitespace

  dehighlightTrailingWhitespace: (buffer) ->
    # find all span.whitespace, replace with just text of span