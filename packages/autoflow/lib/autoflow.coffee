_ = require 'underscore-plus'

CharacterPattern = ///
  [
    ^\s
  ]
///

module.exports =
  activate: ->
    @commandDisposable = atom.commands.add 'atom-text-editor',
      'autoflow:reflow-selection': (event) =>
        @reflowSelection(event.currentTarget.getModel())

  deactivate: ->
    @commandDisposable?.dispose()
    @commandDisposable = null

  reflowSelection: (editor) ->
    range = editor.getSelectedBufferRange()
    range = editor.getCurrentParagraphBufferRange() if range.isEmpty()
    return unless range?

    reflowOptions =
        wrapColumn: @getPreferredLineLength(editor)
        tabLength: @getTabLength(editor)
    reflowedText = @reflow(editor.getTextInRange(range), reflowOptions)
    editor.getBuffer().setTextInRange(range, reflowedText)

  reflow: (text, {wrapColumn, tabLength}) ->
    paragraphs = []
    # Convert all \r\n and \r to \n. The text buffer will normalize them later
    text = text.replace(/\r\n?/g, '\n')

    leadingVerticalSpace = text.match(/^\s*\n/)
    if leadingVerticalSpace
      text = text.substr(leadingVerticalSpace.length)
    else
      leadingVerticalSpace = ''

    trailingVerticalSpace = text.match(/\n\s*$/)
    if trailingVerticalSpace
      text = text.substr(0, text.length - trailingVerticalSpace.length)
    else
      trailingVerticalSpace = ''

    paragraphBlocks = text.split(/\n\s*\n/g)
    if tabLength
      tabLengthInSpaces = Array(tabLength + 1).join(' ')
    else
      tabLengthInSpaces = ''

    for block in paragraphBlocks
      blockLines = block.split('\n')

      # For LaTeX tags surrounding the text, we simply ignore them, and
      # reproduce them verbatim in the wrapped text.
      beginningLinesToIgnore = []
      endingLinesToIgnore = []
      latexTagRegex = /^\s*\\\w+(\[.*\])?\{\w+\}(\[.*\])?\s*$/g    # e.g. \begin{verbatim}
      latexTagStartRegex = /^\s*\\\w+\s*\{\s*$/g                   # e.g. \item{
      latexTagEndRegex = /^\s*\}\s*$/g                             # e.g. }
      while blockLines[0].match(latexTagRegex) or
            blockLines[0].match(latexTagStartRegex)
        beginningLinesToIgnore.push(blockLines[0])
        blockLines.shift()
      while blockLines[blockLines.length - 1].match(latexTagRegex) or
            blockLines[blockLines.length - 1].match(latexTagEndRegex)
        endingLinesToIgnore.unshift(blockLines[blockLines.length - 1])
        blockLines.pop()

      # TODO: this could be more language specific. Use the actual comment char.
      # Remember that `-` has to be the last character in the character class.
      linePrefix = blockLines[0].match(/^\s*(\/\/|\/\*|;;|#'|\|\|\||--|[#%*>-])?\s*/g)[0]
      linePrefixTabExpanded = linePrefix
      linePrefixNew = blockLines[0].match(/\\*%\s*/)
      index = 0
      noInlineComment = false
      if linePrefix
        linePrefixTabExpanded = linePrefix
        if tabLengthInSpaces
          linePrefixTabExpanded = linePrefix.replace(/\t/g, tabLengthInSpaces)
      else if linePrefixNew
        lengthOfSlash = 0
        for num in [0..(linePrefixNew[0].length-1)]
          if linePrefixNew[0].charAt(num) == '%'
            lengthOfSlash = num
            break

        # odd number of slash: not a comment
        if lengthOfSlash %% 2 == 1
          index = block.length
          noInlineComment = true
        else
          index = linePrefixNew["index"] + lengthOfSlash

        # get rid of the first character
        linePrefixNew[0] = linePrefixNew[0][lengthOfSlash..]
        linePrefixTabExpanded = linePrefixNew[0]
        if tabLengthInSpaces
          linePrefixTabExpanded = linePrefixNew[0].replace(/\t/g, tabLengthInSpaces)

      if linePrefix
        escapedLinePrefix = _.escapeRegExp(linePrefix)
        blockLines = blockLines.map (blockLine) ->
          blockLine.replace(///^#{escapedLinePrefix}///, '')

      blockLines = blockLines.map (blockLine) ->
        blockLine.replace(/^\s+/, '')

      lines = []
      currentLine = []
      if linePrefixNew and !linePrefix
        currentLineLength = 0
      else
        currentLineLength = linePrefixTabExpanded.length
      wrappedLinePrefix = linePrefix
        .replace(/^(\s*)\/\*/, '$1  ')
        .replace(/^(\s*)-(?!-)/, '$1 ')

      firstLine = true
      for segment in @segmentText(blockLines.join(' '))
        if @wrapSegment(segment, currentLineLength, wrapColumn)
          if firstLine
            if linePrefixNew and !linePrefix
              lines.push(currentLine.join(''))
            else
              lines.push(linePrefix + currentLine.join(''))
          # Independent of line prefix don't mess with it on the first line
          if firstLine isnt true
            # Handle C comments
            if linePrefix.search(/^\s*\/\*/) isnt -1 or linePrefix.search(/^\s*-(?!-)/) isnt -1
              linePrefix = wrappedLinePrefix
            if linePrefixNew and index <= 0 and !linePrefix
              if currentLine[0] == "%"
                lines.push(linePrefix + currentLine.join(''))
              else
                lines.push(linePrefixNew + currentLine.join(''))
            else
              lines.push(linePrefix + currentLine.join(''))
          currentLine = []
          index -= currentLineLength
          if index <= 0
            currentLineLength = linePrefixTabExpanded.length
          else
            currentLineLength = 0
          firstLine = false
        currentLine.push(segment)
        currentLineLength += segment.length
      if linePrefixNew and index <= 0 and !linePrefix
        lines.push(linePrefixNew + currentLine.join(''))
      else
        lines.push(linePrefix + currentLine.join(''))
      wrappedLines = beginningLinesToIgnore.concat(lines.concat(endingLinesToIgnore))
      paragraphs.push(wrappedLines.join('\n').replace(/\s+\n/g, '\n'))

    leadingVerticalSpace + paragraphs.join('\n\n') + trailingVerticalSpace

  getTabLength: (editor) ->
    atom.config.get('editor.tabLength', scope: editor.getRootScopeDescriptor()) ? 2

  getPreferredLineLength: (editor) ->
    atom.config.get('editor.preferredLineLength', scope: editor.getRootScopeDescriptor())

  wrapSegment: (segment, currentLineLength, wrapColumn) ->
    CharacterPattern.test(segment) and
      (currentLineLength + segment.length > wrapColumn) and
      (currentLineLength > 0 or segment.length < wrapColumn)

  segmentText: (text) ->
    segments = []
    re = /[\s]+|[^\s]+/g
    segments.push(match[0]) while match = re.exec(text)
    segments
