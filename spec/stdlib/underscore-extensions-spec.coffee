_ = require 'underscore'

describe "underscore extensions", ->
  describe "_.adviseBefore", ->
    [object, calls] = []

    beforeEach ->
      calls = []
      object = {
        method: (args...) ->
          calls.push(["original", this, args])
      }

    it "calls the given function before the advised method", ->
      _.adviseBefore object, 'method', (args...) -> calls.push(["advice", this, args])
      object.method(1, 2, 3)
      expect(calls).toEqual [['advice', object, [1, 2, 3]], ['original', object, [1, 2, 3]]]

    it "cancels the original method's invocation if the advice returns true", ->
      _.adviseBefore object, 'method', -> false
      object.method(1, 2, 3)
      expect(calls).toEqual []
