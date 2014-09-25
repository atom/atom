{times, random} = require 'underscore-plus'
randomWords = require 'random-words'
TextBuffer = require 'text-buffer'
TextEditor = require '../src/text-editor'

describe "TextEditor", ->
  [editor, tokenizedBuffer, buffer, steps, previousSteps] = []

  softWrapColumn = 80

  beforeEach ->
    atom.config.set('editor.softWrapAtPreferredLineLength', true)
    atom.config.set('editor.preferredLineLength', softWrapColumn)

  it "properly renders soft-wrapped lines when randomly mutated", ->
    previousSteps = JSON.parse(localStorage.steps ? '[]')

    times 10, (i) ->
      buffer = new TextBuffer
      editor = new TextEditor({buffer})
      editor.setEditorWidthInChars(80)
      tokenizedBuffer = editor.displayBuffer.tokenizedBuffer
      steps = []

      times 30, ->
        randomlyMutateEditor()
        verifyLines()

  verifyLines = ->
    {bufferRows, screenLines} = getReferenceScreenLines()
    for referenceBufferRow, screenRow in bufferRows
      referenceScreenLine = screenLines[screenRow]
      actualBufferRow = editor.bufferRowForScreenRow(screenRow)
      unless actualBufferRow is referenceBufferRow
        logLines()
        throw new Error("Invalid buffer row #{actualBufferRow} for screen row #{screenRow}", )

      actualScreenLine = editor.tokenizedLineForScreenRow(screenRow)
      unless actualScreenLine.text is referenceScreenLine.text
        logLines()
        throw new Error("Invalid line text at screen row #{screenRow}")

  logLines = ->
    console.log "==== screen lines ===="
    editor.logScreenLines()
    console.log "==== reference lines ===="
    {bufferRows, screenLines} = getReferenceScreenLines()
    for bufferRow, screenRow in bufferRows
      console.log screenRow, bufferRow, screenLines[screenRow].text

  randomlyMutateEditor = ->
    if Math.random() < .2
      softWrapped = not editor.isSoftWrapped()
      steps.push(['setSoftWrapped', softWrapped])
      editor.setSoftWrapped(softWrapped)
    else
      range = getRandomRange()
      text = getRandomText()
      steps.push(['setTextInBufferRange', range, text])
      editor.setTextInBufferRange(range, text)

  getRandomRange = ->
    startRow = random(0, buffer.getLastRow())
    startColumn = random(0, buffer.lineForRow(startRow).length)
    endRow = random(startRow, buffer.getLastRow())
    endColumn = random(0, buffer.lineForRow(endRow).length)
    [[startRow, startColumn], [endRow, endColumn]]

  getRandomText = ->
    text = []
    max = buffer.getText().split(/\s/).length * 0.75

    times random(5, max), ->
      if Math.random() < .1
        text += '\n'
      else
        text += " " if /\w$/.test(text)
        text += randomWords(exactly: 1)
    text

  getReferenceScreenLines = ->
    if editor.isSoftWrapped()
      screenLines = []
      bufferRows = []
      for bufferRow in [0..tokenizedBuffer.getLastRow()]
        for screenLine in softWrapLine(tokenizedBuffer.tokenizedLineForRow(bufferRow))
          screenLines.push(screenLine)
          bufferRows.push(bufferRow)
    else
      screenLines = tokenizedBuffer.tokenizedLines.slice()
      bufferRows = [0..tokenizedBuffer.getLastRow()]
    {screenLines, bufferRows}

  softWrapLine = (tokenizedLine) ->
    wrappedLines = []
    while tokenizedLine.text.length > softWrapColumn and wrapScreenColumn = findWrapColumn(tokenizedLine.text)
      [wrappedLine, tokenizedLine] = tokenizedLine.softWrapAt(wrapScreenColumn)
      wrappedLines.push(wrappedLine)
    wrappedLines.push(tokenizedLine)
    wrappedLines

  findWrapColumn = (line) ->
    if /\s/.test(line[softWrapColumn])
      # search forward for the start of a word past the boundary
      for column in [softWrapColumn..line.length]
        return column if /\S/.test(line[column])
      return line.length
    else
      # search backward for the start of the word on the boundary
      for column in [softWrapColumn..0]
        return column + 1 if /\s/.test(line[column])
      return softWrapColumn
