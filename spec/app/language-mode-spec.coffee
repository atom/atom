Project = require 'project'
Buffer = require 'buffer'
EditSession = require 'edit-session'

describe "LanguageMode", ->
  [editSession, buffer, languageMode] = []

  afterEach ->
    editSession.destroy()

  describe "common behavior", ->
    beforeEach ->
      editSession = fixturesProject.buildEditSessionForPath('sample.js', autoIndent: false)
      { buffer, languageMode } = editSession

    describe "matching character insertion", ->
      describe "when ( is inserted", ->
        it "inserts a matching ) following the cursor", ->
          editSession.insertText '('
          expect(buffer.lineForRow(0)).toMatch /^\(\)/

  describe "javascript", ->
    beforeEach ->
      editSession = fixturesProject.buildEditSessionForPath('sample.js', autoIndent: false)
      { buffer, languageMode } = editSession

    describe ".toggleLineCommentsInRange(range)", ->
      it "comments/uncomments lines in the given range", ->
        languageMode.toggleLineCommentsInRange([[4, 5], [7, 8]])
        expect(buffer.lineForRow(4)).toBe "//    while(items.length > 0) {"
        expect(buffer.lineForRow(5)).toBe "//      current = items.shift();"
        expect(buffer.lineForRow(6)).toBe "//      current < pivot ? left.push(current) : right.push(current);"
        expect(buffer.lineForRow(7)).toBe "//    }"

        languageMode.toggleLineCommentsInRange([[4, 5], [5, 8]])
        expect(buffer.lineForRow(4)).toBe "    while(items.length > 0) {"
        expect(buffer.lineForRow(5)).toBe "      current = items.shift();"
        expect(buffer.lineForRow(6)).toBe "//      current < pivot ? left.push(current) : right.push(current);"
        expect(buffer.lineForRow(7)).toBe "//    }"

    describe "fold suggestion", ->
      describe ".isBufferRowFoldable(bufferRow)", ->
        it "returns true only when the buffer row starts a foldable region", ->
          expect(languageMode.isBufferRowFoldable(0)).toBeTruthy()
          expect(languageMode.isBufferRowFoldable(1)).toBeTruthy()
          expect(languageMode.isBufferRowFoldable(2)).toBeFalsy()
          expect(languageMode.isBufferRowFoldable(3)).toBeFalsy()

      describe ".rowRangeForFoldAtBufferRow(bufferRow)", ->
        it "returns the start/end rows of the foldable region starting at the given row", ->
          expect(languageMode.rowRangeForFoldAtBufferRow(0)).toEqual [0, 12]
          expect(languageMode.rowRangeForFoldAtBufferRow(1)).toEqual [1, 9]
          expect(languageMode.rowRangeForFoldAtBufferRow(2)).toBeNull()
          expect(languageMode.rowRangeForFoldAtBufferRow(4)).toEqual [4, 7]

  describe "coffeescript", ->
    beforeEach ->
      editSession = fixturesProject.buildEditSessionForPath('coffee.coffee', autoIndent: false)
      { buffer, languageMode } = editSession

    describe ".toggleLineCommentsInRange(range)", ->
      it "comments/uncomments lines in the given range", ->
        languageMode.toggleLineCommentsInRange([[4, 5], [7, 8]])
        expect(buffer.lineForRow(4)).toBe "    #pivot = items.shift()"
        expect(buffer.lineForRow(5)).toBe "    #left = []"
        expect(buffer.lineForRow(6)).toBe "    #right = []"
        expect(buffer.lineForRow(7)).toBe "#"

        languageMode.toggleLineCommentsInRange([[4, 5], [5, 8]])
        expect(buffer.lineForRow(4)).toBe "    pivot = items.shift()"
        expect(buffer.lineForRow(5)).toBe "    left = []"
        expect(buffer.lineForRow(6)).toBe "    #right = []"
        expect(buffer.lineForRow(7)).toBe "#"

    describe "fold suggestion", ->
      describe ".isBufferRowFoldable(bufferRow)", ->
        it "returns true only when the buffer row starts a foldable region", ->
          expect(languageMode.isBufferRowFoldable(0)).toBeTruthy()
          expect(languageMode.isBufferRowFoldable(1)).toBeTruthy()
          expect(languageMode.isBufferRowFoldable(2)).toBeFalsy()
          expect(languageMode.isBufferRowFoldable(3)).toBeFalsy()
          expect(languageMode.isBufferRowFoldable(19)).toBeTruthy()

      describe ".rowRangeForFoldAtBufferRow(bufferRow)", ->
        it "returns the start/end rows of the foldable region starting at the given row", ->
          expect(languageMode.rowRangeForFoldAtBufferRow(0)).toEqual [0, 20]
          expect(languageMode.rowRangeForFoldAtBufferRow(1)).toEqual [1, 17]
          expect(languageMode.rowRangeForFoldAtBufferRow(2)).toBeNull()
          expect(languageMode.rowRangeForFoldAtBufferRow(19)).toEqual [19, 20]
