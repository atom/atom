RootView = require 'root-view'
_ = require 'underscore'
shell = require 'shell'

describe "Bookmarks package", ->
  [editor, editSession, displayBuffer] = []

  beforeEach ->
    window.rootView = new RootView
    rootView.open('sample.js')
    rootView.enableKeymap()
    atom.activatePackage('bookmarks', immediate: true)
    rootView.attachToDom()
    editor = rootView.getActiveView()
    editSession = editor.activeEditSession
    displayBuffer = editSession.displayBuffer
    spyOn(shell, 'beep')

  describe "toggling bookmarks", ->
    it "creates a marker when toggled", ->
      editSession.setCursorBufferPosition([3, 10])
      expect(displayBuffer.findMarkers(class: 'bookmark').length).toEqual 0

      editor.trigger 'bookmarks:toggle-bookmark'

      markers = displayBuffer.findMarkers(class: 'bookmark')
      expect(markers.length).toEqual 1
      expect(markers[0].getBufferRange()).toEqual [[3, 0], [3, 0]]

    it "removes marker when toggled", ->
      editSession.setCursorBufferPosition([3, 10])
      expect(displayBuffer.findMarkers(class: 'bookmark').length).toEqual 0

      editor.trigger 'bookmarks:toggle-bookmark'
      expect(displayBuffer.findMarkers(class: 'bookmark').length).toEqual 1

      editor.trigger 'bookmarks:toggle-bookmark'
      expect(displayBuffer.findMarkers(class: 'bookmark').length).toEqual 0

    it "toggles proper classes on proper gutter row", ->
      editSession.setCursorBufferPosition([3, 10])
      expect(editor.find('.bookmarked').length).toEqual 0

      editor.trigger 'bookmarks:toggle-bookmark'

      lines = editor.find('.bookmarked')
      expect(lines.length).toEqual 1
      expect(lines.attr('linenumber')).toEqual '3'

      editor.trigger 'bookmarks:toggle-bookmark'
      expect(editor.find('.bookmarked').length).toEqual 0

  describe "jumping between bookmarks", ->

    it "doesnt die when no bookmarks", ->
      editSession.setCursorBufferPosition([5, 10])

      editor.trigger 'bookmarks:jump-to-next-bookmark'
      expect(editSession.getCursor().getBufferPosition()).toEqual [5, 10]
      expect(shell.beep.callCount).toBe 1

      editor.trigger 'bookmarks:jump-to-previous-bookmark'
      expect(editSession.getCursor().getBufferPosition()).toEqual [5, 10]
      expect(shell.beep.callCount).toBe 2

    describe "with one bookmark", ->
      beforeEach ->
        editSession.setCursorBufferPosition([2, 0])
        editor.trigger 'bookmarks:toggle-bookmark'

      it "jump-to-next-bookmark jumps to the right place", ->
        editSession.setCursorBufferPosition([0, 0])

        editor.trigger 'bookmarks:jump-to-next-bookmark'
        expect(editSession.getCursor().getBufferPosition()).toEqual [2, 0]

        editor.trigger 'bookmarks:jump-to-next-bookmark'
        expect(editSession.getCursor().getBufferPosition()).toEqual [2, 0]

        editSession.setCursorBufferPosition([5, 0])

        editor.trigger 'bookmarks:jump-to-next-bookmark'
        expect(editSession.getCursor().getBufferPosition()).toEqual [2, 0]

      it "jump-to-previous-bookmark jumps to the right place", ->
        editSession.setCursorBufferPosition([0, 0])

        editor.trigger 'bookmarks:jump-to-previous-bookmark'
        expect(editSession.getCursor().getBufferPosition()).toEqual [2, 0]

        editor.trigger 'bookmarks:jump-to-previous-bookmark'
        expect(editSession.getCursor().getBufferPosition()).toEqual [2, 0]

        editSession.setCursorBufferPosition([5, 0])

        editor.trigger 'bookmarks:jump-to-previous-bookmark'
        expect(editSession.getCursor().getBufferPosition()).toEqual [2, 0]

    describe "with bookmarks", ->
      beforeEach ->
        editSession.setCursorBufferPosition([2, 0])
        editor.trigger 'bookmarks:toggle-bookmark'

        editSession.setCursorBufferPosition([10, 0])
        editor.trigger 'bookmarks:toggle-bookmark'

      it "jump-to-next-bookmark finds next bookmark", ->
        editSession.setCursorBufferPosition([0, 0])

        editor.trigger 'bookmarks:jump-to-next-bookmark'
        expect(editSession.getCursor().getBufferPosition()).toEqual [2, 0]

        editor.trigger 'bookmarks:jump-to-next-bookmark'
        expect(editSession.getCursor().getBufferPosition()).toEqual [10, 0]

        editor.trigger 'bookmarks:jump-to-next-bookmark'
        expect(editSession.getCursor().getBufferPosition()).toEqual [2, 0]

        editSession.setCursorBufferPosition([11, 0])

        editor.trigger 'bookmarks:jump-to-next-bookmark'
        expect(editSession.getCursor().getBufferPosition()).toEqual [2, 0]

      it "jump-to-previous-bookmark finds previous bookmark", ->
        editSession.setCursorBufferPosition([0, 0])

        editor.trigger 'bookmarks:jump-to-previous-bookmark'
        expect(editSession.getCursor().getBufferPosition()).toEqual [10, 0]

        editor.trigger 'bookmarks:jump-to-previous-bookmark'
        expect(editSession.getCursor().getBufferPosition()).toEqual [2, 0]

        editor.trigger 'bookmarks:jump-to-previous-bookmark'
        expect(editSession.getCursor().getBufferPosition()).toEqual [10, 0]

        editSession.setCursorBufferPosition([11, 0])

        editor.trigger 'bookmarks:jump-to-previous-bookmark'
        expect(editSession.getCursor().getBufferPosition()).toEqual [10, 0]

  describe "browsing bookmarks", ->
    it "displays a select list of all bookmarks", ->
      editSession.setCursorBufferPosition([0])
      editor.trigger 'bookmarks:toggle-bookmark'
      editSession.setCursorBufferPosition([2])
      editor.trigger 'bookmarks:toggle-bookmark'
      editSession.setCursorBufferPosition([4])
      editor.trigger 'bookmarks:toggle-bookmark'

      rootView.trigger 'bookmarks:view-all'

      bookmarks = rootView.find('.bookmarks-view')
      expect(bookmarks).toExist()
      expect(bookmarks.find('.bookmark').length).toBe 3
      expect(bookmarks.find('.bookmark:eq(0)').find('.primary-line').text()).toBe 'sample.js:1'
      expect(bookmarks.find('.bookmark:eq(0)').find('.secondary-line').text()).toBe 'var quicksort = function () {'
      expect(bookmarks.find('.bookmark:eq(1)').find('.primary-line').text()).toBe 'sample.js:3'
      expect(bookmarks.find('.bookmark:eq(1)').find('.secondary-line').text()).toBe 'if (items.length <= 1) return items;'
      expect(bookmarks.find('.bookmark:eq(2)').find('.primary-line').text()).toBe 'sample.js:5'
      expect(bookmarks.find('.bookmark:eq(2)').find('.secondary-line').text()).toBe 'while(items.length > 0) {'

    describe "when a bookmark is selected", ->
      it "sets the cursor to the location the bookmark", ->
        editSession.setCursorBufferPosition([8])
        editor.trigger 'bookmarks:toggle-bookmark'
        editSession.setCursorBufferPosition([0])

        rootView.trigger 'bookmarks:view-all'

        bookmarks = rootView.find('.bookmarks-view')
        expect(bookmarks).toExist()
        bookmarks.find('.bookmark').mousedown().mouseup()
        expect(editSession.getCursorBufferPosition()).toEqual [8, 0]
