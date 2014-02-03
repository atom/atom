describe "Pasteboard", ->
  describe "write(text, metadata) and read()", ->
    it "writes and reads text to/from the native pasteboard", ->
      expect(atom.clipboard.read().text).toBe 'initial pasteboard content'
      atom.clipboard.write('next')
      expect(atom.clipboard.read().text).toBe 'next'

    it "returns metadata if the item on the native pasteboard matches the last written item", ->
      atom.clipboard.write('next', {meta: 'data'})
      expect(atom.clipboard.read().text).toBe 'next'
      expect(atom.clipboard.read().metadata).toEqual {meta: 'data'}
