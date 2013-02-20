Editor = require 'editor'
Pane = require 'pane'
{$$} = require 'space-pen'

describe "Pane", ->
  [view1, view2, editSession1, editSession2, pane] = []

  beforeEach ->
    view1 = $$ -> @div id: 'view-1', 'View 1'
    view2 = $$ -> @div id: 'view-2', 'View 2'
    editSession1 = project.buildEditSession('sample.js')
    editSession2 = project.buildEditSession('sample.txt')
    pane = new Pane(view1, editSession1, view2, editSession2)

  describe ".initialize(items...)", ->
    it "displays the first item in the pane", ->
      expect(pane.itemViews.find('#view-1')).toExist()

  describe ".showItem(item)", ->
    it "hides all item views except the one being shown and sets the currentItem", ->
      expect(pane.currentItem).toBe view1
      pane.showItem(view2)
      expect(view1.css('display')).toBe 'none'
      expect(view2.css('display')).toBe ''
      expect(pane.currentItem).toBe view2

    describe "when the given item isn't yet in the items list on the pane", ->
      it "adds it to the items list after the current item", ->
        view3 = $$ -> @div id: 'view-3', "View 3"
        pane.showItem(editSession1)
        expect(pane.getCurrentItemIndex()).toBe 1
        pane.showItem(view3)
        expect(pane.getItems()).toEqual [view1, editSession1, view3, view2, editSession2]
        expect(pane.currentItem).toBe view3
        expect(pane.getCurrentItemIndex()).toBe 2

    describe "when showing a model item", ->
      describe "when no view has yet been appended for that item", ->
        it "appends and shows a view to display the item based on its `.getViewClass` method", ->
          pane.showItem(editSession1)
          editor = pane.itemViews.find('.editor').view()
          expect(editor.activeEditSession).toBe editSession1

      describe "when a valid view has already been appended for another item", ->
        it "recycles the existing view by assigning the selected item to it", ->
          pane.showItem(editSession1)
          pane.showItem(editSession2)
          expect(pane.itemViews.find('.editor').length).toBe 1
          editor = pane.itemViews.find('.editor').view()
          expect(editor.activeEditSession).toBe editSession2

    describe "when showing a view item", ->
      it "appends it to the itemViews div if it hasn't already been appended and show it", ->
        expect(pane.itemViews.find('#view-2')).not.toExist()
        pane.showItem(view2)
        expect(pane.itemViews.find('#view-2')).toExist()

  describe ".removeItem(item)", ->
    it "removes the item from the items list and shows the next item if it was showing", ->
      pane.removeItem(view1)
      expect(pane.getItems()).toEqual [editSession1, view2, editSession2]
      expect(pane.currentItem).toBe editSession1

      pane.showItem(editSession2)
      pane.removeItem(editSession2)
      expect(pane.getItems()).toEqual [editSession1, view2]
      expect(pane.currentItem).toBe editSession1

    describe "when the item is a view", ->
      it "removes the item from the 'item-views' div", ->
        expect(view1.parent()).toMatchSelector pane.itemViews
        pane.removeItem(view1)
        expect(view1.parent()).not.toMatchSelector pane.itemViews

    describe "when the item is a model", ->
      it "removes the associated view only when all items that require it have been removed", ->
        pane.showItem(editSession2)
        pane.removeItem(editSession2)
        expect(pane.itemViews.find('.editor')).toExist()
        pane.removeItem(editSession1)
        expect(pane.itemViews.find('.editor')).not.toExist()

      it "calls destroy on the model", ->
        pane.removeItem(editSession2)
        expect(editSession2.destroyed).toBeTruthy()

  describe "pane:show-next-item and pane:show-preview-item", ->
    it "advances forward/backward through the pane's items, looping around at either end", ->
      expect(pane.currentItem).toBe view1
      pane.trigger 'pane:show-previous-item'
      expect(pane.currentItem).toBe editSession2
      pane.trigger 'pane:show-previous-item'
      expect(pane.currentItem).toBe view2
      pane.trigger 'pane:show-next-item'
      expect(pane.currentItem).toBe editSession2
      pane.trigger 'pane:show-next-item'
      expect(pane.currentItem).toBe view1

  describe ".remove()", ->
    it "destroys all the pane's items", ->
      pane.remove()
      expect(editSession1.destroyed).toBeTruthy()
      expect(editSession2.destroyed).toBeTruthy()

  describe ".focus()", ->
    it "focuses the current item", ->
      focusHandler = jasmine.createSpy("focusHandler")
      pane.currentItem.on 'focus', focusHandler
      pane.focus()
      expect(focusHandler).toHaveBeenCalled()

  describe ".itemForPath(path)", ->
    it "returns the item for which a call to .getPath() returns the given path", ->
      expect(pane.itemForPath(editSession1.getPath())).toBe editSession1
      expect(pane.itemForPath(editSession2.getPath())).toBe editSession2

  describe "serialization", ->
    it "can serialize and deserialize the pane and all its serializable items", ->
      newPane = deserialize(pane.serialize())
      expect(newPane.getItems()).toEqual [editSession1, editSession2]

#   This relates to confirming the closing of a tab
#
#   describe "when buffer is modified", ->
#     it "triggers an alert and does not close the session", ->
#       spyOn(editor, 'remove').andCallThrough()
#       spyOn(atom, 'confirm')
#       editor.insertText("I AM CHANGED!")
#       editor.trigger "core:close"
#       expect(editor.remove).not.toHaveBeenCalled()
#       expect(atom.confirm).toHaveBeenCalled()
#
#     it "doesn't trigger an alert if the buffer is opened in multiple sessions", ->
#       spyOn(editor, 'remove').andCallThrough()
#       spyOn(atom, 'confirm')
#       editor.insertText("I AM CHANGED!")
#       editor.splitLeft()
#       editor.trigger "core:close"
#       expect(editor.remove).toHaveBeenCalled()
#       expect(atom.confirm).not.toHaveBeenCalled()
