RootView = require 'root-view'
VimState = require 'vim/lib/vim-state'

class EventMonitor
  constructor: ->
    @events = []
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

class MockVimView
  constructor: () ->
    @mode = "command"
  enterInsertMode: () ->
    @mode = "insert"

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

    describe "left-right", ->
      describe "left", ->
        it_sends_motion_event "left", "core:move-left"
      describe "right", ->
        it_sends_motion_event "right", "core:move-right"
      describe "first character", ->
        it_sends_motion_event "move-to-beginning-of-line", "editor:move-to-beginning-of-line"
      describe "first non-blank character", ->
      describe "end of line", ->
        it_sends_motion_event "move-to-end-of-line", "editor:move-to-end-of-line"

    describe "up-down", ->
      describe "up", ->
        it_sends_motion_event "up", "core:move-up"
      describe "down", ->
        it_sends_motion_event "down", "core:move-down"

    describe "word", ->
      describe "forward", ->
        it_sends_motion_event "next-word", "editor:move-to-next-word"
      describe "backward", ->
        it_sends_motion_event "previous-word", "editor:previous-to-next-word"
    describe "line", ->

  describe "operations", ->
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
    describe "change", ->
      it "removes text in the motion", ->
        vim.operation("change")
        vim.motion("move-to-end-of-line")
        expect(target.hasEvent("editor:select-to-end-of-line")).toBe(true)
        expect(target.hasEvent("core:delete")).toBe(true)
      it "sends editor into insert mode", ->
        vim.operation("change")
        vim.motion("move-to-end-of-line")
        expect(editor.mode).toBe("insert")
    describe "delete", ->
      it "removes text in the motion", ->
        vim.operation("delete")
        vim.motion("move-to-end-of-line")
        expect(target.hasEvent("editor:select-to-end-of-line")).toBe(true)
        expect(target.hasEvent("core:delete")).toBe(true)
    describe "yank", ->
    describe "swap case", ->
    describe "filter through external program", ->
    describe "shift left", ->
    describe "shift right", ->