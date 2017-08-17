describe "LanguageMode", ->
  [editor, buffer, languageMode] = []

  afterEach ->
    editor.destroy()

  describe "javascript", ->
    beforeEach ->
      waitsForPromise ->
        atom.workspace.open('sample.js', autoIndent: false).then (o) ->
          editor = o
          {buffer, languageMode} = editor

      waitsForPromise ->
        atom.packages.activatePackage('language-javascript')

    afterEach ->
      atom.packages.deactivatePackages()
      atom.packages.unloadPackages()

    describe ".minIndentLevelForRowRange(startRow, endRow)", ->
      it "returns the minimum indent level for the given row range", ->
        expect(languageMode.minIndentLevelForRowRange(4, 7)).toBe 2
        expect(languageMode.minIndentLevelForRowRange(5, 7)).toBe 2
        expect(languageMode.minIndentLevelForRowRange(5, 6)).toBe 3
        expect(languageMode.minIndentLevelForRowRange(9, 11)).toBe 1
        expect(languageMode.minIndentLevelForRowRange(10, 10)).toBe 0

    describe ".toggleLineCommentsForBufferRows(start, end)", ->
      it "comments/uncomments lines in the given range", ->
        languageMode.toggleLineCommentsForBufferRows(4, 7)
        expect(buffer.lineForRow(4)).toBe "    // while(items.length > 0) {"
        expect(buffer.lineForRow(5)).toBe "    //   current = items.shift();"
        expect(buffer.lineForRow(6)).toBe "    //   current < pivot ? left.push(current) : right.push(current);"
        expect(buffer.lineForRow(7)).toBe "    // }"

        languageMode.toggleLineCommentsForBufferRows(4, 5)
        expect(buffer.lineForRow(4)).toBe "    while(items.length > 0) {"
        expect(buffer.lineForRow(5)).toBe "      current = items.shift();"
        expect(buffer.lineForRow(6)).toBe "    //   current < pivot ? left.push(current) : right.push(current);"
        expect(buffer.lineForRow(7)).toBe "    // }"

        buffer.setText('\tvar i;')
        languageMode.toggleLineCommentsForBufferRows(0, 0)
        expect(buffer.lineForRow(0)).toBe "\t// var i;"

        buffer.setText('var i;')
        languageMode.toggleLineCommentsForBufferRows(0, 0)
        expect(buffer.lineForRow(0)).toBe "// var i;"

        buffer.setText(' var i;')
        languageMode.toggleLineCommentsForBufferRows(0, 0)
        expect(buffer.lineForRow(0)).toBe " // var i;"

        buffer.setText('  ')
        languageMode.toggleLineCommentsForBufferRows(0, 0)
        expect(buffer.lineForRow(0)).toBe "  // "

        buffer.setText('    a\n  \n    b')
        languageMode.toggleLineCommentsForBufferRows(0, 2)
        expect(buffer.lineForRow(0)).toBe "    // a"
        expect(buffer.lineForRow(1)).toBe "    // "
        expect(buffer.lineForRow(2)).toBe "    // b"

        buffer.setText('    \n    // var i;')
        languageMode.toggleLineCommentsForBufferRows(0, 1)
        expect(buffer.lineForRow(0)).toBe '    '
        expect(buffer.lineForRow(1)).toBe '    var i;'

    describe ".rowRangeForCodeFoldAtBufferRow(bufferRow)", ->
      it "returns the start/end rows of the foldable region starting at the given row", ->
        expect(languageMode.rowRangeForCodeFoldAtBufferRow(0)).toEqual [0, 12]
        expect(languageMode.rowRangeForCodeFoldAtBufferRow(1)).toEqual [1, 9]
        expect(languageMode.rowRangeForCodeFoldAtBufferRow(2)).toBeNull()
        expect(languageMode.rowRangeForCodeFoldAtBufferRow(4)).toEqual [4, 7]

    describe ".rowRangeForCommentAtBufferRow(bufferRow)", ->
      it "returns the start/end rows of the foldable comment starting at the given row", ->
        buffer.setText("//this is a multi line comment\n//another line")
        expect(languageMode.rowRangeForCommentAtBufferRow(0)).toEqual [0, 1]
        expect(languageMode.rowRangeForCommentAtBufferRow(1)).toEqual [0, 1]

        buffer.setText("//this is a multi line comment\n//another line\n//and one more")
        expect(languageMode.rowRangeForCommentAtBufferRow(0)).toEqual [0, 2]
        expect(languageMode.rowRangeForCommentAtBufferRow(1)).toEqual [0, 2]

        buffer.setText("//this is a multi line comment\n\n//with an empty line")
        expect(languageMode.rowRangeForCommentAtBufferRow(0)).toBeUndefined()
        expect(languageMode.rowRangeForCommentAtBufferRow(1)).toBeUndefined()
        expect(languageMode.rowRangeForCommentAtBufferRow(2)).toBeUndefined()

        buffer.setText("//this is a single line comment\n")
        expect(languageMode.rowRangeForCommentAtBufferRow(0)).toBeUndefined()
        expect(languageMode.rowRangeForCommentAtBufferRow(1)).toBeUndefined()

        buffer.setText("//this is a single line comment")
        expect(languageMode.rowRangeForCommentAtBufferRow(0)).toBeUndefined()

    describe ".suggestedIndentForBufferRow", ->
      it "bases indentation off of the previous non-blank line", ->
        expect(languageMode.suggestedIndentForBufferRow(0)).toBe 0
        expect(languageMode.suggestedIndentForBufferRow(1)).toBe 1
        expect(languageMode.suggestedIndentForBufferRow(2)).toBe 2
        expect(languageMode.suggestedIndentForBufferRow(5)).toBe 3
        expect(languageMode.suggestedIndentForBufferRow(7)).toBe 2
        expect(languageMode.suggestedIndentForBufferRow(9)).toBe 1
        expect(languageMode.suggestedIndentForBufferRow(11)).toBe 1

      it "does not take invisibles into account", ->
        editor.update({showInvisibles: true})
        expect(languageMode.suggestedIndentForBufferRow(0)).toBe 0
        expect(languageMode.suggestedIndentForBufferRow(1)).toBe 1
        expect(languageMode.suggestedIndentForBufferRow(2)).toBe 2
        expect(languageMode.suggestedIndentForBufferRow(5)).toBe 3
        expect(languageMode.suggestedIndentForBufferRow(7)).toBe 2
        expect(languageMode.suggestedIndentForBufferRow(9)).toBe 1
        expect(languageMode.suggestedIndentForBufferRow(11)).toBe 1

    describe "rowRangeForParagraphAtBufferRow", ->
      describe "with code and comments", ->
        beforeEach ->
          buffer.setText '''
            var quicksort = function () {
              /* Single line comment block */
              var sort = function(items) {};

              /*
              A multiline
              comment is here
              */
              var sort = function(items) {};

              // A comment
              //
              // Multiple comment
              // lines
              var sort = function(items) {};
              // comment line after fn

              var nosort = function(items) {
                return item;
              }

            };
          '''

        it "will limit paragraph range to comments", ->
          range = languageMode.rowRangeForParagraphAtBufferRow(0)
          expect(range).toEqual [[0, 0], [0, 29]]

          range = languageMode.rowRangeForParagraphAtBufferRow(10)
          expect(range).toEqual [[10, 0], [10, 14]]
          range = languageMode.rowRangeForParagraphAtBufferRow(11)
          expect(range).toBeFalsy()
          range = languageMode.rowRangeForParagraphAtBufferRow(12)
          expect(range).toEqual [[12, 0], [13, 10]]

          range = languageMode.rowRangeForParagraphAtBufferRow(14)
          expect(range).toEqual [[14, 0], [14, 32]]

          range = languageMode.rowRangeForParagraphAtBufferRow(15)
          expect(range).toEqual [[15, 0], [15, 26]]

          range = languageMode.rowRangeForParagraphAtBufferRow(18)
          expect(range).toEqual [[17, 0], [19, 3]]

  describe "coffeescript", ->
    beforeEach ->
      waitsForPromise ->
        atom.workspace.open('coffee.coffee', autoIndent: false).then (o) ->
          editor = o
          {buffer, languageMode} = editor

      waitsForPromise ->
        atom.packages.activatePackage('language-coffee-script')

    afterEach ->
      atom.packages.deactivatePackages()
      atom.packages.unloadPackages()

    describe ".toggleLineCommentsForBufferRows(start, end)", ->
      it "comments/uncomments lines in the given range", ->
        languageMode.toggleLineCommentsForBufferRows(4, 6)
        expect(buffer.lineForRow(4)).toBe "    # pivot = items.shift()"
        expect(buffer.lineForRow(5)).toBe "    # left = []"
        expect(buffer.lineForRow(6)).toBe "    # right = []"

        languageMode.toggleLineCommentsForBufferRows(4, 5)
        expect(buffer.lineForRow(4)).toBe "    pivot = items.shift()"
        expect(buffer.lineForRow(5)).toBe "    left = []"
        expect(buffer.lineForRow(6)).toBe "    # right = []"

      it "comments/uncomments lines when empty line", ->
        languageMode.toggleLineCommentsForBufferRows(4, 7)
        expect(buffer.lineForRow(4)).toBe "    # pivot = items.shift()"
        expect(buffer.lineForRow(5)).toBe "    # left = []"
        expect(buffer.lineForRow(6)).toBe "    # right = []"
        expect(buffer.lineForRow(7)).toBe "    # "

        languageMode.toggleLineCommentsForBufferRows(4, 5)
        expect(buffer.lineForRow(4)).toBe "    pivot = items.shift()"
        expect(buffer.lineForRow(5)).toBe "    left = []"
        expect(buffer.lineForRow(6)).toBe "    # right = []"
        expect(buffer.lineForRow(7)).toBe "    # "

    describe "fold suggestion", ->
      describe ".rowRangeForCodeFoldAtBufferRow(bufferRow)", ->
        it "returns the start/end rows of the foldable region starting at the given row", ->
          expect(languageMode.rowRangeForCodeFoldAtBufferRow(0)).toEqual [0, 20]
          expect(languageMode.rowRangeForCodeFoldAtBufferRow(1)).toEqual [1, 17]
          expect(languageMode.rowRangeForCodeFoldAtBufferRow(2)).toBeNull()
          expect(languageMode.rowRangeForCodeFoldAtBufferRow(19)).toEqual [19, 20]

  describe "css", ->
    beforeEach ->
      waitsForPromise ->
        atom.workspace.open('css.css', autoIndent: false).then (o) ->
          editor = o
          {buffer, languageMode} = editor

      waitsForPromise ->
        atom.packages.activatePackage('language-css')

    afterEach ->
      atom.packages.deactivatePackages()
      atom.packages.unloadPackages()

    describe ".toggleLineCommentsForBufferRows(start, end)", ->
      it "comments/uncomments lines in the given range", ->
        languageMode.toggleLineCommentsForBufferRows(0, 1)
        expect(buffer.lineForRow(0)).toBe "/*body {"
        expect(buffer.lineForRow(1)).toBe "  font-size: 1234px;*/"
        expect(buffer.lineForRow(2)).toBe "  width: 110%;"
        expect(buffer.lineForRow(3)).toBe "  font-weight: bold !important;"

        languageMode.toggleLineCommentsForBufferRows(2, 2)
        expect(buffer.lineForRow(0)).toBe "/*body {"
        expect(buffer.lineForRow(1)).toBe "  font-size: 1234px;*/"
        expect(buffer.lineForRow(2)).toBe "  /*width: 110%;*/"
        expect(buffer.lineForRow(3)).toBe "  font-weight: bold !important;"

        languageMode.toggleLineCommentsForBufferRows(0, 1)
        expect(buffer.lineForRow(0)).toBe "body {"
        expect(buffer.lineForRow(1)).toBe "  font-size: 1234px;"
        expect(buffer.lineForRow(2)).toBe "  /*width: 110%;*/"
        expect(buffer.lineForRow(3)).toBe "  font-weight: bold !important;"

      it "uncomments lines with leading whitespace", ->
        buffer.setTextInRange([[2, 0], [2, Infinity]], "  /*width: 110%;*/")
        languageMode.toggleLineCommentsForBufferRows(2, 2)
        expect(buffer.lineForRow(2)).toBe "  width: 110%;"

      it "uncomments lines with trailing whitespace", ->
        buffer.setTextInRange([[2, 0], [2, Infinity]], "/*width: 110%;*/  ")
        languageMode.toggleLineCommentsForBufferRows(2, 2)
        expect(buffer.lineForRow(2)).toBe "width: 110%;  "

      it "uncomments lines with leading and trailing whitespace", ->
        buffer.setTextInRange([[2, 0], [2, Infinity]], "   /*width: 110%;*/ ")
        languageMode.toggleLineCommentsForBufferRows(2, 2)
        expect(buffer.lineForRow(2)).toBe "   width: 110%; "

  describe "less", ->
    beforeEach ->
      waitsForPromise ->
        atom.workspace.open('sample.less', autoIndent: false).then (o) ->
          editor = o
          {buffer, languageMode} = editor

      waitsForPromise ->
        atom.packages.activatePackage('language-less')

      waitsForPromise ->
        atom.packages.activatePackage('language-css')

    afterEach ->
      atom.packages.deactivatePackages()
      atom.packages.unloadPackages()

    describe "when commenting lines", ->
      it "only uses the `commentEnd` pattern if it comes from the same grammar as the `commentStart`", ->
        languageMode.toggleLineCommentsForBufferRows(0, 0)
        expect(buffer.lineForRow(0)).toBe "// @color: #4D926F;"

  describe "xml", ->
    beforeEach ->
      waitsForPromise ->
        atom.workspace.open('sample.xml', autoIndent: false).then (o) ->
          editor = o
          editor.setText("<!-- test -->")
          {buffer, languageMode} = editor

      waitsForPromise ->
        atom.packages.activatePackage('language-xml')

    afterEach ->
      atom.packages.deactivatePackages()
      atom.packages.unloadPackages()

    describe "when uncommenting lines", ->
      it "removes the leading whitespace from the comment end pattern match", ->
        languageMode.toggleLineCommentsForBufferRows(0, 0)
        expect(buffer.lineForRow(0)).toBe "test"

  describe "folding", ->
    beforeEach ->
      waitsForPromise ->
        atom.workspace.open('sample.js', autoIndent: false).then (o) ->
          editor = o
          {buffer, languageMode} = editor

      waitsForPromise ->
        atom.packages.activatePackage('language-javascript')

    afterEach ->
      atom.packages.deactivatePackages()
      atom.packages.unloadPackages()

    it "maintains cursor buffer position when a folding/unfolding", ->
      editor.setCursorBufferPosition([5, 5])
      languageMode.foldAll()
      expect(editor.getCursorBufferPosition()).toEqual([5, 5])

    describe ".unfoldAll()", ->
      it "unfolds every folded line", ->
        initialScreenLineCount = editor.getScreenLineCount()
        languageMode.foldBufferRow(0)
        languageMode.foldBufferRow(1)
        expect(editor.getScreenLineCount()).toBeLessThan initialScreenLineCount
        languageMode.unfoldAll()
        expect(editor.getScreenLineCount()).toBe initialScreenLineCount

    describe ".foldAll()", ->
      it "folds every foldable line", ->
        languageMode.foldAll()

        [fold1, fold2, fold3] = languageMode.unfoldAll()
        expect([fold1.start.row, fold1.end.row]).toEqual [0, 12]
        expect([fold2.start.row, fold2.end.row]).toEqual [1, 9]
        expect([fold3.start.row, fold3.end.row]).toEqual [4, 7]

    describe ".foldBufferRow(bufferRow)", ->
      describe "when bufferRow can be folded", ->
        it "creates a fold based on the syntactic region starting at the given row", ->
          languageMode.foldBufferRow(1)
          [fold] = languageMode.unfoldAll()
          expect([fold.start.row, fold.end.row]).toEqual [1, 9]

      describe "when bufferRow can't be folded", ->
        it "searches upward for the first row that begins a syntatic region containing the given buffer row (and folds it)", ->
          languageMode.foldBufferRow(8)
          [fold] = languageMode.unfoldAll()
          expect([fold.start.row, fold.end.row]).toEqual [1, 9]

      describe "when the bufferRow is already folded", ->
        it "searches upward for the first row that begins a syntatic region containing the folded row (and folds it)", ->
          languageMode.foldBufferRow(2)
          expect(editor.isFoldedAtBufferRow(0)).toBe(false)
          expect(editor.isFoldedAtBufferRow(1)).toBe(true)

          languageMode.foldBufferRow(1)
          expect(editor.isFoldedAtBufferRow(0)).toBe(true)

      describe "when the bufferRow is in a multi-line comment", ->
        it "searches upward and downward for surrounding comment lines and folds them as a single fold", ->
          buffer.insert([1, 0], "  //this is a comment\n  // and\n  //more docs\n\n//second comment")
          languageMode.foldBufferRow(1)
          [fold] = languageMode.unfoldAll()
          expect([fold.start.row, fold.end.row]).toEqual [1, 3]

      describe "when the bufferRow is a single-line comment", ->
        it "searches upward for the first row that begins a syntatic region containing the folded row (and folds it)", ->
          buffer.insert([1, 0], "  //this is a single line comment\n")
          languageMode.foldBufferRow(1)
          [fold] = languageMode.unfoldAll()
          expect([fold.start.row, fold.end.row]).toEqual [0, 13]

    describe ".foldAllAtIndentLevel(indentLevel)", ->
      it "folds blocks of text at the given indentation level", ->
        languageMode.foldAllAtIndentLevel(0)
        expect(editor.lineTextForScreenRow(0)).toBe "var quicksort = function () {" + editor.displayLayer.foldCharacter
        expect(editor.getLastScreenRow()).toBe 0

        languageMode.foldAllAtIndentLevel(1)
        expect(editor.lineTextForScreenRow(0)).toBe "var quicksort = function () {"
        expect(editor.lineTextForScreenRow(1)).toBe "  var sort = function(items) {" + editor.displayLayer.foldCharacter
        expect(editor.getLastScreenRow()).toBe 4

        languageMode.foldAllAtIndentLevel(2)
        expect(editor.lineTextForScreenRow(0)).toBe "var quicksort = function () {"
        expect(editor.lineTextForScreenRow(1)).toBe "  var sort = function(items) {"
        expect(editor.lineTextForScreenRow(2)).toBe "    if (items.length <= 1) return items;"
        expect(editor.getLastScreenRow()).toBe 9

  describe "folding with comments", ->
    beforeEach ->
      waitsForPromise ->
        atom.workspace.open('sample-with-comments.js', autoIndent: false).then (o) ->
          editor = o
          {buffer, languageMode} = editor

      waitsForPromise ->
        atom.packages.activatePackage('language-javascript')

    afterEach ->
      atom.packages.deactivatePackages()
      atom.packages.unloadPackages()

    describe ".unfoldAll()", ->
      it "unfolds every folded line", ->
        initialScreenLineCount = editor.getScreenLineCount()
        languageMode.foldBufferRow(0)
        languageMode.foldBufferRow(5)
        expect(editor.getScreenLineCount()).toBeLessThan initialScreenLineCount
        languageMode.unfoldAll()
        expect(editor.getScreenLineCount()).toBe initialScreenLineCount

    describe ".foldAll()", ->
      it "folds every foldable line", ->
        languageMode.foldAll()

        folds = languageMode.unfoldAll()
        expect(folds.length).toBe 8
        expect([folds[0].start.row, folds[0].end.row]).toEqual [0, 30]
        expect([folds[1].start.row, folds[1].end.row]).toEqual [1, 4]
        expect([folds[2].start.row, folds[2].end.row]).toEqual [5, 27]
        expect([folds[3].start.row, folds[3].end.row]).toEqual [6, 8]
        expect([folds[4].start.row, folds[4].end.row]).toEqual [11, 16]
        expect([folds[5].start.row, folds[5].end.row]).toEqual [17, 20]
        expect([folds[6].start.row, folds[6].end.row]).toEqual [21, 22]
        expect([folds[7].start.row, folds[7].end.row]).toEqual [24, 25]

    describe ".foldAllAtIndentLevel()", ->
      it "folds every foldable range at a given indentLevel", ->
        languageMode.foldAllAtIndentLevel(2)

        folds = languageMode.unfoldAll()
        expect(folds.length).toBe 5
        expect([folds[0].start.row, folds[0].end.row]).toEqual [6, 8]
        expect([folds[1].start.row, folds[1].end.row]).toEqual [11, 16]
        expect([folds[2].start.row, folds[2].end.row]).toEqual [17, 20]
        expect([folds[3].start.row, folds[3].end.row]).toEqual [21, 22]
        expect([folds[4].start.row, folds[4].end.row]).toEqual [24, 25]

      it "does not fold anything but the indentLevel", ->
        languageMode.foldAllAtIndentLevel(0)

        folds = languageMode.unfoldAll()
        expect(folds.length).toBe 1
        expect([folds[0].start.row, folds[0].end.row]).toEqual [0, 30]

    describe ".isFoldableAtBufferRow(bufferRow)", ->
      it "returns true if the line starts a multi-line comment", ->
        expect(languageMode.isFoldableAtBufferRow(1)).toBe true
        expect(languageMode.isFoldableAtBufferRow(6)).toBe true
        expect(languageMode.isFoldableAtBufferRow(8)).toBe false
        expect(languageMode.isFoldableAtBufferRow(11)).toBe true
        expect(languageMode.isFoldableAtBufferRow(15)).toBe false
        expect(languageMode.isFoldableAtBufferRow(17)).toBe true
        expect(languageMode.isFoldableAtBufferRow(21)).toBe true
        expect(languageMode.isFoldableAtBufferRow(24)).toBe true
        expect(languageMode.isFoldableAtBufferRow(28)).toBe false

      it "returns true for lines that end with a comment and are followed by an indented line", ->
        expect(languageMode.isFoldableAtBufferRow(5)).toBe true

      it "does not return true for a line in the middle of a comment that's followed by an indented line", ->
        expect(languageMode.isFoldableAtBufferRow(7)).toBe false
        editor.buffer.insert([8, 0], '  ')
        expect(languageMode.isFoldableAtBufferRow(7)).toBe false

  describe "css", ->
    beforeEach ->
      waitsForPromise ->
        atom.workspace.open('css.css', autoIndent: true).then (o) ->
          editor = o
          {buffer, languageMode} = editor

      waitsForPromise ->
        atom.packages.activatePackage('language-source')
        atom.packages.activatePackage('language-css')

    afterEach ->
      atom.packages.deactivatePackages()
      atom.packages.unloadPackages()

    describe "suggestedIndentForBufferRow", ->
      it "does not return negative values (regression)", ->
        editor.setText('.test {\npadding: 0;\n}')
        expect(editor.suggestedIndentForBufferRow(2)).toBe 0
