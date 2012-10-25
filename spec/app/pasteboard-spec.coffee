describe "Pasteboard", ->
  nativePasteboard = null
  beforeEach ->
    nativePasteboard = 'first'
    spyOn($native, 'writeToPasteboard').andCallFake (text) -> nativePasteboard = text
    spyOn($native, 'readFromPasteboard').andCallFake -> nativePasteboard

  describe "write(text, metadata) and read()", ->
    it "writes and reads text to/from the native pasteboard", ->
      expect(pasteboard.read()).toEqual ['first']
      pasteboard.write('next')
      expect(nativePasteboard).toBe 'next'

    it "returns metadata if the item on the native pasteboard matches the last written item", ->
      pasteboard.write('next', {meta: 'data'})
      expect(nativePasteboard).toBe 'next'
      expect(pasteboard.read()).toEqual ['next', {meta: 'data'}]
