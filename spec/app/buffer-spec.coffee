Project = require 'project'
Buffer = require 'buffer'
fs = require 'fs'

describe 'Buffer', ->
  [filePath, fileContents, buffer] = []

  beforeEach ->
    filePath = require.resolve('fixtures/sample.js')
    fileContents = fs.read(filePath)
    buffer = new Buffer(filePath)

  afterEach ->
    buffer?.release()

  describe 'constructor', ->
    beforeEach ->
      buffer.release()

    describe "when given a path", ->
      describe "when a file exists for the path", ->
        it "loads the contents of that file", ->
          filePath = require.resolve 'fixtures/sample.txt'
          buffer = new Buffer(filePath)
          expect(buffer.getText()).toBe fs.read(filePath)

        it "is not modified and has no undo history", ->
          buffer = new Buffer(filePath)
          expect(buffer.isModified()).toBeFalsy()
          expect(buffer.undoManager.undoHistory.length).toBe 0

      describe "when no file exists for the path", ->
        it "throws an exception", ->
          buffer = null
          filePath = "does-not-exist.txt"
          expect(fs.exists(filePath)).toBeFalsy()
          expect(-> new Buffer(filePath)).toThrow()

    describe "when no path is given", ->
      it "creates an empty buffer", ->
        buffer = new Buffer
        expect(buffer.getText()).toBe ""

  describe "path-change event", ->
    [path, newPath, bufferToChange, eventHandler] = []

    beforeEach ->
      path = fs.join(require.resolve("fixtures/"), "atom-manipulate-me")
      newPath = "#{path}-i-moved"
      fs.write(path, "")
      bufferToChange = new Buffer(path)
      eventHandler = jasmine.createSpy('eventHandler')
      bufferToChange.on 'path-change', eventHandler

    afterEach ->
      bufferToChange.destroy()
      fs.remove(path) if fs.exists(path)
      fs.remove(newPath) if fs.exists(newPath)

    it "triggers a `path-change` event when path is changed", ->
      bufferToChange.saveAs(newPath)
      expect(eventHandler).toHaveBeenCalledWith(bufferToChange)

    it "triggers a `path-change` event when the file is moved", ->
      fs.remove(newPath) if fs.exists(newPath)
      fs.move(path, newPath)

      waitsFor "buffer path change", ->
        eventHandler.callCount > 0

      runs ->
        expect(eventHandler).toHaveBeenCalledWith(bufferToChange)

    it "triggers a `path-change` event when the file is removed", ->
      fs.remove(path)

      waitsFor "buffer path change", ->
        eventHandler.callCount > 0

  describe "when the buffer's file is modified (via another process)", ->
    path = null
    beforeEach ->
      path = "/tmp/tmp.txt"
      fs.write(path, "first")
      buffer.release()
      buffer = new Buffer(path).retain()

    afterEach ->
      fs.remove(path)

    it "does not trigger a contents-change event when Atom modifies the file", ->
      buffer.insert([0,0], "HELLO!")
      changeHandler = jasmine.createSpy("buffer changed")
      buffer.on "change", changeHandler
      buffer.save()

      waits 30
      runs ->
        expect(changeHandler).not.toHaveBeenCalled()

    describe "when the buffer is unmodified", ->
      it "triggers 'change' event and buffer remains unmodified", ->
        changeHandler = jasmine.createSpy('changeHandler')
        buffer.on 'change', changeHandler
        fs.write(path, "second")

        expect(changeHandler.callCount).toBe 0
        waitsFor "file to trigger change event", ->
          changeHandler.callCount > 0

        runs ->
          [event] = changeHandler.argsForCall[0]
          expect(event.oldRange).toEqual [[0, 0], [0, 5]]
          expect(event.newRange).toEqual [[0, 0], [0, 6]]
          expect(event.oldText).toBe "first"
          expect(event.newText).toBe "second"
          expect(buffer.isModified()).toBeFalsy()

    describe "when the buffer is modified", ->
      it "sets modifiedOnDisk to be true", ->
        fileChangeHandler = jasmine.createSpy('fileChange')
        buffer.file.on 'contents-change', fileChangeHandler

        buffer.insert([0, 0], "a change")
        fs.write(path, "second")

        expect(fileChangeHandler.callCount).toBe 0
        waitsFor "file to trigger contents-change event", ->
          fileChangeHandler.callCount > 0

        runs ->
          expect(buffer.isModifiedOnDisk()).toBeTruthy()

  describe "when the buffer's file is deleted (via another process)", ->
    it "no longer has a path", ->
      path = "/tmp/atom-file-to-delete.txt"
      fs.write(path, '')
      bufferToDelete = new Buffer(path)
      expect(bufferToDelete.getPath()).toBe path

      fs.remove(path)

      waitsFor "file to be removed", ->
        not bufferToDelete.getPath()

  describe ".isModified()", ->
    beforeEach ->
      buffer.destroy()
      waitsFor "file to be removed", ->
        not bufferToDelete.getPath()

  describe ".isModified()", ->
    it "returns true when user changes buffer", ->
      expect(buffer.isModified()).toBeFalsy()
      buffer.insert([0,0], "hi")
      expect(buffer.isModified()).toBe true

    it "returns false after modified buffer is saved", ->
      filePath = "/tmp/atom-tmp-file"
      fs.write(filePath, '')
      buffer.release()
      buffer = new Buffer(filePath)
      expect(buffer.isModified()).toBe false

      buffer.insert([0,0], "hi")
      expect(buffer.isModified()).toBe true

      buffer.save()
      expect(buffer.isModified()).toBe false

  describe ".getLines()", ->
    it "returns an array of lines in the text contents", ->
      expect(buffer.getLines().length).toBe fileContents.split("\n").length
      expect(buffer.getLines().join('\n')).toBe fileContents

  describe ".change(range, string)", ->
    changeHandler = null

    beforeEach ->
      changeHandler = jasmine.createSpy('changeHandler')
      buffer.on 'change', changeHandler

    describe "when used to insert (called with an empty range and a non-empty string)", ->
      describe "when the given string has no newlines", ->
        it "inserts the string at the location of the given range", ->
          range = [[3, 4], [3, 4]]
          buffer.change range, "foo"

          expect(buffer.lineForRow(2)).toBe "    if (items.length <= 1) return items;"
          expect(buffer.lineForRow(3)).toBe "    foovar pivot = items.shift(), current, left = [], right = [];"
          expect(buffer.lineForRow(4)).toBe "    while(items.length > 0) {"

          expect(changeHandler).toHaveBeenCalled()
          [event] = changeHandler.argsForCall[0]
          expect(event.oldRange).toEqual range
          expect(event.newRange).toEqual [[3, 4], [3, 7]]
          expect(event.oldText).toBe ""
          expect(event.newText).toBe "foo"

      describe "when the given string has newlines", ->
        it "inserts the lines at the location of the given range", ->
          range = [[3, 4], [3, 4]]

          buffer.change range, "foo\n\nbar\nbaz"

          expect(buffer.lineForRow(2)).toBe "    if (items.length <= 1) return items;"
          expect(buffer.lineForRow(3)).toBe "    foo"
          expect(buffer.lineForRow(4)).toBe ""
          expect(buffer.lineForRow(5)).toBe "bar"
          expect(buffer.lineForRow(6)).toBe "bazvar pivot = items.shift(), current, left = [], right = [];"
          expect(buffer.lineForRow(7)).toBe "    while(items.length > 0) {"

          expect(changeHandler).toHaveBeenCalled()
          [event] = changeHandler.argsForCall[0]
          expect(event.oldRange).toEqual range
          expect(event.newRange).toEqual [[3, 4], [6, 3]]
          expect(event.oldText).toBe ""
          expect(event.newText).toBe "foo\n\nbar\nbaz"

    describe "when used to remove (called with a non-empty range and an empty string)", ->
      describe "when the range is contained within a single line", ->
        it "removes the characters within the range", ->
          range = [[3, 4], [3, 7]]
          buffer.change range, ""

          expect(buffer.lineForRow(2)).toBe "    if (items.length <= 1) return items;"
          expect(buffer.lineForRow(3)).toBe "     pivot = items.shift(), current, left = [], right = [];"
          expect(buffer.lineForRow(4)).toBe "    while(items.length > 0) {"

          expect(changeHandler).toHaveBeenCalled()
          [event] = changeHandler.argsForCall[0]
          expect(event.oldRange).toEqual range
          expect(event.newRange).toEqual [[3, 4], [3, 4]]
          expect(event.oldText).toBe "var"
          expect(event.newText).toBe ""

      describe "when the range spans 2 lines", ->
        it "removes the characters within the range and joins the lines", ->
          range = [[3, 16], [4, 4]]
          buffer.change range, ""

          expect(buffer.lineForRow(2)).toBe "    if (items.length <= 1) return items;"
          expect(buffer.lineForRow(3)).toBe "    var pivot = while(items.length > 0) {"
          expect(buffer.lineForRow(4)).toBe "      current = items.shift();"

          expect(changeHandler).toHaveBeenCalled()
          [event] = changeHandler.argsForCall[0]
          expect(event.oldRange).toEqual range
          expect(event.newRange).toEqual [[3, 16], [3, 16]]
          expect(event.oldText).toBe "items.shift(), current, left = [], right = [];\n    "
          expect(event.newText).toBe ""

      describe "when the range spans more than 2 lines", ->
        it "removes the characters within the range, joining the first and last line and removing the lines in-between", ->
          buffer.change [[3, 16], [11, 9]], ""

          expect(buffer.lineForRow(2)).toBe "    if (items.length <= 1) return items;"
          expect(buffer.lineForRow(3)).toBe "    var pivot = sort(Array.apply(this, arguments));"
          expect(buffer.lineForRow(4)).toBe "};"

    describe "when used to replace text with other text (called with non-empty range and non-empty string)", ->
      it "replaces the old text with the new text", ->
        range = [[3, 16], [11, 9]]
        oldText = buffer.getTextInRange(range)

        buffer.change range, "foo\nbar"

        expect(buffer.lineForRow(2)).toBe "    if (items.length <= 1) return items;"
        expect(buffer.lineForRow(3)).toBe "    var pivot = foo"
        expect(buffer.lineForRow(4)).toBe "barsort(Array.apply(this, arguments));"
        expect(buffer.lineForRow(5)).toBe "};"

        expect(changeHandler).toHaveBeenCalled()
        [event] = changeHandler.argsForCall[0]
        expect(event.oldRange).toEqual range
        expect(event.newRange).toEqual [[3, 16], [4, 3]]
        expect(event.oldText).toBe oldText
        expect(event.newText).toBe "foo\nbar"

    it "allows a 'change' event handler to safely undo the change", ->
      buffer.on 'change', -> buffer.undo()
      buffer.change([0, 0], "hello")
      expect(buffer.lineForRow(0)).toBe "var quicksort = function () {"

  describe ".setText(text)", ->
    it "changes the entire contents of the buffer and emits a change event", ->
      lastRow = buffer.getLastRow()
      expectedPreRange = [[0,0], [lastRow, buffer.lineForRow(lastRow).length]]
      changeHandler = jasmine.createSpy('changeHandler')
      buffer.on 'change', changeHandler

      newText = "I know you are.\nBut what am I?"
      buffer.setText(newText)

      expect(buffer.getText()).toBe newText
      expect(changeHandler).toHaveBeenCalled()

      [event] = changeHandler.argsForCall[0]
      expect(event.newText).toBe newText
      expect(event.oldRange).toEqual expectedPreRange
      expect(event.newRange).toEqual [[0, 0], [1, 14]]

  describe ".save()", ->
    beforeEach ->
      buffer.release()

    describe "when the buffer has a path", ->
      filePath = null

      beforeEach ->
        filePath = '/tmp/temp.txt'
        fs.write(filePath, "")
        buffer = new Buffer filePath

      afterEach ->
        fs.remove filePath if fs.exists(filePath)

      it "saves the contents of the buffer to the path", ->
        buffer.setText 'Buffer contents!'
        buffer.save()
        expect(fs.read(filePath)).toEqual 'Buffer contents!'

      it "fires beforeSave and afterSave events around the call to fs.write", ->
        events = []
        beforeSave1 = -> events.push('beforeSave1')
        beforeSave2 = -> events.push('beforeSave2')
        afterSave1 = -> events.push('afterSave1')
        afterSave2 = -> events.push('afterSave2')

        buffer.on 'before-save', beforeSave1
        buffer.on 'before-save', beforeSave2
        spyOn(fs, 'write').andCallFake -> events.push 'fs.write'
        buffer.on 'after-save', afterSave1
        buffer.on 'after-save', afterSave2

        buffer.save()
        expect(events).toEqual ['beforeSave1', 'beforeSave2', 'fs.write', 'afterSave1', 'afterSave2']

    describe "when the buffer has no path", ->
      it "throws an exception", ->
        buffer = new Buffer
        expect(-> buffer.save()).toThrow()

  describe "reload()", ->
    it "loads text from disk are sets @modified and @modifiedOnDisk to false", ->
      buffer.modified = true
      buffer.modifiedOnDisk = true
      buffer.setText("abc")

      buffer.reload()
      expect(buffer.modifed).toBeFalsy()
      expect(buffer.modifiedOnDisk).toBeFalsy()
      expect(buffer.getText()).toBe(fileContents)

  describe ".saveAs(path)", ->
    [filePath, saveAsBuffer] = []

    afterEach ->
      saveAsBuffer.release()

    it "saves the contents of the buffer to the path", ->
      filePath = '/tmp/temp.txt'
      fs.remove filePath if fs.exists(filePath)

      saveAsBuffer = new Buffer().retain()
      eventHandler = jasmine.createSpy('eventHandler')
      saveAsBuffer.on 'path-change', eventHandler

      saveAsBuffer.setText 'Buffer contents!'
      saveAsBuffer.saveAs(filePath)
      expect(fs.read(filePath)).toEqual 'Buffer contents!'

      expect(eventHandler).toHaveBeenCalledWith(saveAsBuffer)

    it "stops listening to events on previous path and begins listening to events on new path", ->
      originalPath = "/tmp/original.txt"
      newPath = "/tmp/new.txt"
      fs.write(originalPath, "")

      saveAsBuffer = new Buffer(originalPath).retain()
      changeHandler = jasmine.createSpy('changeHandler')
      saveAsBuffer.on 'change', changeHandler
      saveAsBuffer.saveAs(newPath)
      expect(changeHandler).not.toHaveBeenCalled()

      fs.write(originalPath, "should not trigger buffer event")
      waits 20
      runs ->
        expect(changeHandler).not.toHaveBeenCalled()
        fs.write(newPath, "should trigger buffer event")

      waitsFor ->
        changeHandler.callCount > 0

  describe ".getTextInRange(range)", ->
    describe "when range is empty", ->
      it "returns an empty string", ->
        range = [[1,1], [1,1]]
        expect(buffer.getTextInRange(range)).toBe ""

    describe "when range spans one line", ->
      it "returns characters in range", ->
        range = [[2,8], [2,13]]
        expect(buffer.getTextInRange(range)).toBe "items"

        lineLength = buffer.lineForRow(2).length
        range = [[2,0], [2,lineLength]]
        expect(buffer.getTextInRange(range)).toBe "    if (items.length <= 1) return items;"

    describe "when range spans multiple lines", ->
      it "returns characters in range (including newlines)", ->
        lineLength = buffer.lineForRow(2).length
        range = [[2,0], [3,0]]
        expect(buffer.getTextInRange(range)).toBe "    if (items.length <= 1) return items;\n"

        lineLength = buffer.lineForRow(2).length
        range = [[2,10], [4,10]]
        expect(buffer.getTextInRange(range)).toBe "ems.length <= 1) return items;\n    var pivot = items.shift(), current, left = [], right = [];\n    while("

  describe ".scanInRange(range, regex, fn)", ->
    describe "when given a regex with no global flag", ->
      it "calls the iterator with the first match for the given regex in the given range", ->
        matches = []
        ranges = []
        buffer.scanInRange /cu(rr)ent/, [[4,0], [6,44]], (match, range) ->
          matches.push(match)
          ranges.push(range)

        expect(matches.length).toBe 1
        expect(ranges.length).toBe 1

        expect(matches[0][0]).toBe 'current'
        expect(matches[0][1]).toBe 'rr'
        expect(ranges[0]).toEqual [[5,6], [5,13]]

    describe "when given a regex with a global flag", ->
      it "calls the iterator with each match for the given regex in the given range", ->
        matches = []
        ranges = []
        buffer.scanInRange /cu(rr)ent/g, [[4,0], [6,59]], (match, range) ->
          matches.push(match)
          ranges.push(range)

        expect(matches.length).toBe 3
        expect(ranges.length).toBe 3

        expect(matches[0][0]).toBe 'current'
        expect(matches[0][1]).toBe 'rr'
        expect(ranges[0]).toEqual [[5,6], [5,13]]

        expect(matches[1][0]).toBe 'current'
        expect(matches[1][1]).toBe 'rr'
        expect(ranges[1]).toEqual [[6,6], [6,13]]

        expect(matches[2][0]).toBe 'current'
        expect(matches[2][1]).toBe 'rr'
        expect(ranges[2]).toEqual [[6,34], [6,41]]

    describe "when the last regex match exceeds the end of the range", ->
      describe "when the portion of the match within the range also matches the regex", ->
        it "calls the iterator with the truncated match", ->
          matches = []
          ranges = []
          buffer.scanInRange /cu(r*)/g, [[4,0], [6,9]], (match, range) ->
            matches.push(match)
            ranges.push(range)

          expect(matches.length).toBe 2
          expect(ranges.length).toBe 2

          expect(matches[0][0]).toBe 'curr'
          expect(matches[0][1]).toBe 'rr'
          expect(ranges[0]).toEqual [[5,6], [5,10]]

          expect(matches[1][0]).toBe 'cur'
          expect(matches[1][1]).toBe 'r'
          expect(ranges[1]).toEqual [[6,6], [6,9]]

      describe "when the portion of the match within the range does not matches the regex", ->
        it "calls the iterator with the truncated match", ->
          matches = []
          ranges = []
          buffer.scanInRange /cu(r*)e/g, [[4,0], [6,9]], (match, range) ->
            matches.push(match)
            ranges.push(range)

          expect(matches.length).toBe 1
          expect(ranges.length).toBe 1

          expect(matches[0][0]).toBe 'curre'
          expect(matches[0][1]).toBe 'rr'
          expect(ranges[0]).toEqual [[5,6], [5,11]]

    describe "when the iterator calls the 'replace' control function with a replacement string", ->
      it "replaces each occurrence of the regex match with the string", ->
        ranges = []
        buffer.scanInRange /cu(rr)ent/g, [[4,0], [6,59]], (match, range, { replace }) ->
          ranges.push(range)
          replace("foo")

        expect(ranges[0]).toEqual [[5,6], [5,13]]
        expect(ranges[1]).toEqual [[6,6], [6,13]]
        expect(ranges[2]).toEqual [[6,30], [6,37]]

        expect(buffer.lineForRow(5)).toBe '      foo = items.shift();'
        expect(buffer.lineForRow(6)).toBe '      foo < pivot ? left.push(foo) : right.push(current);'

      it "allows the match to be replaced with the empty string", ->
        buffer.scanInRange /current/g, [[4,0], [6,59]], (match, range, { replace }) ->
          replace("")

        expect(buffer.lineForRow(5)).toBe '       = items.shift();'
        expect(buffer.lineForRow(6)).toBe '       < pivot ? left.push() : right.push(current);'

    describe "when the iterator calls the 'stop' control function", ->
      it "stops the traversal", ->
        ranges = []
        buffer.scanInRange /cu(rr)ent/g, [[4,0], [6,59]], (match, range, { stop }) ->
          ranges.push(range)
          stop() if ranges.length == 2

        expect(ranges.length).toBe 2

  describe ".backwardsScanInRange(range, regex, fn)", ->
    describe "when given a regex with no global flag", ->
      it "calls the iterator with the last match for the given regex in the given range", ->
        matches = []
        ranges = []
        buffer.backwardsScanInRange /cu(rr)ent/, [[4,0], [6,44]], (match, range) ->
          matches.push(match)
          ranges.push(range)

        expect(matches.length).toBe 1
        expect(ranges.length).toBe 1

        expect(matches[0][0]).toBe 'current'
        expect(matches[0][1]).toBe 'rr'
        expect(ranges[0]).toEqual [[6,34], [6,41]]

    describe "when given a regex with a global flag", ->
      it "calls the iterator with each match for the given regex in the given range, starting with the last match", ->
        matches = []
        ranges = []
        buffer.backwardsScanInRange /cu(rr)ent/g, [[4,0], [6,59]], (match, range) ->
          matches.push(match)
          ranges.push(range)

        expect(matches.length).toBe 3
        expect(ranges.length).toBe 3

        expect(matches[0][0]).toBe 'current'
        expect(matches[0][1]).toBe 'rr'
        expect(ranges[0]).toEqual [[6,34], [6,41]]

        expect(matches[1][0]).toBe 'current'
        expect(matches[1][1]).toBe 'rr'
        expect(ranges[1]).toEqual [[6,6], [6,13]]

        expect(matches[2][0]).toBe 'current'
        expect(matches[2][1]).toBe 'rr'
        expect(ranges[2]).toEqual [[5,6], [5,13]]

    describe "when the iterator calls the 'replace' control function with a replacement string", ->
      it "replaces each occurrence of the regex match with the string", ->
        ranges = []
        buffer.backwardsScanInRange /cu(rr)ent/g, [[4,0], [6,59]], (match, range, { replace }) ->
          ranges.push(range)
          replace("foo") unless range.start.isEqual([6,6])

        expect(ranges[0]).toEqual [[6,34], [6,41]]
        expect(ranges[1]).toEqual [[6,6], [6,13]]
        expect(ranges[2]).toEqual [[5,6], [5,13]]

        expect(buffer.lineForRow(5)).toBe '      foo = items.shift();'
        expect(buffer.lineForRow(6)).toBe '      current < pivot ? left.push(foo) : right.push(current);'

    describe "when the iterator calls the 'stop' control function", ->
      it "stops the traversal", ->
        ranges = []
        buffer.backwardsScanInRange /cu(rr)ent/g, [[4,0], [6,59]], (match, range, { stop }) ->
          ranges.push(range)
          stop() if ranges.length == 2

        expect(ranges.length).toBe 2
        expect(ranges[0]).toEqual [[6,34], [6,41]]
        expect(ranges[1]).toEqual [[6,6], [6,13]]

  describe ".characterIndexForPosition(position)", ->
    it "returns the total number of charachters that precede the given position", ->
      expect(buffer.characterIndexForPosition([0, 0])).toBe 0
      expect(buffer.characterIndexForPosition([0, 1])).toBe 1
      expect(buffer.characterIndexForPosition([0, 29])).toBe 29
      expect(buffer.characterIndexForPosition([1, 0])).toBe 30
      expect(buffer.characterIndexForPosition([2, 0])).toBe 61
      expect(buffer.characterIndexForPosition([12, 2])).toBe 408

  describe ".positionForCharacterIndex(position)", ->
    it "returns the position based on charachter index", ->
      expect(buffer.positionForCharacterIndex(0)).toEqual [0, 0]
      expect(buffer.positionForCharacterIndex(1)).toEqual [0, 1]
      expect(buffer.positionForCharacterIndex(29)).toEqual [0, 29]
      expect(buffer.positionForCharacterIndex(30)).toEqual [1, 0]
      expect(buffer.positionForCharacterIndex(61)).toEqual [2, 0]
      expect(buffer.positionForCharacterIndex(408)).toEqual [12, 2]

  describe "anchors", ->
    [anchor, destroyHandler] = []

    beforeEach ->
      destroyHandler = jasmine.createSpy("destroyHandler")
      anchor = buffer.addAnchorAtPosition([4, 25])
      anchor.on 'destroy', destroyHandler

    describe "when a buffer change precedes an anchor", ->
      it "moves the anchor in accordance with the change", ->
        buffer.delete([[3, 0], [4, 10]])
        expect(anchor.getBufferPosition()).toEqual [3, 15]
        expect(destroyHandler).not.toHaveBeenCalled()

    describe "when a buffer change surrounds an anchor", ->
      it "destroys the anchor", ->
        buffer.delete([[3, 0], [5, 0]])
        expect(destroyHandler).toHaveBeenCalled()
        expect(buffer.getAnchors().indexOf(anchor)).toBe -1
