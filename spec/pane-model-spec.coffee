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
