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
    return new Promise((resolve, reject) => {
      this.dbPromise.then(db => {
        if (db == null) return resolve()

        var request = db.transaction(['states'], 'readwrite')
          .objectStore('states')
          .put({value: value, storedAt: new Date().toString()}, key)

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
          if (result && !result.isJSON) {
            resolve(result.value)
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
