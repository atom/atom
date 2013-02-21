PaneContainer = require 'pane-container'
Pane = require 'pane'
{$$} = require 'space-pen'
$ = require 'jquery'

describe "Pane", ->
  [container, view1, view2, editSession1, editSession2, pane] = []

  beforeEach ->
    container = new PaneContainer
    view1 = $$ -> @div id: 'view-1', 'View 1'
    view2 = $$ -> @div id: 'view-2', 'View 2'
    editSession1 = project.buildEditSession('sample.js')
    editSession2 = project.buildEditSession('sample.txt')
    pane = new Pane(view1, editSession1, view2, editSession2)
    container.append(pane)

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
      it "appends it to the itemViews div if it hasn't already been appended and shows it", ->
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

  describe "pane:show-next-item and pane:show-previous-item", ->
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

  describe "when the pane is focused", ->
    it "focuses the current item view", ->
      focusHandler = jasmine.createSpy("focusHandler")
      pane.currentItem.on 'focus', focusHandler
      pane.focus()
      expect(focusHandler).toHaveBeenCalled()

  describe "split methods", ->
    [pane1, view3, view4] = []
    beforeEach ->
      pane1 = pane
      pane.showItem(editSession1)
      view3 = $$ -> @div id: 'view-3', 'View 3'
      view4 = $$ -> @div id: 'view-4', 'View 4'

    describe "splitRight(items...)", ->
      it "builds a row if needed, then appends a new pane after itself", ->
        # creates the new pane with a copy of the current item if none are given
        pane2 = pane1.splitRight()
        expect(container.find('.row .pane').toArray()).toEqual [pane1[0], pane2[0]]
        expect(pane2.items).toEqual [editSession1]
        expect(pane2.currentItem).not.toBe editSession1 # it's a copy

        pane3 = pane2.splitRight(view3, view4)
        expect(pane3.getItems()).toEqual [view3, view4]
        expect(container.find('.row .pane').toArray()).toEqual [pane[0], pane2[0], pane3[0]]

    describe "splitRight(items...)", ->
      it "builds a row if needed, then appends a new pane before itself", ->
        # creates the new pane with a copy of the current item if none are given
        pane2 = pane.splitLeft()
        expect(container.find('.row .pane').toArray()).toEqual [pane2[0], pane[0]]
        expect(pane2.items).toEqual [editSession1]
        expect(pane2.currentItem).not.toBe editSession1 # it's a copy

        pane3 = pane2.splitLeft(view3, view4)
        expect(pane3.getItems()).toEqual [view3, view4]
        expect(container.find('.row .pane').toArray()).toEqual [pane3[0], pane2[0], pane[0]]

    describe "splitDown(items...)", ->
      it "builds a column if needed, then appends a new pane after itself", ->
        # creates the new pane with a copy of the current item if none are given
        pane2 = pane.splitDown()
        expect(container.find('.column .pane').toArray()).toEqual [pane[0], pane2[0]]
        expect(pane2.items).toEqual [editSession1]
        expect(pane2.currentItem).not.toBe editSession1 # it's a copy

        pane3 = pane2.splitDown(view3, view4)
        expect(pane3.getItems()).toEqual [view3, view4]
        expect(container.find('.column .pane').toArray()).toEqual [pane[0], pane2[0], pane3[0]]

    describe "splitUp(items...)", ->
      it "builds a column if needed, then appends a new pane before itself", ->
        # creates the new pane with a copy of the current item if none are given
        pane2 = pane.splitUp()
        expect(container.find('.column .pane').toArray()).toEqual [pane2[0], pane[0]]
        expect(pane2.items).toEqual [editSession1]
        expect(pane2.currentItem).not.toBe editSession1 # it's a copy

        pane3 = pane2.splitUp(view3, view4)
        expect(pane3.getItems()).toEqual [view3, view4]
        expect(container.find('.column .pane').toArray()).toEqual [pane3[0], pane2[0], pane[0]]

    it "lays out nested panes by equally dividing their containing row / column", ->
      container.width(520).height(240).attachToDom()
      pane1.showItem($("1"))
      pane1
        .splitLeft($("2"))
        .splitUp($("3"))
        .splitLeft($("4"))
        .splitDown($("5"))

      row1 = container.children(':eq(0)')
      expect(row1.children().length).toBe 2
      column1 = row1.children(':eq(0)').view()
      pane1 = row1.children(':eq(1)').view()
      expect(column1.outerWidth()).toBe Math.round(2/3 * container.width())
      expect(column1.outerHeight()).toBe container.height()
      expect(pane1.outerWidth()).toBe Math.round(1/3 * container.width())
      expect(pane1.outerHeight()).toBe container.height()
      expect(Math.round(pane1.position().left)).toBe column1.outerWidth()

      expect(column1.children().length).toBe 2
      row2 = column1.children(':eq(0)').view()
      pane2 = column1.children(':eq(1)').view()
      expect(row2.outerWidth()).toBe column1.outerWidth()
      expect(row2.height()).toBe 2/3 * container.height()
      expect(pane2.outerWidth()).toBe column1.outerWidth()
      expect(pane2.outerHeight()).toBe 1/3 * container.height()
      expect(pane2.position().top).toBe row2.height()

      expect(row2.children().length).toBe 2
      column3 = row2.children(':eq(0)').view()
      pane3 = row2.children(':eq(1)').view()
      expect(column3.outerWidth()).toBe Math.round(1/3 * container.width())
      expect(column3.outerHeight()).toBe row2.outerHeight()
      # the built in rounding seems to be rounding x.5 down, but we need to go up. this sucks.
      expect(Math.round(pane3.trueWidth())).toBe Math.round(1/3 * container.width())
      expect(pane3.height()).toBe row2.outerHeight()
      expect(Math.round(pane3.position().left)).toBe column3.width()

      expect(column3.children().length).toBe 2
      pane4 = column3.children(':eq(0)').view()
      pane5 = column3.children(':eq(1)').view()
      expect(pane4.outerWidth()).toBe column3.width()
      expect(pane4.outerHeight()).toBe 1/3 * container.height()
      expect(pane5.outerWidth()).toBe column3.width()
      expect(pane5.position().top).toBe pane4.outerHeight()
      expect(pane5.outerHeight()).toBe 1/3 * container.height()

      pane5.remove()
      expect(column3.parent()).not.toExist()
      expect(pane2.outerHeight()).toBe Math.floor(1/2 * container.height())
      expect(pane3.outerHeight()).toBe Math.floor(1/2 * container.height())
      expect(pane4.outerHeight()).toBe Math.floor(1/2 * container.height())

      pane4.remove()
      expect(row2.parent()).not.toExist()
      expect(pane1.outerWidth()).toBe Math.floor(1/2 * container.width())
      expect(pane2.outerWidth()).toBe Math.floor(1/2 * container.width())
      expect(pane3.outerWidth()).toBe Math.floor(1/2 * container.width())

      pane3.remove()
      expect(column1.parent()).not.toExist()
      expect(pane2.outerHeight()).toBe container.height()

      pane2.remove()
      expect(row1.parent()).not.toExist()
      expect(container.children().length).toBe 1
      expect(container.children('.pane').length).toBe 1
      expect(pane1.outerWidth()).toBe container.width()

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
