/** @babel */
import {it, ffit, fffit, beforeEach, afterEach} from './async-spec-helpers'

const StateStore = require('../src/state-store.js')

describe("StateStore", () => {
  it("can save and load states", () => {
    const store = new StateStore()
    return store.save('key', {foo:'bar'})
      .then(() => store.load('key'))
      .then((state) => {
        expect(state).toEqual({foo:'bar'})
      })
  })

  describe("when there is an error reading from the database", () => {
    it("rejects the promise returned by load", () => {
      const store = new StateStore()

      const fakeErrorEvent = {target: {errorCode: "Something bad happened"}}

      spyOn(IDBObjectStore.prototype, 'get').andCallFake((key) => {
        let request = {}
        process.nextTick(() => request.onerror(fakeErrorEvent))
        return request
      })

      return store.load('nonexistentKey')
        .then(() => {
          throw new Error("Promise should have been rejected")
        })
        .catch((event) => {
          expect(event).toBe(fakeErrorEvent)
        })
    })
  })
})
