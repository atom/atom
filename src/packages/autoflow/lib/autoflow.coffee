module.exports =
  activate: ->
    rootView.eachEditor (editor) =>
      return unless editor.attached and editor.getPane()?
      editor.command 'autoflow:reflow-paragraph', (e) =>
        @reflowParagraph(e.currentTargetView())

  reflowParagraph: (editor) ->
    if range = editor.getCurrentParagraphBufferRange()
      wrapColumn = config.getPositiveInt('editor.preferredLineLength', 80)
      editor.getBuffer().change(range, @reflow(editor.getTextInRange(range), {wrapColumn}))

  reflow: (text, {wrapColumn}) ->
    paragraphs = []

    paragraphBlocks = text.split(/\n\s*\n/g)

    for block in paragraphBlocks
      lines = []
      currentLine = []
      currentLineLength = 0

      for segment in @segmentText(block.replace(/\n/g, ' '))
        if @wrapSegment(segment, currentLineLength, wrapColumn)
          lines.push(currentLine.join(''))
          currentLine = []
          currentLineLength = 0
        currentLine.push(segment)
        currentLineLength += segment.length

      lines.push(currentLine.join(''))

      paragraphs.push(lines.join('\n').replace(/\s+\n/g, '\n'))

    paragraphs.join('\n\n')

  wrapSegment: (segment, currentLineLength, wrapColumn) ->
    /\w/.test(segment) and
      (currentLineLength + segment.length > wrapColumn) and
      (currentLineLength > 0 or segment.length < wrapColumn)

  segmentText: (text) ->
    segments = []
    re = /[\s]+|[^\s]+/g
    segments.push(match[0]) while match = re.exec(text)
    segments
