# THIS FILE INTENTIONALLY BREAKS THE CI BUILD!
# Delete this file when doc changes are ready to merge!

readyToMerge = no
describe "This pull request", ->
  it "should be ready to merge", ->
    expect(readyToMerge).toBeTruthy()
