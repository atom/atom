PaneContainer = require '../src/pane-container'

fdescribe "PaneContainer", ->
  container = null

  beforeEach ->
    container = PaneContainer.createAsRoot()

  describe "::createPane(items...)", ->
    describe "when there are no panes", ->
      it "creates a single pane as the root", ->
        expect(container.root).toBe undefined
        pane = container.createPane({title: 'Item 1'})
        expect(container.panes).toEqual [pane]
        expect(container.root).toBe pane

  describe "splitting and destroying panes", ->
    it "inserts and removes pane axes of the corrent orientation as necessary", ->
      # creation phase
      pane1 = container.createPane({title: 'Item 1'})

      pane2 = pane1.splitRight({title: 'Item 2'})
      row = container.root
      expect(row.orientation).toBe 'horizontal'
      expect(row.children).toEqual [pane1, pane2]

      pane3 = pane2.splitLeft({title: 'Item 3'})
      expect(row.children).toEqual [pane1, pane3, pane2]

      pane4 = pane3.splitDown({title: 'Item 4'})
      column = row.children.get(1)
      expect(column.orientation).toBe 'vertical'
      expect(column.children).toEqual [pane3, pane4]

      pane5 = pane4.splitUp({title: 'Item 5'})
      expect(column.children).toEqual [pane3, pane5, pane4]

      # destruction phase
      pane5.destroy()
      pane4.destroy()
      expect(column.isAttached()).toBe false
      expect(row.children).toEqual [pane1, pane3, pane2]

      pane3.destroy()
      pane2.destroy()
      expect(row.isAttached()).toBe false
      expect(container.root).toBe pane1

  describe "moving items between panes", ->
    [pane1, pane2] = []

    beforeEach ->
      pane1 = container.createPane({title: 'Item 1'}, {title: 'Item 2'})
      pane2 = pane1.splitRight({title: 'Item 3'}, {title: 'Item 4'})

    it "removes the item from the source pane and moves it to the target pane at the desired index", ->
      pane1.moveItemToPane(pane1.items.get(1), pane2, 1)
      expect(pane1.items.map('title')).toEqual ['Item 1']
      expect(pane2.items.map('title')).toEqual ['Item 3', 'Item 2', 'Item 4']

      # default index to length of target pane's items
      pane1.moveItemToPane(pane2.items.get(2), pane1)
      expect(pane1.items.map('title')).toEqual ['Item 1', 'Item 4']
      expect(pane2.items.map('title')).toEqual ['Item 3', 'Item 2']

      # destroy the source pane when it loses all items
      pane1.moveItemToPane(pane1.items.get(0), pane2)
      pane1.moveItemToPane(pane1.items.get(0), pane2)
      expect(pane1.isAttached()).toBe false
