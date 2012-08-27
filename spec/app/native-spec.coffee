describe 'Native', ->
  describe '$native.getPlatform()', ->
    it 'returns a non-empty value', ->
      platform = $native.getPlatform()
      expect(platform).not.toBe ''
      expect(platform.length).toBeGreaterThan(0)
