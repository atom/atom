describe "MenuManager", ->
  describe "::add(items)", ->
    it "can add new menus that can be removed with the returned disposable", ->
      originalItemCount = atom.menu.template.length
      disposable = atom.menu.add [{label: "A", submenu: [{label: "B", command: "b"}]}]
      expect(atom.menu.template[originalItemCount]).toEqual {label: "A", submenu: [{label: "B", command: "b"}]}
      disposable.dispose()
      expect(atom.menu.template.length).toBe originalItemCount

    it "can add submenu items to existing menus that can be removed with the returned disposable", ->
      originalItemCount = atom.menu.template.length
      disposable1 = atom.menu.add [{label: "A", submenu: [{label: "B", command: "b"}]}]
      disposable2 = atom.menu.add [{label: "A", submenu: [{label: "C", submenu: [{label: "D", command: 'd'}]}]}]
      disposable3 = atom.menu.add [{label: "A", submenu: [{label: "C", submenu: [{label: "E", command: 'e'}]}]}]

      expect(atom.menu.template[originalItemCount]).toEqual {
        label: "A",
        submenu: [
          {label: "B", command: "b"},
          {label: "C", submenu: [{label: 'D', command: 'd'}, {label: 'E', command: 'e'}]}
        ]
      }

      disposable3.dispose()
      expect(atom.menu.template[originalItemCount]).toEqual {
        label: "A",
        submenu: [
          {label: "B", command: "b"},
          {label: "C", submenu: [{label: 'D', command: 'd'}]}
        ]
      }

      disposable2.dispose()
      expect(atom.menu.template[originalItemCount]).toEqual {label: "A", submenu: [{label: "B", command: "b"}]}

      disposable1.dispose()
      expect(atom.menu.template.length).toBe originalItemCount

    it "does not add duplicate labels to the same menu", ->
      originalItemCount = atom.menu.template.length
      atom.menu.add [{label: "A", submenu: [{label: "B", command: "b"}]}]
      atom.menu.add [{label: "A", submenu: [{label: "B", command: "b"}]}]
      expect(atom.menu.template[originalItemCount]).toEqual {label: "A", submenu: [{label: "B", command: "b"}]}
