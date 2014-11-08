# TODO: Come up with a less ridiculous name for this file.

describe "The spec helpers:", ->
  
  describe 'when a test uses advanceClock()', ->
    [futureCallback] = []
    beforeEach ->
      futureCallback = jasmine.createSpy('futureCallback')

    it 'can synchronously call setTimeout callbacks in the future', ->
      setTimeout(futureCallback, 1000)
      advanceClock(1001)

      expect(futureCallback).toHaveBeenCalled()

    it 'allows timeouts to be cleared', ->
      id = setTimeout(futureCallback, 1000)
      advanceClock(999)
      clearTimeout(id)

      advanceClock(1000)
      expect(futureCallback).not.toHaveBeenCalled()

