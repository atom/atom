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

      # TODO: this could be more language specific. Use the actual comment char.
      linePrefix = block.match(/^\s*[\/#*-]*\s*/g)[0]
      blockLines = block.split('\n')
      blockLines = (blockLine.replace(new RegExp('^'+linePrefix), '') for blockLine in blockLines) if linePrefix

      lines = []
      currentLine = []
      currentLineLength = linePrefix.length

      for segment in @segmentText(blockLines.join(' '))
        if @wrapSegment(segment, currentLineLength, wrapColumn)
          lines.push(linePrefix + currentLine.join(''))
          currentLine = []
          currentLineLength = linePrefix.length
        currentLine.push(segment)
        currentLineLength += segment.length
      lines.push(linePrefix + currentLine.join(''))

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
