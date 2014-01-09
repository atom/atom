PaneModel = require '../src/pane-model'
PaneAxisModel = require '../src/pane-axis-model'
PaneContainerModel = require '../src/pane-container-model'

describe "PaneModel", ->
  describe "split methods", ->
    [pane1, container] = []

    beforeEach ->
      pane1 = new PaneModel(items: ["A"])
      container = new PaneContainerModel(root: pane1)

    describe "::splitLeft(params)", ->
      describe "when the parent is the container root", ->
        it "replaces itself with a row and inserts a new pane to the left of itself", ->
          pane2 = pane1.splitLeft(items: ["B"])
          pane3 = pane1.splitLeft(items: ["C"])
          expect(container.root.orientation).toBe 'horizontal'
          expect(container.root.children).toEqual [pane2, pane3, pane1]

      describe "when the parent is a column", ->
        it "replaces itself with a row and inserts a new pane to the left of itself", ->
          pane1.splitDown()
          pane2 = pane1.splitLeft(items: ["B"])
          pane3 = pane1.splitLeft(items: ["C"])
          row = container.root.children[0]
          expect(row.orientation).toBe 'horizontal'
          expect(row.children).toEqual [pane2, pane3, pane1]

    describe "::splitRight(params)", ->
      describe "when the parent is the container root", ->
        it "replaces itself with a row and inserts a new pane to the right of itself", ->
          pane2 = pane1.splitRight(items: ["B"])
          pane3 = pane1.splitRight(items: ["C"])
          expect(container.root.orientation).toBe 'horizontal'
          expect(container.root.children).toEqual [pane1, pane3, pane2]

      describe "when the parent is a column", ->
        it "replaces itself with a row and inserts a new pane to the right of itself", ->
          pane1.splitDown()
          pane2 = pane1.splitRight(items: ["B"])
          pane3 = pane1.splitRight(items: ["C"])
          row = container.root.children[0]
          expect(row.orientation).toBe 'horizontal'
          expect(row.children).toEqual [pane1, pane3, pane2]

    describe "::splitUp(params)", ->
      describe "when the parent is the container root", ->
        it "replaces itself with a column and inserts a new pane above itself", ->
          pane2 = pane1.splitUp(items: ["B"])
          pane3 = pane1.splitUp(items: ["C"])
          expect(container.root.orientation).toBe 'vertical'
          expect(container.root.children).toEqual [pane2, pane3, pane1]

      describe "when the parent is a row", ->
        it "replaces itself with a column and inserts a new pane above itself", ->
          pane1.splitRight()
          pane2 = pane1.splitUp(items: ["B"])
          pane3 = pane1.splitUp(items: ["C"])
          column = container.root.children[0]
          expect(column.orientation).toBe 'vertical'
          expect(column.children).toEqual [pane2, pane3, pane1]

    describe "::splitDown(params)", ->
      describe "when the parent is the container root", ->
        it "replaces itself with a column and inserts a new pane below itself", ->
          pane2 = pane1.splitDown(items: ["B"])
          pane3 = pane1.splitDown(items: ["C"])
          expect(container.root.orientation).toBe 'vertical'
          expect(container.root.children).toEqual [pane1, pane3, pane2]

      describe "when the parent is a row", ->
        it "replaces itself with a column and inserts a new pane below itself", ->
          pane1.splitRight()
          pane2 = pane1.splitDown(items: ["B"])
          pane3 = pane1.splitDown(items: ["C"])
          column = container.root.children[0]
          expect(column.orientation).toBe 'vertical'
          expect(column.children).toEqual [pane1, pane3, pane2]

    it "focuses the new pane, even if the current pane isn't focused", ->
      expect(pane1.focused).toBe false
      pane2 = pane1.splitRight()
      expect(pane2.focused).toBe true

  describe "::destroy()", ->
    [pane1, container] = []

    beforeEach ->
      pane1 = new PaneModel(items: ["A"])
      container = new PaneContainerModel(root: pane1)

    describe "if the pane's parent has more than two children", ->
      it "removes the pane from its parent", ->
        pane2 = pane1.splitRight()
        pane3 = pane2.splitRight()

        expect(container.root.children).toEqual [pane1, pane2, pane3]
        pane2.destroy()
        expect(container.root.children).toEqual [pane1, pane3]

    describe "if the pane's parent has two children", ->
      it "replaces the parent with its last remaining child", ->
        pane2 = pane1.splitRight()
        pane3 = pane2.splitDown()

        expect(container.root.children[0]).toBe pane1
        expect(container.root.children[1].children).toEqual [pane2, pane3]
        pane3.destroy()
        expect(container.root.children).toEqual [pane1, pane2]
        pane2.destroy()
        expect(container.root).toBe pane1

    describe "if the pane is focused", ->
      it "shifts focus to the next pane", ->
        pane2 = pane1.splitRight()
        pane3 = pane2.splitRight()
        pane2.focus()
        expect(pane2.focused).toBe true
        expect(pane3.focused).toBe false
        pane2.destroy()
        expect(pane3.focused).toBe true
