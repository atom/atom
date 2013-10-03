{_, fs} = require 'atom'
path = require 'path'
{Site} = require 'telepath'

describe 'TextBuffer', ->
  [filePath, fileContents, buffer] = []

  beforeEach ->
    filePath = require.resolve('./fixtures/sample.js')
    fileContents = fs.read(filePath)
    buffer = project.bufferForPath(filePath)

  afterEach ->
    buffer?.release()

  describe 'constructor', ->
    beforeEach ->
      buffer.release()
      buffer = null

    describe "when given a path", ->
      describe "when a file exists for the path", ->
        it "loads the contents of that file", ->
          filePath = require.resolve './fixtures/sample.txt'
          buffer = project.bufferForPath(filePath)
          expect(buffer.getText()).toBe fs.read(filePath)

        it "does not allow the initial state of the buffer to be undone", ->
          filePath = require.resolve './fixtures/sample.txt'
          buffer = project.bufferForPath(filePath)
          buffer.undo()
          expect(buffer.getText()).toBe fs.read(filePath)

      describe "when no file exists for the path", ->
        it "is modified and is initially empty", ->
          filePath = "does-not-exist.txt"
          expect(fs.exists(filePath)).toBeFalsy()
          buffer = project.bufferForPath(filePath)
          expect(buffer.isModified()).toBeTruthy()
          expect(buffer.getText()).toBe ''

    describe "when no path is given", ->
      it "creates an empty buffer", ->
        buffer = project.bufferForPath(null)
        expect(buffer .getText()).toBe ""

  describe "path-changed event", ->
    [filePath, newPath, bufferToChange, eventHandler] = []

    beforeEach ->
      filePath = path.join(__dirname, "fixtures", "atom-manipulate-me")
      newPath = "#{filePath}-i-moved"
      fs.writeSync(filePath, "")
      bufferToChange = project.bufferForPath(filePath)
      eventHandler = jasmine.createSpy('eventHandler')
      bufferToChange.on 'path-changed', eventHandler

    afterEach ->
      bufferToChange.destroy()
      fs.remove(filePath) if fs.exists(filePath)
      fs.remove(newPath) if fs.exists(newPath)

    it "triggers a `path-changed` event when path is changed", ->
      bufferToChange.saveAs(newPath)
      expect(eventHandler).toHaveBeenCalledWith(bufferToChange)

    it "triggers a `path-changed` event when the file is moved", ->
      jasmine.unspy(window, "setTimeout")

      fs.remove(newPath) if fs.exists(newPath)
      fs.move(filePath, newPath)

      waitsFor "buffer path change", ->
        eventHandler.callCount > 0

      runs ->
        expect(eventHandler).toHaveBeenCalledWith(bufferToChange)

  describe "when the buffer's on-disk contents change", ->
    filePath = null

    beforeEach ->
      filePath = "/tmp/tmp.txt"
      fs.writeSync(filePath, "first")
      buffer.release()
      buffer = project.bufferForPath(filePath).retain()

    afterEach ->
      buffer.release()
      buffer = null
      fs.remove(filePath) if fs.exists(filePath)

    it "does not trigger a change event when Atom modifies the file", ->
      buffer.insert([0,0], "HELLO!")
      changeHandler = jasmine.createSpy("buffer changed")
      buffer.on "changed", changeHandler
      buffer.save()

      waits 30
      runs ->
        expect(changeHandler).not.toHaveBeenCalled()

    describe "when the buffer is in an unmodified state before the on-disk change", ->
      it "changes the memory contents of the buffer to match the new disk contents and triggers a 'changed' event", ->
        changeHandler = jasmine.createSpy('changeHandler')
        buffer.on 'changed', changeHandler
        fs.writeSync(filePath, "second")

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

    describe "when the buffer's memory contents differ from the *previous* disk contents", ->
      it "leaves the buffer in a modified state (does not update its memory contents)", ->
        fileChangeHandler = jasmine.createSpy('fileChange')
        buffer.file.on 'contents-changed', fileChangeHandler

        buffer.insert([0, 0], "a change")
        fs.writeSync(filePath, "second")

        expect(fileChangeHandler.callCount).toBe 0
        waitsFor "file to trigger 'contents-changed' event", ->
          fileChangeHandler.callCount > 0

        runs ->
          expect(buffer.isModified()).toBeTruthy()

      it "fires a single contents-conflicted event", ->
        buffer.insert([0, 0], "a change")
        buffer.save()
        buffer.insert([0, 0], "a second change")

        handler = jasmine.createSpy('fileChange')
        fs.writeSync(filePath, "second")
        buffer.on 'contents-conflicted', handler

        expect(handler.callCount).toBe 0
        waitsFor ->
          handler.callCount > 0

        runs ->
          expect(handler.callCount).toBe 1

  describe "when the buffer's file is deleted (via another process)", ->
    [filePath, bufferToDelete] = []

    beforeEach ->
      filePath = "/tmp/atom-file-to-delete.txt"
      fs.writeSync(filePath, 'delete me')
      bufferToDelete = project.bufferForPath(filePath)
      filePath = bufferToDelete.getPath() # symlinks may have been converted

      expect(bufferToDelete.getPath()).toBe filePath
      expect(bufferToDelete.isModified()).toBeFalsy()

      removeHandler = jasmine.createSpy('removeHandler')
      bufferToDelete.file.on 'removed', removeHandler
      fs.remove(filePath)
      waitsFor "file to be removed", ->
        removeHandler.callCount > 0

    afterEach ->
      bufferToDelete.destroy()

    it "retains its path and reports the buffer as modified", ->
      expect(bufferToDelete.getPath()).toBe filePath
      expect(bufferToDelete.isModified()).toBeTruthy()

    it "resumes watching of the file when it is re-saved", ->
      bufferToDelete.save()
      expect(fsUtils.exists(bufferToDelete.getPath())).toBeTruthy()
      expect(bufferToDelete.isInConflict()).toBeFalsy()

      fs.writeSync(filePath, 'moo')

      changeHandler = jasmine.createSpy('changeHandler')
      bufferToDelete.on 'changed', changeHandler
      waitsFor 'change event', ->
        changeHandler.callCount > 0

  describe "modified status", ->
    it "reports the modified status changing to true or false after the user changes buffer", ->
      modifiedHandler = jasmine.createSpy("modifiedHandler")
      buffer.on 'modified-status-changed', modifiedHandler

      expect(buffer.isModified()).toBeFalsy()
      buffer.insert([0,0], "hi")
      expect(buffer.isModified()).toBe true

      advanceClock(buffer.stoppedChangingDelay)
      expect(modifiedHandler).toHaveBeenCalledWith(true)

      modifiedHandler.reset()
      buffer.insert([0,2], "ho")
      advanceClock(buffer.stoppedChangingDelay)
      expect(modifiedHandler).not.toHaveBeenCalled()

      modifiedHandler.reset()
      buffer.undo()
      buffer.undo()
      advanceClock(buffer.stoppedChangingDelay)
      expect(modifiedHandler).toHaveBeenCalledWith(false)

    it "reports the modified status changing to true after the underlying file is deleted", ->
      buffer.release()
      filePath = "/tmp/atom-tmp-file"
      fs.writeSync(filePath, 'delete me')
      buffer = project.bufferForPath(filePath)
      modifiedHandler = jasmine.createSpy("modifiedHandler")
      buffer.on 'modified-status-changed', modifiedHandler

      fs.remove(filePath)

      waitsFor "modified status to change", -> modifiedHandler.callCount
      runs -> expect(buffer.isModified()).toBe true

    it "reports the modified status changing to false after a modified buffer is saved", ->
      filePath = "/tmp/atom-tmp-file"
      fs.writeSync(filePath, '')
      buffer.release()
      buffer = project.bufferForPath(filePath)
      modifiedHandler = jasmine.createSpy("modifiedHandler")
      buffer.on 'modified-status-changed', modifiedHandler

      buffer.insert([0,0], "hi")
      advanceClock(buffer.stoppedChangingDelay)
      expect(buffer.isModified()).toBe true
      modifiedHandler.reset()

      buffer.save()

      expect(modifiedHandler).toHaveBeenCalledWith(false)
      expect(buffer.isModified()).toBe false
      modifiedHandler.reset()

      buffer.insert([0, 0], 'x')
      advanceClock(buffer.stoppedChangingDelay)
      expect(modifiedHandler).toHaveBeenCalledWith(true)
      expect(buffer.isModified()).toBe true

    it "reports the modified status changing to false after a modified buffer is reloaded", ->
      filePath = "/tmp/atom-tmp-file"
      fs.writeSync(filePath, '')
      buffer.release()
      buffer = project.bufferForPath(filePath)
      modifiedHandler = jasmine.createSpy("modifiedHandler")
      buffer.on 'modified-status-changed', modifiedHandler

      buffer.insert([0,0], "hi")
      advanceClock(buffer.stoppedChangingDelay)
      expect(buffer.isModified()).toBe true
      modifiedHandler.reset()

      buffer.reload()
      expect(modifiedHandler).toHaveBeenCalledWith(false)
      expect(buffer.isModified()).toBe false
      modifiedHandler.reset()

      buffer.insert([0, 0], 'x')
      advanceClock(buffer.stoppedChangingDelay)
      expect(modifiedHandler).toHaveBeenCalledWith(true)
      expect(buffer.isModified()).toBe true

    it "reports the modified status changing to false after a buffer to a non-existent file is saved", ->
      filePath = "/tmp/atom-tmp-file"
      fs.remove(filePath) if fs.exists(filePath)
      expect(fs.exists(filePath)).toBeFalsy()
      buffer.release()
      buffer = project.bufferForPath(filePath)
      modifiedHandler = jasmine.createSpy("modifiedHandler")
      buffer.on 'modified-status-changed', modifiedHandler

      buffer.insert([0,0], "hi")
      advanceClock(buffer.stoppedChangingDelay)
      expect(buffer.isModified()).toBe true
      modifiedHandler.reset()

      buffer.save()
      expect(fs.exists(filePath)).toBeTruthy()

      expect(modifiedHandler).toHaveBeenCalledWith(false)
      expect(buffer.isModified()).toBe false
      modifiedHandler.reset()

      buffer.insert([0, 0], 'x')
      advanceClock(buffer.stoppedChangingDelay)
      expect(modifiedHandler).toHaveBeenCalledWith(true)
      expect(buffer.isModified()).toBe true

    it "returns false for an empty buffer with no path", ->
      buffer.release()
      buffer = project.bufferForPath(null)
      expect(buffer.isModified()).toBeFalsy()

    it "returns true for a non-empty buffer with no path", ->
      buffer.release()
      buffer = project.bufferForPath(null)
      buffer.setText('a')
      expect(buffer.isModified()).toBeTruthy()
      buffer.setText('\n')
      expect(buffer.isModified()).toBeTruthy()

  describe ".getLines()", ->
    it "returns an array of lines in the text contents", ->
      expect(buffer.getLines().length).toBe fileContents.split("\n").length
      expect(buffer.getLines().join('\n')).toBe fileContents

  describe ".change(range, string)", ->
    changeHandler = null

    beforeEach ->
      changeHandler = jasmine.createSpy('changeHandler')
      buffer.on 'changed', changeHandler

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

    it "allows a 'changed' event handler to safely undo the change", ->
      buffer.one 'changed', -> buffer.undo()
      buffer.change([0, 0], "hello")
      expect(buffer.lineForRow(0)).toBe "var quicksort = function () {"

  describe ".setText(text)", ->
    it "changes the entire contents of the buffer and emits a change event", ->
      lastRow = buffer.getLastRow()
      expectedPreRange = [[0,0], [lastRow, buffer.lineForRow(lastRow).length]]
      changeHandler = jasmine.createSpy('changeHandler')
      buffer.on 'changed', changeHandler

      newText = "I know you are.\nBut what am I?"
      buffer.setText(newText)

      expect(buffer.getText()).toBe newText
      expect(changeHandler).toHaveBeenCalled()

      [event] = changeHandler.argsForCall[0]
      expect(event.newText).toBe newText
      expect(event.oldRange).toEqual expectedPreRange
      expect(event.newRange).toEqual [[0, 0], [1, 14]]

  describe ".save()", ->
    saveBuffer = null

    afterEach ->
      saveBuffer.release()

    describe "when the buffer has a path", ->
      filePath = null

      beforeEach ->
        filePath = '/tmp/temp.txt'
        fs.writeSync(filePath, "")
        saveBuffer = project.bufferForPath(filePath)
        saveBuffer.setText("blah")

      it "saves the contents of the buffer to the path", ->
        saveBuffer.setText 'Buffer contents!'
        saveBuffer.save()
        expect(fs.read(filePath)).toEqual 'Buffer contents!'

      it "fires will-be-saved and saved events around the call to fs.writeSync", ->
        events = []
        beforeSave1 = -> events.push('beforeSave1')
        beforeSave2 = -> events.push('beforeSave2')
        afterSave1 = -> events.push('afterSave1')
        afterSave2 = -> events.push('afterSave2')

        saveBuffer.on 'will-be-saved', beforeSave1
        saveBuffer.on 'will-be-saved', beforeSave2
        spyOn(fs, 'writeSync').andCallFake -> events.push 'fs.writeSync'
        saveBuffer.on 'saved', afterSave1
        saveBuffer.on 'saved', afterSave2

        saveBuffer.save()
        expect(events).toEqual ['beforeSave1', 'beforeSave2', 'fs.writeSync', 'afterSave1', 'afterSave2']

      it "fires will-reload and reloaded events when reloaded", ->
        events = []

        saveBuffer.on 'will-reload', -> events.push 'will-reload'
        saveBuffer.on 'reloaded', -> events.push 'reloaded'
        saveBuffer.reload()
        expect(events).toEqual ['will-reload', 'reloaded']

    describe "when the buffer has no path", ->
      it "throws an exception", ->
        saveBuffer = project.bufferForPath(null)
        saveBuffer.setText "hi"
        expect(-> saveBuffer.save()).toThrow()

  describe "reload()", ->
    it "reloads current text from disk and clears any conflicts", ->
      buffer.setText("abc")
      buffer.conflict = true

      buffer.reload()
      expect(buffer.isModified()).toBeFalsy()
      expect(buffer.isInConflict()).toBeFalsy()
      expect(buffer.getText()).toBe(fileContents)

  describe ".saveAs(path)", ->
    [filePath, saveAsBuffer] = []

    afterEach ->
      saveAsBuffer.release()

    it "saves the contents of the buffer to the path", ->
      filePath = '/tmp/temp.txt'
      fs.remove filePath if fs.exists(filePath)

      saveAsBuffer = project.bufferForPath(null).retain()
      eventHandler = jasmine.createSpy('eventHandler')
      saveAsBuffer.on 'path-changed', eventHandler

      saveAsBuffer.setText 'Buffer contents!'
      saveAsBuffer.saveAs(filePath)
      expect(fs.read(filePath)).toEqual 'Buffer contents!'

      expect(eventHandler).toHaveBeenCalledWith(saveAsBuffer)

    it "stops listening to events on previous path and begins listening to events on new path", ->
      originalPath = "/tmp/original.txt"
      newPath = "/tmp/new.txt"
      fs.writeSync(originalPath, "")

      saveAsBuffer = project.bufferForPath(originalPath).retain()
      changeHandler = jasmine.createSpy('changeHandler')
      saveAsBuffer.on 'changed', changeHandler
      saveAsBuffer.saveAs(newPath)
      expect(changeHandler).not.toHaveBeenCalled()

      fs.writeSync(originalPath, "should not trigger buffer event")
      waits 20
      runs ->
        expect(changeHandler).not.toHaveBeenCalled()
        fs.writeSync(newPath, "should trigger buffer event")

      waitsFor ->
        changeHandler.callCount > 0

  describe ".getRelativePath()", ->
    [filePath, newPath, bufferToChange, eventHandler] = []

    beforeEach ->
      filePath = path.join(__dirname, "fixtures", "atom-manipulate-me")
      newPath = "#{filePath}-i-moved"
      fs.writeSync(filePath, "")
      bufferToChange = project.bufferForPath(filePath)
      eventHandler = jasmine.createSpy('eventHandler')
      bufferToChange.on 'path-changed', eventHandler

    afterEach ->
      bufferToChange.destroy()
      fs.remove(filePath) if fs.exists(filePath)
      fs.remove(newPath) if fs.exists(newPath)

    it "updates when the text buffer's file is moved", ->
      expect(bufferToChange.getRelativePath()).toBe('atom-manipulate-me')

      jasmine.unspy(window, "setTimeout")
      eventHandler.reset()
      fs.move(filePath, newPath)

      waitsFor "buffer path change", ->
        eventHandler.callCount > 0

      runs ->
        expect(bufferToChange.getRelativePath()).toBe('atom-manipulate-me-i-moved')

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

    describe "when the range starts before the start of the buffer", ->
      it "clips the range to the start of the buffer", ->
        expect(buffer.getTextInRange([[-Infinity, -Infinity], [0, Infinity]])).toBe buffer.lineForRow(0)

    describe "when the range ends after the end of the buffer", ->
      it "clips the range to the end of the buffer", ->
        expect(buffer.getTextInRange([[12], [13, Infinity]])).toBe buffer.lineForRow(12)

  describe ".scan(regex, fn)", ->
    it "retunrns lineText and lineTextOffset", ->
      matches = []
      buffer.scan /current/, (match) ->
        matches.push(match)
      expect(matches.length).toBe 1

      expect(matches[0].matchText).toEqual 'current'
      expect(matches[0].lineText).toEqual '    var pivot = items.shift(), current, left = [], right = [];'
      expect(matches[0].lineTextOffset).toBe 0

  describe ".scanInRange(range, regex, fn)", ->
    describe "when given a regex with a ignore case flag", ->
      it "does a case-insensitive search", ->
        matches = []
        buffer.scanInRange /cuRRent/i, [[0,0], [12,0]], ({match, range}) ->
          matches.push(match)
        expect(matches.length).toBe 1

    describe "when given a regex with no global flag", ->
      it "calls the iterator with the first match for the given regex in the given range", ->
        matches = []
        ranges = []
        buffer.scanInRange /cu(rr)ent/, [[4,0], [6,44]], ({match, range}) ->
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
        buffer.scanInRange /cu(rr)ent/g, [[4,0], [6,59]], ({match, range}) ->
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
          buffer.scanInRange /cu(r*)/g, [[4,0], [6,9]], ({match, range}) ->
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
          buffer.scanInRange /cu(r*)e/g, [[4,0], [6,9]], ({match, range}) ->
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
        buffer.scanInRange /cu(rr)ent/g, [[4,0], [6,59]], ({range, replace}) ->
          ranges.push(range)
          replace("foo")

        expect(ranges[0]).toEqual [[5,6], [5,13]]
        expect(ranges[1]).toEqual [[6,6], [6,13]]
        expect(ranges[2]).toEqual [[6,30], [6,37]]

        expect(buffer.lineForRow(5)).toBe '      foo = items.shift();'
        expect(buffer.lineForRow(6)).toBe '      foo < pivot ? left.push(foo) : right.push(current);'

      it "allows the match to be replaced with the empty string", ->
        buffer.scanInRange /current/g, [[4,0], [6,59]], ({replace}) ->
          replace("")

        expect(buffer.lineForRow(5)).toBe '       = items.shift();'
        expect(buffer.lineForRow(6)).toBe '       < pivot ? left.push() : right.push(current);'

    describe "when the iterator calls the 'stop' control function", ->
      it "stops the traversal", ->
        ranges = []
        buffer.scanInRange /cu(rr)ent/g, [[4,0], [6,59]], ({range, stop}) ->
          ranges.push(range)
          stop() if ranges.length == 2

        expect(ranges.length).toBe 2

  describe ".backwardsScanInRange(range, regex, fn)", ->
    describe "when given a regex with no global flag", ->
      it "calls the iterator with the last match for the given regex in the given range", ->
        matches = []
        ranges = []
        buffer.backwardsScanInRange /cu(rr)ent/, [[4,0], [6,44]], ({match, range}) ->
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
        buffer.backwardsScanInRange /cu(rr)ent/g, [[4,0], [6,59]], ({match, range}) ->
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
        buffer.backwardsScanInRange /cu(rr)ent/g, [[4,0], [6,59]], ({range, replace}) ->
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
        buffer.backwardsScanInRange /cu(rr)ent/g, [[4,0], [6,59]], ({range, stop}) ->
          ranges.push(range)
          stop() if ranges.length == 2

        expect(ranges.length).toBe 2
        expect(ranges[0]).toEqual [[6,34], [6,41]]
        expect(ranges[1]).toEqual [[6,6], [6,13]]

  describe ".characterIndexForPosition(position)", ->
    it "returns the total number of characters that precede the given position", ->
      expect(buffer.characterIndexForPosition([0, 0])).toBe 0
      expect(buffer.characterIndexForPosition([0, 1])).toBe 1
      expect(buffer.characterIndexForPosition([0, 29])).toBe 29
      expect(buffer.characterIndexForPosition([1, 0])).toBe 30
      expect(buffer.characterIndexForPosition([2, 0])).toBe 61
      expect(buffer.characterIndexForPosition([12, 2])).toBe 408
      expect(buffer.characterIndexForPosition([Infinity])).toBe 408

    describe "when the buffer contains crlf line endings", ->
      it "returns the total number of characters that precede the given position", ->
        buffer.setText("line1\r\nline2\nline3\r\nline4")
        expect(buffer.characterIndexForPosition([1])).toBe 7
        expect(buffer.characterIndexForPosition([2])).toBe 13
        expect(buffer.characterIndexForPosition([3])).toBe 20

  describe ".positionForCharacterIndex(position)", ->
    it "returns the position based on character index", ->
      expect(buffer.positionForCharacterIndex(0)).toEqual [0, 0]
      expect(buffer.positionForCharacterIndex(1)).toEqual [0, 1]
      expect(buffer.positionForCharacterIndex(29)).toEqual [0, 29]
      expect(buffer.positionForCharacterIndex(30)).toEqual [1, 0]
      expect(buffer.positionForCharacterIndex(61)).toEqual [2, 0]
      expect(buffer.positionForCharacterIndex(408)).toEqual [12, 2]

    describe "when the buffer contains crlf line endings", ->
      it "returns the position based on character index", ->
        buffer.setText("line1\r\nline2\nline3\r\nline4")
        expect(buffer.positionForCharacterIndex(7)).toEqual [1, 0]
        expect(buffer.positionForCharacterIndex(13)).toEqual [2, 0]
        expect(buffer.positionForCharacterIndex(20)).toEqual [3, 0]

  describe ".usesSoftTabs()", ->
    it "returns true if the first indented line begins with tabs", ->
      buffer.setText("function() {\n  foo();\n}")
      expect(buffer.usesSoftTabs()).toBeTruthy()
      buffer.setText("function() {\n\tfoo();\n}")
      expect(buffer.usesSoftTabs()).toBeFalsy()
      buffer.setText("")
      expect(buffer.usesSoftTabs()).toBeUndefined()

  describe ".isEmpty()", ->
    it "returns true for an empty buffer", ->
      buffer.setText('')
      expect(buffer.isEmpty()).toBeTruthy()

    it "returns false for a non-empty buffer", ->
      buffer.setText('a')
      expect(buffer.isEmpty()).toBeFalsy()
      buffer.setText('a\nb\nc')
      expect(buffer.isEmpty()).toBeFalsy()
      buffer.setText('\n')
      expect(buffer.isEmpty()).toBeFalsy()

  describe "'contents-modified' event", ->
    it "triggers the 'contents-modified' event with the current modified status when the buffer changes, rate-limiting events with a delay", ->
      delay = buffer.stoppedChangingDelay
      contentsModifiedHandler = jasmine.createSpy("contentsModifiedHandler")
      buffer.on 'contents-modified', contentsModifiedHandler

      buffer.insert([0, 0], 'a')
      expect(contentsModifiedHandler).not.toHaveBeenCalled()

      advanceClock(delay / 2)

      buffer.insert([0, 0], 'b')
      expect(contentsModifiedHandler).not.toHaveBeenCalled()

      advanceClock(delay / 2)
      expect(contentsModifiedHandler).not.toHaveBeenCalled()

      advanceClock(delay / 2)
      expect(contentsModifiedHandler).toHaveBeenCalledWith(true)

      contentsModifiedHandler.reset()
      buffer.undo()
      buffer.undo()
      advanceClock(delay)
      expect(contentsModifiedHandler).toHaveBeenCalledWith(false)

  describe ".append(text)", ->
    it "adds text to the end of the buffer", ->
      buffer.setText("")
      buffer.append("a")
      expect(buffer.getText()).toBe "a"
      buffer.append("b\nc")
      expect(buffer.getText()).toBe "ab\nc"

  describe "line ending support", ->
    describe ".getText()", ->
      it "returns the text with the corrent line endings for each row", ->
        buffer.setText("a\r\nb\nc")
        expect(buffer.getText()).toBe "a\r\nb\nc"
        buffer.setText("a\r\nb\nc\n")
        expect(buffer.getText()).toBe "a\r\nb\nc\n"

    describe "when editing a line", ->
      it "preserves the existing line ending", ->
        buffer.setText("a\r\nb\nc")
        buffer.insert([0, 1], "1")
        expect(buffer.getText()).toBe "a1\r\nb\nc"

    describe "when inserting text with multiple lines", ->
      describe "when the current line has a line ending", ->
        it "uses the same line ending as the line where the text is inserted", ->
          buffer.setText("a\r\n")
          buffer.insert([0, 1], "hello\n1\n\n2")
          expect(buffer.getText()).toBe "ahello\r\n1\r\n\r\n2\r\n"

      describe "when the current line has no line ending (because it's the last line of the buffer)", ->
        describe "when the buffer contains only a single line", ->
          it "honors the line endings in the inserted text", ->
            buffer.setText("initialtext")
            buffer.append("hello\n1\r\n2\n")
            expect(buffer.getText()).toBe "initialtexthello\n1\r\n2\n"

        describe "when the buffer contains a preceding line", ->
          it "uses the line ending of the preceding line", ->
            buffer.setText("\ninitialtext")
            buffer.append("hello\n1\r\n2\n")
            expect(buffer.getText()).toBe "\ninitialtexthello\n1\n2\n"

  describe "serialization", ->
    buffer2 = null

    afterEach ->
      buffer2?.release()

    describe "when the serialized buffer had no unsaved changes", ->
      it "loads the current contents of the file at the serialized path", ->
        expect(buffer.isModified()).toBeFalsy()

        state = buffer.serialize()
        state.get('text').insert([0, 0], 'simulate divergence of on-disk contents from serialized contents')

        buffer2 = deserialize(state, {project})
        expect(buffer2.isModified()).toBeFalsy()
        expect(buffer2.getPath()).toBe(buffer.getPath())
        expect(buffer2.getText()).toBe(buffer.getText())

    describe "when the serialized buffer had unsaved changes", ->
      it "restores the previous unsaved state of the buffer", ->
        previousText = buffer.getText()
        buffer.setText("abc")

        state = buffer.serialize()
        expect(state.getObject('text')).toBe 'abc'

        buffer2 = deserialize(state, {project})
        expect(buffer2.getPath()).toBe(buffer.getPath())
        expect(buffer2.getText()).toBe(buffer.getText())
        expect(buffer2.isModified()).toBeTruthy()
        buffer2.setText(previousText)
        expect(buffer2.isModified()).toBeFalsy()

    describe "when the serialized buffer was unsaved and had no path", ->
      it "restores the previous unsaved state of the buffer", ->
        buffer.setPath(undefined)
        buffer.setText("abc")

        state = buffer.serialize()
        expect(state.get('path')).toBeUndefined()
        expect(state.getObject('text')).toBe 'abc'

        buffer2 = deserialize(state)
        expect(buffer2.getPath()).toBeUndefined()
        expect(buffer2.getText()).toBe("abc")

    describe "when the buffer has remote markers", ->
      [buffer2, buffer3] = []

      afterEach ->
        buffer2.destroy()
        buffer3.destroy()

      it "does not include them in the serialized state", ->
        doc1 = buffer.getState()
        doc2 = doc1.clone(new Site(2))
        doc1.connect(doc2)
        buffer2 = deserialize(doc2, {project})

        buffer.markPosition [1, 0]
        buffer2.markPosition [2, 0]
        expect(buffer.getMarkerCount()).toBe 2
        expect(buffer.getMarkers()[0].isRemote()).toBe false
        expect(buffer.getMarkers()[1].isRemote()).toBe true

        buffer3 = deserialize(buffer.serialize(), {project})
        expect(buffer3.getMarkerCount()).toBe 1
        expect(buffer3.getMarkers()[0].isRemote()).toBe false
        expect(buffer3.getMarkers()[0].getRange()).toEqual [[1, 0], [1, 0]]
