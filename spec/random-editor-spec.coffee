{times, random} = require 'underscore-plus'
randomWords = require 'random-words'
TextBuffer = require 'text-buffer'
TextEditor = require '../src/text-editor'

describe "TextEditor", ->
  [editor, tokenizedBuffer, buffer, steps] = []

  softWrapColumn = 80

  beforeEach ->
    atom.config.set('editor.softWrapAtPreferredLineLength', true)
    atom.config.set('editor.preferredLineLength', softWrapColumn)

  it "properly renders soft-wrapped lines when randomly mutated", ->
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
    console.log "==== steps to reproduce this failure: ==="
    for step in steps
      console.log 'editor.' + step[0] + '('+ step[1..].map((a) -> JSON.stringify(a)).join(', ') + ')'

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
    referenceEditor = new TextEditor({})
    referenceEditor.setEditorWidthInChars(80)
    referenceEditor.setText(editor.getText())
    referenceEditor.setSoftWrapped(editor.isSoftWrapped())
    screenLines = referenceEditor.tokenizedLinesForScreenRows(0, referenceEditor.getLastScreenRow())
    bufferRows = referenceEditor.bufferRowsForScreenRows(0, referenceEditor.getLastScreenRow())

    {screenLines, bufferRows}
