describe "Pasteboard", ->
  describe "write(text, metadata) and read()", ->
    it "writes and reads text to/from the native pasteboard", ->
      expect(pasteboard.read()).toEqual ['initial pasteboard content']
      pasteboard.write('next')
      expect(pasteboard.read()[0]).toBe 'next'

    it "returns metadata if the item on the native pasteboard matches the last written item", ->
      pasteboard.write('next', {meta: 'data'})
      expect(pasteboard.read()).toEqual ['next', {meta: 'data'}]
