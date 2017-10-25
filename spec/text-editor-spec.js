const fs = require('fs')
const temp = require('temp').track()
const {it, fit, ffit, fffit, beforeEach, afterEach} = require('./async-spec-helpers') // eslint-disable-line no-unused-vars
const TextBuffer = require('text-buffer')
const TextEditor = require('../src/text-editor')

describe('TextEditor', () => {
  let editor

  afterEach(() => {
    editor.destroy()
  })

  describe('.shouldPromptToSave()', () => {
    beforeEach(async () => {
      editor = await atom.workspace.open('sample.js')
      jasmine.unspy(editor, 'shouldPromptToSave')
    })

    it('returns true when buffer has unsaved changes', () => {
      expect(editor.shouldPromptToSave()).toBeFalsy()
      editor.setText('changed')
      expect(editor.shouldPromptToSave()).toBeTruthy()
    })

    it("returns false when an editor's buffer is in use by more than one buffer", async () => {
      editor.setText('changed')

      atom.workspace.getActivePane().splitRight()
      const editor2 = await atom.workspace.open('sample.js', {autoIndent: false})
      expect(editor.shouldPromptToSave()).toBeFalsy()

      editor2.destroy()
      expect(editor.shouldPromptToSave()).toBeTruthy()
    })

    it('returns true when the window is closing if the file has changed on disk', async () => {
      jasmine.useRealClock()

      editor.setText('initial stuff')
      await editor.saveAs(temp.openSync('test-file').path)

      editor.setText('other stuff')
      fs.writeFileSync(editor.getPath(), 'new stuff')
      expect(editor.shouldPromptToSave({windowCloseRequested: true, projectHasPaths: true})).toBeFalsy()

      await new Promise(resolve => editor.onDidConflict(resolve))
      expect(editor.shouldPromptToSave({windowCloseRequested: true, projectHasPaths: true})).toBeTruthy()
    })

    it('returns false when the window is closing and the project has one or more directory paths', () => {
      editor.setText('changed')
      expect(editor.shouldPromptToSave({windowCloseRequested: true, projectHasPaths: true})).toBeFalsy()
    })

    it('returns false when the window is closing and the project has no directory paths', () => {
      editor.setText('changed')
      expect(editor.shouldPromptToSave({windowCloseRequested: true, projectHasPaths: false})).toBeTruthy()
    })
  })

  describe('.toggleLineCommentsInSelection()', () => {
    beforeEach(async () => {
      await atom.packages.activatePackage('language-javascript')
      editor = await atom.workspace.open('sample.js')
    })

    it('toggles comments on the selected lines', () => {
      editor.setSelectedBufferRange([[4, 5], [7, 5]])
      editor.toggleLineCommentsInSelection()

      expect(editor.lineTextForBufferRow(4)).toBe('    // while(items.length > 0) {')
      expect(editor.lineTextForBufferRow(5)).toBe('    //   current = items.shift();')
      expect(editor.lineTextForBufferRow(6)).toBe('    //   current < pivot ? left.push(current) : right.push(current);')
      expect(editor.lineTextForBufferRow(7)).toBe('    // }')
      expect(editor.getSelectedBufferRange()).toEqual([[4, 8], [7, 8]])

      editor.toggleLineCommentsInSelection()
      expect(editor.lineTextForBufferRow(4)).toBe('    while(items.length > 0) {')
      expect(editor.lineTextForBufferRow(5)).toBe('      current = items.shift();')
      expect(editor.lineTextForBufferRow(6)).toBe('      current < pivot ? left.push(current) : right.push(current);')
      expect(editor.lineTextForBufferRow(7)).toBe('    }')
    })

    it('does not comment the last line of a non-empty selection if it ends at column 0', () => {
      editor.setSelectedBufferRange([[4, 5], [7, 0]])
      editor.toggleLineCommentsInSelection()
      expect(editor.lineTextForBufferRow(4)).toBe('    // while(items.length > 0) {')
      expect(editor.lineTextForBufferRow(5)).toBe('    //   current = items.shift();')
      expect(editor.lineTextForBufferRow(6)).toBe('    //   current < pivot ? left.push(current) : right.push(current);')
      expect(editor.lineTextForBufferRow(7)).toBe('    }')
    })

    it('uncomments lines if all lines match the comment regex', () => {
      editor.setSelectedBufferRange([[0, 0], [0, 1]])
      editor.toggleLineCommentsInSelection()
      expect(editor.lineTextForBufferRow(0)).toBe('// var quicksort = function () {')

      editor.setSelectedBufferRange([[0, 0], [2, Infinity]])
      editor.toggleLineCommentsInSelection()
      expect(editor.lineTextForBufferRow(0)).toBe('// // var quicksort = function () {')
      expect(editor.lineTextForBufferRow(1)).toBe('//   var sort = function(items) {')
      expect(editor.lineTextForBufferRow(2)).toBe('//     if (items.length <= 1) return items;')

      editor.setSelectedBufferRange([[0, 0], [2, Infinity]])
      editor.toggleLineCommentsInSelection()
      expect(editor.lineTextForBufferRow(0)).toBe('// var quicksort = function () {')
      expect(editor.lineTextForBufferRow(1)).toBe('  var sort = function(items) {')
      expect(editor.lineTextForBufferRow(2)).toBe('    if (items.length <= 1) return items;')

      editor.setSelectedBufferRange([[0, 0], [0, Infinity]])
      editor.toggleLineCommentsInSelection()
      expect(editor.lineTextForBufferRow(0)).toBe('var quicksort = function () {')
    })

    it('uncomments commented lines separated by an empty line', () => {
      editor.setSelectedBufferRange([[0, 0], [1, Infinity]])
      editor.toggleLineCommentsInSelection()
      expect(editor.lineTextForBufferRow(0)).toBe('// var quicksort = function () {')
      expect(editor.lineTextForBufferRow(1)).toBe('//   var sort = function(items) {')

      editor.getBuffer().insert([0, Infinity], '\n')

      editor.setSelectedBufferRange([[0, 0], [2, Infinity]])
      editor.toggleLineCommentsInSelection()
      expect(editor.lineTextForBufferRow(0)).toBe('var quicksort = function () {')
      expect(editor.lineTextForBufferRow(1)).toBe('')
      expect(editor.lineTextForBufferRow(2)).toBe('  var sort = function(items) {')
    })

    it('preserves selection emptiness', () => {
      editor.setCursorBufferPosition([4, 0])
      editor.toggleLineCommentsInSelection()
      expect(editor.getLastSelection().isEmpty()).toBeTruthy()
    })

    it('does not explode if the current language mode has no comment regex', () => {
      const editor = new TextEditor({buffer: new TextBuffer({text: 'hello'})})
      editor.setSelectedBufferRange([[0, 0], [0, 5]])
      editor.toggleLineCommentsInSelection()
      expect(editor.lineTextForBufferRow(0)).toBe('hello')
    })

    it('does nothing for empty lines and null grammar', () => {
      editor.setGrammar(atom.grammars.grammarForScopeName('text.plain.null-grammar'))
      editor.setCursorBufferPosition([10, 0])
      editor.toggleLineCommentsInSelection()
      expect(editor.lineTextForBufferRow(10)).toBe('')
    })

    it('uncomments when the line lacks the trailing whitespace in the comment regex', () => {
      editor.setCursorBufferPosition([10, 0])
      editor.toggleLineCommentsInSelection()

      expect(editor.lineTextForBufferRow(10)).toBe('// ')
      expect(editor.getSelectedBufferRange()).toEqual([[10, 3], [10, 3]])
      editor.backspace()
      expect(editor.lineTextForBufferRow(10)).toBe('//')

      editor.toggleLineCommentsInSelection()
      expect(editor.lineTextForBufferRow(10)).toBe('')
      expect(editor.getSelectedBufferRange()).toEqual([[10, 0], [10, 0]])
    })

    it('uncomments when the line has leading whitespace', () => {
      editor.setCursorBufferPosition([10, 0])
      editor.toggleLineCommentsInSelection()

      expect(editor.lineTextForBufferRow(10)).toBe('// ')
      editor.moveToBeginningOfLine()
      editor.insertText('  ')
      editor.setSelectedBufferRange([[10, 0], [10, 0]])
      editor.toggleLineCommentsInSelection()
      expect(editor.lineTextForBufferRow(10)).toBe('  ')
    })
  })

  describe('.toggleLineCommentsForBufferRows', () => {
    describe('xml', () => {
      beforeEach(async () => {
        await atom.packages.activatePackage('language-xml')
        editor = await atom.workspace.open('test.xml')
        editor.setText('<!-- test -->')
      })

      it('removes the leading whitespace from the comment end pattern match when uncommenting lines', () => {
        editor.toggleLineCommentsForBufferRows(0, 0)
        expect(editor.lineTextForBufferRow(0)).toBe('test')
      })
    })

    describe('less', () => {
      beforeEach(async () => {
        await atom.packages.activatePackage('language-less')
        await atom.packages.activatePackage('language-css')
        editor = await atom.workspace.open('sample.less')
      })

      it('only uses the `commentEnd` pattern if it comes from the same grammar as the `commentStart` when commenting lines', () => {
        editor.toggleLineCommentsForBufferRows(0, 0)
        expect(editor.lineTextForBufferRow(0)).toBe('// @color: #4D926F;')
      })
    })

    describe('css', () => {
      beforeEach(async () => {
        await atom.packages.activatePackage('language-css')
        editor = await atom.workspace.open('css.css')
      })

      it('comments/uncomments lines in the given range', () => {
        editor.toggleLineCommentsForBufferRows(0, 1)
        expect(editor.lineTextForBufferRow(0)).toBe('/* body {')
        expect(editor.lineTextForBufferRow(1)).toBe('  font-size: 1234px; */')
        expect(editor.lineTextForBufferRow(2)).toBe('  width: 110%;')
        expect(editor.lineTextForBufferRow(3)).toBe('  font-weight: bold !important;')

        editor.toggleLineCommentsForBufferRows(2, 2)
        expect(editor.lineTextForBufferRow(0)).toBe('/* body {')
        expect(editor.lineTextForBufferRow(1)).toBe('  font-size: 1234px; */')
        expect(editor.lineTextForBufferRow(2)).toBe('  /* width: 110%; */')
        expect(editor.lineTextForBufferRow(3)).toBe('  font-weight: bold !important;')

        editor.toggleLineCommentsForBufferRows(0, 1)
        expect(editor.lineTextForBufferRow(0)).toBe('body {')
        expect(editor.lineTextForBufferRow(1)).toBe('  font-size: 1234px;')
        expect(editor.lineTextForBufferRow(2)).toBe('  /* width: 110%; */')
        expect(editor.lineTextForBufferRow(3)).toBe('  font-weight: bold !important;')
      })

      it('uncomments lines with leading whitespace', () => {
        editor.setTextInBufferRange([[2, 0], [2, Infinity]], '  /* width: 110%; */')
        editor.toggleLineCommentsForBufferRows(2, 2)
        expect(editor.lineTextForBufferRow(2)).toBe('  width: 110%;')
      })

      it('uncomments lines with trailing whitespace', () => {
        editor.setTextInBufferRange([[2, 0], [2, Infinity]], '/* width: 110%; */  ')
        editor.toggleLineCommentsForBufferRows(2, 2)
        expect(editor.lineTextForBufferRow(2)).toBe('width: 110%;  ')
      })

      it('uncomments lines with leading and trailing whitespace', () => {
        editor.setTextInBufferRange([[2, 0], [2, Infinity]], '   /* width: 110%; */ ')
        editor.toggleLineCommentsForBufferRows(2, 2)
        expect(editor.lineTextForBufferRow(2)).toBe('   width: 110%; ')
      })
    })

    describe('coffeescript', () => {
      beforeEach(async () => {
        await atom.packages.activatePackage('language-coffee-script')
        editor = await atom.workspace.open('coffee.coffee')
      })

      it('comments/uncomments lines in the given range', () => {
        editor.toggleLineCommentsForBufferRows(4, 6)
        expect(editor.lineTextForBufferRow(4)).toBe('    # pivot = items.shift()')
        expect(editor.lineTextForBufferRow(5)).toBe('    # left = []')
        expect(editor.lineTextForBufferRow(6)).toBe('    # right = []')

        editor.toggleLineCommentsForBufferRows(4, 5)
        expect(editor.lineTextForBufferRow(4)).toBe('    pivot = items.shift()')
        expect(editor.lineTextForBufferRow(5)).toBe('    left = []')
        expect(editor.lineTextForBufferRow(6)).toBe('    # right = []')
      })

      it('comments/uncomments empty lines', () => {
        editor.toggleLineCommentsForBufferRows(4, 7)
        expect(editor.lineTextForBufferRow(4)).toBe('    # pivot = items.shift()')
        expect(editor.lineTextForBufferRow(5)).toBe('    # left = []')
        expect(editor.lineTextForBufferRow(6)).toBe('    # right = []')
        expect(editor.lineTextForBufferRow(7)).toBe('    # ')

        editor.toggleLineCommentsForBufferRows(4, 5)
        expect(editor.lineTextForBufferRow(4)).toBe('    pivot = items.shift()')
        expect(editor.lineTextForBufferRow(5)).toBe('    left = []')
        expect(editor.lineTextForBufferRow(6)).toBe('    # right = []')
        expect(editor.lineTextForBufferRow(7)).toBe('    # ')
      })
    })

    describe('javascript', () => {
      beforeEach(async () => {
        await atom.packages.activatePackage('language-javascript')
        editor = await atom.workspace.open('sample.js')
      })

      it('comments/uncomments lines in the given range', () => {
        editor.toggleLineCommentsForBufferRows(4, 7)
        expect(editor.lineTextForBufferRow(4)).toBe('    // while(items.length > 0) {')
        expect(editor.lineTextForBufferRow(5)).toBe('    //   current = items.shift();')
        expect(editor.lineTextForBufferRow(6)).toBe('    //   current < pivot ? left.push(current) : right.push(current);')
        expect(editor.lineTextForBufferRow(7)).toBe('    // }')

        editor.toggleLineCommentsForBufferRows(4, 5)
        expect(editor.lineTextForBufferRow(4)).toBe('    while(items.length > 0) {')
        expect(editor.lineTextForBufferRow(5)).toBe('      current = items.shift();')
        expect(editor.lineTextForBufferRow(6)).toBe('    //   current < pivot ? left.push(current) : right.push(current);')
        expect(editor.lineTextForBufferRow(7)).toBe('    // }')

        editor.setText('\tvar i;')
        editor.toggleLineCommentsForBufferRows(0, 0)
        expect(editor.lineTextForBufferRow(0)).toBe('\t// var i;')

        editor.setText('var i;')
        editor.toggleLineCommentsForBufferRows(0, 0)
        expect(editor.lineTextForBufferRow(0)).toBe('// var i;')

        editor.setText(' var i;')
        editor.toggleLineCommentsForBufferRows(0, 0)
        expect(editor.lineTextForBufferRow(0)).toBe(' // var i;')

        editor.setText('  ')
        editor.toggleLineCommentsForBufferRows(0, 0)
        expect(editor.lineTextForBufferRow(0)).toBe('  // ')

        editor.setText('    a\n  \n    b')
        editor.toggleLineCommentsForBufferRows(0, 2)
        expect(editor.lineTextForBufferRow(0)).toBe('    // a')
        expect(editor.lineTextForBufferRow(1)).toBe('    // ')
        expect(editor.lineTextForBufferRow(2)).toBe('    // b')

        editor.setText('    \n    // var i;')
        editor.toggleLineCommentsForBufferRows(0, 1)
        expect(editor.lineTextForBufferRow(0)).toBe('    ')
        expect(editor.lineTextForBufferRow(1)).toBe('    var i;')
      })
    })
  })

  describe('folding', () => {
    beforeEach(async () => {
      await atom.packages.activatePackage('language-javascript')
    })

    it('maintains cursor buffer position when a folding/unfolding', async () => {
      editor = await atom.workspace.open('sample.js', {autoIndent: false})
      editor.setCursorBufferPosition([5, 5])
      editor.foldAll()
      expect(editor.getCursorBufferPosition()).toEqual([5, 5])
    })

    describe('.unfoldAll()', () => {
      it('unfolds every folded line', async () => {
        editor = await atom.workspace.open('sample.js', {autoIndent: false})

        const initialScreenLineCount = editor.getScreenLineCount()
        editor.foldBufferRow(0)
        editor.foldBufferRow(1)
        expect(editor.getScreenLineCount()).toBeLessThan(initialScreenLineCount)
        editor.unfoldAll()
        expect(editor.getScreenLineCount()).toBe(initialScreenLineCount)
      })

      it('unfolds every folded line with comments', async () => {
        editor = await atom.workspace.open('sample-with-comments.js', {autoIndent: false})

        const initialScreenLineCount = editor.getScreenLineCount()
        editor.foldBufferRow(0)
        editor.foldBufferRow(5)
        expect(editor.getScreenLineCount()).toBeLessThan(initialScreenLineCount)
        editor.unfoldAll()
        expect(editor.getScreenLineCount()).toBe(initialScreenLineCount)
      })
    })

    describe('.foldAll()', () => {
      it('folds every foldable line', async () => {
        editor = await atom.workspace.open('sample.js', {autoIndent: false})

        editor.foldAll()
        const [fold1, fold2, fold3] = editor.unfoldAll()
        expect([fold1.start.row, fold1.end.row]).toEqual([0, 12])
        expect([fold2.start.row, fold2.end.row]).toEqual([1, 9])
        expect([fold3.start.row, fold3.end.row]).toEqual([4, 7])
      })

      it('works with multi-line comments', async () => {
        editor = await atom.workspace.open('sample-with-comments.js', {autoIndent: false})

        editor.foldAll()
        const folds = editor.unfoldAll()
        expect(folds.length).toBe(8)
        expect([folds[0].start.row, folds[0].end.row]).toEqual([0, 30])
        expect([folds[1].start.row, folds[1].end.row]).toEqual([1, 4])
        expect([folds[2].start.row, folds[2].end.row]).toEqual([5, 27])
        expect([folds[3].start.row, folds[3].end.row]).toEqual([6, 8])
        expect([folds[4].start.row, folds[4].end.row]).toEqual([11, 16])
        expect([folds[5].start.row, folds[5].end.row]).toEqual([17, 20])
        expect([folds[6].start.row, folds[6].end.row]).toEqual([21, 22])
        expect([folds[7].start.row, folds[7].end.row]).toEqual([24, 25])
      })
    })

    describe('.foldBufferRow(bufferRow)', () => {
      beforeEach(async () => {
        editor = await atom.workspace.open('sample.js')
      })

      describe('when bufferRow can be folded', () => {
        it('creates a fold based on the syntactic region starting at the given row', () => {
          editor.foldBufferRow(1)
          const [fold] = editor.unfoldAll()
          expect([fold.start.row, fold.end.row]).toEqual([1, 9])
        })
      })

      describe("when bufferRow can't be folded", () => {
        it('searches upward for the first row that begins a syntactic region containing the given buffer row (and folds it)', () => {
          editor.foldBufferRow(8)
          const [fold] = editor.unfoldAll()
          expect([fold.start.row, fold.end.row]).toEqual([1, 9])
        })
      })

      describe('when the bufferRow is already folded', () => {
        it('searches upward for the first row that begins a syntactic region containing the folded row (and folds it)', () => {
          editor.foldBufferRow(2)
          expect(editor.isFoldedAtBufferRow(0)).toBe(false)
          expect(editor.isFoldedAtBufferRow(1)).toBe(true)

          editor.foldBufferRow(1)
          expect(editor.isFoldedAtBufferRow(0)).toBe(true)
        })
      })

      describe('when the bufferRow is in a multi-line comment', () => {
        it('searches upward and downward for surrounding comment lines and folds them as a single fold', () => {
          editor.buffer.insert([1, 0], '  //this is a comment\n  // and\n  //more docs\n\n//second comment')
          editor.foldBufferRow(1)
          const [fold] = editor.unfoldAll()
          expect([fold.start.row, fold.end.row]).toEqual([1, 3])
        })
      })

      describe('when the bufferRow is a single-line comment', () => {
        it('searches upward for the first row that begins a syntactic region containing the folded row (and folds it)', () => {
          editor.buffer.insert([1, 0], '  //this is a single line comment\n')
          editor.foldBufferRow(1)
          const [fold] = editor.unfoldAll()
          expect([fold.start.row, fold.end.row]).toEqual([0, 13])
        })
      })
    })

    describe('.foldCurrentRow()', () => {
      it('creates a fold at the location of the last cursor', async () => {
        editor = await atom.workspace.open()
        editor.setText('\nif (x) {\n  y()\n}')
        editor.setCursorBufferPosition([1, 0])
        expect(editor.getScreenLineCount()).toBe(4)
        editor.foldCurrentRow()
        expect(editor.getScreenLineCount()).toBe(3)
      })

      it('does nothing when the current row cannot be folded', async () => {
        editor = await atom.workspace.open()
        editor.setText('var x;\nx++\nx++')
        editor.setCursorBufferPosition([0, 0])
        expect(editor.getScreenLineCount()).toBe(3)
        editor.foldCurrentRow()
        expect(editor.getScreenLineCount()).toBe(3)
      })
    })

    describe('.foldAllAtIndentLevel(indentLevel)', () => {
      it('folds blocks of text at the given indentation level', async () => {
        editor = await atom.workspace.open('sample.js', {autoIndent: false})

        editor.foldAllAtIndentLevel(0)
        expect(editor.lineTextForScreenRow(0)).toBe(`var quicksort = function () {${editor.displayLayer.foldCharacter}`)
        expect(editor.getLastScreenRow()).toBe(0)

        editor.foldAllAtIndentLevel(1)
        expect(editor.lineTextForScreenRow(0)).toBe('var quicksort = function () {')
        expect(editor.lineTextForScreenRow(1)).toBe(`  var sort = function(items) {${editor.displayLayer.foldCharacter}`)
        expect(editor.getLastScreenRow()).toBe(4)

        editor.foldAllAtIndentLevel(2)
        expect(editor.lineTextForScreenRow(0)).toBe('var quicksort = function () {')
        expect(editor.lineTextForScreenRow(1)).toBe('  var sort = function(items) {')
        expect(editor.lineTextForScreenRow(2)).toBe('    if (items.length <= 1) return items;')
        expect(editor.getLastScreenRow()).toBe(9)
      })

      it('folds every foldable range at a given indentLevel', async () => {
        editor = await atom.workspace.open('sample-with-comments.js', {autoIndent: false})

        editor.foldAllAtIndentLevel(2)
        const folds = editor.unfoldAll()
        expect(folds.length).toBe(5)
        expect([folds[0].start.row, folds[0].end.row]).toEqual([6, 8])
        expect([folds[1].start.row, folds[1].end.row]).toEqual([11, 16])
        expect([folds[2].start.row, folds[2].end.row]).toEqual([17, 20])
        expect([folds[3].start.row, folds[3].end.row]).toEqual([21, 22])
        expect([folds[4].start.row, folds[4].end.row]).toEqual([24, 25])
      })

      it('does not fold anything but the indentLevel', async () => {
        editor = await atom.workspace.open('sample-with-comments.js', {autoIndent: false})

        editor.foldAllAtIndentLevel(0)
        const folds = editor.unfoldAll()
        expect(folds.length).toBe(1)
        expect([folds[0].start.row, folds[0].end.row]).toEqual([0, 30])
      })
    })

    describe('.isFoldableAtBufferRow(bufferRow)', () => {
      it('returns true if the line starts a multi-line comment', async () => {
        editor = await atom.workspace.open('sample-with-comments.js')

        expect(editor.isFoldableAtBufferRow(1)).toBe(true)
        expect(editor.isFoldableAtBufferRow(6)).toBe(true)
        expect(editor.isFoldableAtBufferRow(8)).toBe(false)
        expect(editor.isFoldableAtBufferRow(11)).toBe(true)
        expect(editor.isFoldableAtBufferRow(15)).toBe(false)
        expect(editor.isFoldableAtBufferRow(17)).toBe(true)
        expect(editor.isFoldableAtBufferRow(21)).toBe(true)
        expect(editor.isFoldableAtBufferRow(24)).toBe(true)
        expect(editor.isFoldableAtBufferRow(28)).toBe(false)
      })

      it('returns true for lines that end with a comment and are followed by an indented line', async () => {
        editor = await atom.workspace.open('sample-with-comments.js')

        expect(editor.isFoldableAtBufferRow(5)).toBe(true)
      })

      it("does not return true for a line in the middle of a comment that's followed by an indented line", async () => {
        editor = await atom.workspace.open('sample-with-comments.js')

        expect(editor.isFoldableAtBufferRow(7)).toBe(false)
        editor.buffer.insert([8, 0], '  ')
        expect(editor.isFoldableAtBufferRow(7)).toBe(false)
      })
    })
  })
})
