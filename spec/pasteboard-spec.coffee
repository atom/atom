describe "Pasteboard", ->
  describe "write(text, metadata) and read()", ->
    it "writes and reads text to/from the native pasteboard", ->
      expect(atom.pasteboard.read()).toEqual ['initial pasteboard content']
      atom.pasteboard.write('next')
      expect(atom.pasteboard.read()[0]).toBe 'next'

    it "returns metadata if the item on the native pasteboard matches the last written item", ->
      atom.pasteboard.write('next', {meta: 'data'})
      expect(atom.pasteboard.read()).toEqual ['next', {meta: 'data'}]
