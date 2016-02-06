'use strict'

module.exports =
class StateStore {
  constructor () {
    this.dbPromise = new Promise((resolve, reject) => {
      let dbOpenRequest = indexedDB.open('AtomEnvironments', 1)
      dbOpenRequest.onupgradeneeded = (event) => {
        let db = event.target.result
        db.createObjectStore('states')
        resolve(db)
      }
      dbOpenRequest.onsuccess = () => {
        resolve(dbOpenRequest.result)
      }
      dbOpenRequest.onerror = reject
    })
  }

  save (key, value) {
    return this.dbPromise.then(db => {
      value.storedAt = new Date().toString()
      return new Promise((resolve, reject) => {
        var request = db.transaction(['states'], 'readwrite')
          .objectStore('states')
          .put(value, key)

        request.onsuccess = resolve
        request.onerror = reject
      })
    })
  }

  load (key) {
    return this.dbPromise.then(db => {
      return new Promise((resolve, reject) => {
        var request = db.transaction(['states'])
          .objectStore('states')
          .get(key)

        request.onsuccess = (event) => resolve(event.target.result)
        request.onerror = (event) => reject(event)
      })
    })
  }
}
