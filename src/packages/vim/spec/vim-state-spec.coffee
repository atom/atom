RootView = require 'root-view'
Vim = require 'vim/lib/vim-view'
VimState = require 'vim/lib/vim-state'

class EventMonitor
  constructor: ->
    @events = []
    @edit =
      setCursorBufferPosition: () ->
      getCursorBufferPosition: () ->
      clearSelections: ()->
  trigger: (event) ->
    @events.push(event)
  count: () ->
    @events.length
  lastEvent: () ->
    @events[@events.length - 1]
  hasEvent: (name) ->
    for event in @events
      return true if event == name
    false
  command: (name) ->
  activeEditSession:
    setCursorBufferPosition: () ->
    getCursorBufferPosition: () ->
    clearSelections: () ->
    insertText: () ->
    getSelections: () -> []

class MockVimView
  constructor: () ->
    @enterCommandMode()
  enterInsertMode: () ->
    @mode = "insert"
  enterCommandMode: () ->
    @mode = "command"
  exitVisualMode: () ->
    @visual = false
  enterAwaitInputMode: () ->
  startedRecording: () ->
  stoppedRecording: () ->
  editor:
    insertText:() ->
fdescribe "Vim state", ->

  [target, vim, editor] = []

  it_sends_motion_event = (motion, event) =>
    it "sends event '#{event}'", =>
      vim.motion(motion)
      expect(target.lastEvent()).toBe(event)

  beforeEach ->
    target = new EventMonitor
    editor = new MockVimView
    vim = new VimState(target, editor)
    editor.state = vim
    vim.editSession = () => target.activeEditSession

  realEditor = () ->
    config.set("vim.enabled", true)
    window.rootView = new RootView()
    rootView.open('sample.js')
    rootView.simulateDomAttachment()
    editor = rootView.getActiveEditor()
    Vim.activate(rootView)
    vim = editor.vim.state


  # http://vimdoc.sourceforge.net/htmldoc/motion.html
  describe "motions", ->
    describe "counts", ->
      it "defaults to 1", ->
        vim.motion("left")
        expect(target.count()).toBe(1)
      it "repeats a motion multiple times", ->
        vim.count(3)
        vim.motion("left")
        expect(target.count()).toBe(3)
      it "resets after a motion was performed", ->
        vim.count(3)
        vim.motion("left")
        expect(vim.count()).toBe(1)
      describe "add decimals", ->
        it "adds each decimal", ->
          vim.addCountDecimal(1)
          vim.addCountDecimal(3)
          expect(vim.count()).toBe(13)
          vim.motion("left")
          expect(target.count()).toBe(13)

    describe "select in visual mode", ->
      it "uses select operations", ->
        editor.visual = true
        expect(vim.defaultOperation()).toBe('select')

    describe "left-right", ->
      describe "left", ->
        it_sends_motion_event "left", "core:move-left"
      describe "right", ->
        it_sends_motion_event "right", "core:move-right"
      describe "first character", ->
        it_sends_motion_event "beginning-of-line", "editor:move-to-beginning-of-line"
      describe "first non-blank character", ->
      describe "end of line", ->
        it_sends_motion_event "end-of-line", "editor:move-to-end-of-line"

    describe "up-down", ->
      describe "up", ->
        it_sends_motion_event "up", "core:move-up"
      describe "down", ->
        it_sends_motion_event "down", "core:move-down"

    describe "word", ->
      describe "forward", ->
        it_sends_motion_event "next-word", "editor:move-to-beginning-of-next-word"
      describe "backward", ->
        it_sends_motion_event "previous-word", "editor:move-to-beginning-of-word"
      describe "line", ->
    describe 'go to line', ->
      it "moves cursor to line n", ->
        vim.count(2)
        vim.motion("go-to-line")
        expect(target.hasEvent("core:move-to-top")).toBe(true)
        expect(target.hasEvent("core:move-down")).toBe(true)
    describe "find character", ->
      it "moves cursor until it finds character", ->
        realEditor()
        expect(editor.activeEditSession.getCursor().getBufferPosition().column).toBe(0)
        vim.motion("find-character")
        expect(editor.activeEditSession.getCursor().getBufferPosition().column).toBe(0)
        vim.input("f")
        expect(editor.activeEditSession.getCursor().getBufferPosition().column).toBe(16)

  describe "operations", ->
    describe "execution", ->
      it "performs event when motion is executed", ->
        vim.operation("delete")
        expect(target.count()).toBe(0)
        vim.motion("left")
        expect(target.count()).not.toBe(0)
      it "performs operation on current line when operation is executed twice", ->
        vim.operation("delete")
        expect(target.count()).toBe(0)
        vim.operation("delete")
        expect(target.count()).not.toBe(0)
      it "performs operation in visual mode", ->
        editor.visual = true
        vim.operation("delete")
        expect(target.count()).not.toBe(0)

    describe "repeat last operation", ->
      it "executes the last operation", ->
        vim.operation("move")
        expect(target.count()).toBe(1)
        expect(target.hasEvent("editor:move-line")).toBeTruthy()
        target.events = []
        vim.operation("repeat")
        expect(target.count()).toBe(1)
        expect(target.hasEvent("editor:move-line")).toBeTruthy()

    describe "change", ->
      it "removes text in the motion", ->
        vim.operation("change")
        vim.motion("end-of-line")
        expect(target.hasEvent("editor:select-to-end-of-line")).toBe(true)
        expect(target.hasEvent("core:delete")).toBe(true)
      it "sends editor into insert mode", ->
        vim.operation("change")
        vim.motion("end-of-line")
        expect(editor.mode).toBe("insert")
    describe "delete", ->
      it "removes text in the motion", ->
        vim.operation("delete")
        vim.motion("end-of-line")
        expect(target.hasEvent("editor:select-to-end-of-line")).toBe(true)
        expect(target.hasEvent("core:delete")).toBe(true)
    describe "change-character", ->
      it "changes the character under the cursor to input", ->
        spyOn(editor.editor, "insertText")
        vim.operation("change-character")
        vim.input("a")
        expect(target.hasEvent("core:delete")).toBe(true)
        expect(editor.editor.insertText).toHaveBeenCalled()
    describe "insert-line", ->
      it "inserts a line below the cursor", ->
        vim.operation("insert-line")
        vim.motion("end-of-line")
        expect(target.hasEvent("editor:newline")).toBe(true)
    describe "yank", ->
      it "copies text", ->
        spyOn(vim, 'yankSelection')
        vim.operation("yank")
        vim.operation("yank")
        expect(vim.yankSelection).toHaveBeenCalled()
    describe "paste", ->
      it "pastes text", ->
        spyOn(vim, 'paste')
        vim.operation("paste")
        expect(vim.paste).toHaveBeenCalled()
    describe "swap case", ->
    describe "filter through external program", ->
    describe "shift left", ->
    describe "shift right", ->
    describe "record", ->
      beforeEach ->
        vim.operation("start-recording")
        vim.input("a")
        vim.motion("right")
      it "is stored in a register", ->
        expect(vim.recording).toBeTruthy()
        vim.operation("stop-recording")
        expect(vim.recording).toBeFalsy()
        expect(vim.recordings['a']).toBeTruthy()
      it "stores all operations", ->
        vim.operation("stop-recording")
        expect(vim.recordings['a'][0].name).toBe("move")
        expect(vim.recordings['a'].length).toBe(1)
      it "replays all operations", ->
        vim.motion("left")
        vim.operation("stop-recording")
        expect(vim.recordings['a'].length).toBe(2)
        target.events = []
        vim.operation("replay-recording")
        vim.input("a")
        expect(target.hasEvent("core:move-right")).toBeTruthy()
        expect(target.hasEvent("core:move-left")).toBeTruthy()

  describe "aliases", ->
    it 'performs an operation and motion with the current count', ->
      vim.count(2)
      vim.alias('delete-character')
      expect(target.count()).not.toBe(0)

  describe "pasteboard", ->
    it 'stores and retrieves data', ->
      spyOn(vim, 'selectedText').andReturn("a")
      spyOn(vim, 'insertText')
      vim.yankSelection()
      vim.paste()
      expect(vim.insertText).toHaveBeenCalledWith("a")
    it 'does not pasten when no text is yanked', ->
      spyOn(vim, 'selectedText').andReturn(null)
      spyOn(vim, 'insertText')
      vim.yankSelection()
      vim.paste()
      expect(vim.insertText).not.toHaveBeenCalled()
