'use strict'

module.exports =
class StateStore {
  constructor (databaseName, version) {
    this.dbPromise = new Promise((resolve) => {
      let dbOpenRequest = indexedDB.open(databaseName, version)
      dbOpenRequest.onupgradeneeded = (event) => {
        let db = event.target.result
        db.createObjectStore('states')
      }
      dbOpenRequest.onsuccess = () => {
        resolve(dbOpenRequest.result)
      }
      dbOpenRequest.onerror = (error) => {
        console.error('Could not connect to indexedDB', error)
        resolve(null)
      }
    })
  }

  connect () {
    return this.dbPromise.then(db => !!db)
  }

  save (key, value) {
    // Serialize values using JSON.stringify, as it seems way faster than IndexedDB structured clone.
    // (Ref.: https://bugs.chromium.org/p/chromium/issues/detail?id=536620)
    let jsonValue = JSON.stringify(value)
    return new Promise((resolve, reject) => {
      this.dbPromise.then(db => {
        if (db == null) resolve()

        var request = db.transaction(['states'], 'readwrite')
          .objectStore('states')
          .put({value: jsonValue, storedAt: new Date().toString(), isJSON: true}, key)

        request.onsuccess = resolve
        request.onerror = reject
      })
    })
  }

  load (key) {
    return this.dbPromise.then(db => {
      if (!db) return

      return new Promise((resolve, reject) => {
        var request = db.transaction(['states'])
          .objectStore('states')
          .get(key)

        request.onsuccess = (event) => {
          let result = event.target.result
          if (result) {
            // TODO: remove this when state will be serialized only via JSON.
            resolve(result.isJSON ? JSON.parse(result.value) : result.value)
          } else {
            resolve(null)
          }
        }

        request.onerror = (event) => reject(event)
      })
    })
  }

  clear () {
    return this.dbPromise.then(db => {
      if (!db) return

      return new Promise((resolve, reject) => {
        var request = db.transaction(['states'], 'readwrite')
          .objectStore('states')
          .clear()

        request.onsuccess = resolve
        request.onerror = reject
      })
    })
  }

  count () {
    return this.dbPromise.then(db => {
      if (!db) return

      return new Promise((resolve, reject) => {
        var request = db.transaction(['states'])
          .objectStore('states')
          .count()

        request.onsuccess = () => {
          resolve(request.result)
        }
        request.onerror = reject
      })
    })
  }
}
