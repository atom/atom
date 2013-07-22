RootView = require 'root-view'
_ = require 'underscore'

describe "Bookmarks package", ->
  editor = null
  editSession = null
  displayBuffer = null

  beforeEach ->
    window.rootView = new RootView
    rootView.open('sample.js')
    rootView.enableKeymap()
    atom.activatePackage('bookmarks', immediate: true)
    rootView.attachToDom()
    editor = rootView.getActiveView()
    editSession = editor.activeEditSession
    displayBuffer = editSession.displayBuffer


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

      editor.trigger 'bookmarks:jump-to-previous-bookmark'
      expect(editSession.getCursor().getBufferPosition()).toEqual [5, 10]

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

      it "jump-to-previous-bookmark finds previous bookmark", ->
        editSession.setCursorBufferPosition([0, 0])

        editor.trigger 'bookmarks:jump-to-previous-bookmark'
        expect(editSession.getCursor().getBufferPosition()).toEqual [10, 0]

        editor.trigger 'bookmarks:jump-to-previous-bookmark'
        expect(editSession.getCursor().getBufferPosition()).toEqual [2, 0]

        editor.trigger 'bookmarks:jump-to-previous-bookmark'
        expect(editSession.getCursor().getBufferPosition()).toEqual [10, 0]
