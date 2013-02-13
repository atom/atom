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

fdescribe "Vim state", ->

  [target, vim] = []

  it_sends_motion_event = (motion, event) =>
    it "sends event '#{event}'", =>
      vim.motion(motion)
      expect(target.lastEvent()).toBe(event)

  beforeEach ->
    target = new EventMonitor
    vim = new VimState(target)

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
      describe "first non-blank character", ->
      describe "end of line", ->

    describe "up-down", ->
      describe "up", ->
        it_sends_motion_event "up", "core:move-up"
      describe "down", ->
        it_sends_motion_event "down", "core:move-down"

    describe "word", ->
      describe "forward", ->
      describe "backward", ->
    describe "line", ->

  describe "operations", ->
    describe "change", ->
    describe "delete", ->
    describe "yank", ->
    describe "swap case", ->
    describe "filter through external program", ->
    describe "shift left", ->
    describe "shift right", ->