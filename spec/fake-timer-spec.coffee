# spec for fakeSetInterval, converting from @scv119

require "./spec-helper"

describe "test fakeSetInterval", ->
  it 'triggered in expected order', ->
    firstExecutedCount = 0
    secondExecutedCount = 0

    fakeSetInterval ->
      firstExecutedCount++
      expect(secondExecutedCount < firstExecutedCount).toBe true
    , 10

    advanceClock 5

    fakeSetInterval ->
      secondExecutedCount++
    , 10

    advanceClock 40

    expect(firstExecutedCount).toBe 4
    expect(secondExecutedCount).toBe 4
