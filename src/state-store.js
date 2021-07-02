'use strict';

module.exports = class StateStore {
  constructor(databaseName, version) {
    this.connected = false;
    this.databaseName = databaseName;
    this.version = version;
  }

  get dbPromise() {
    if (!this._dbPromise) {
      this._dbPromise = new Promise(resolve => {
        const dbOpenRequest = indexedDB.open(this.databaseName, this.version);
        dbOpenRequest.onupgradeneeded = event => {
          let db = event.target.result;
          db.onerror = error => {
            atom.notifications.addFatalError('Error loading database', {
              stack: new Error('Error loading database').stack,
              dismissable: true
            });
            console.error('Error loading database', error);
          };
          db.createObjectStore('states');
        };
        dbOpenRequest.onsuccess = () => {
          this.connected = true;
          resolve(dbOpenRequest.result);
        };
        dbOpenRequest.onerror = error => {
          atom.notifications.addFatalError('Could not connect to indexedDB', {
            stack: new Error('Could not connect to indexedDB').stack,
            dismissable: true
          });
          console.error('Could not connect to indexedDB', error);
          this.connected = false;
          resolve(null);
        };
      });
    }

    return this._dbPromise;
  }

  isConnected() {
    return this.connected;
  }

  connect() {
    return this.dbPromise.then(db => !!db);
  }

  save(key, value) {
    return new Promise((resolve, reject) => {
      this.dbPromise.then(db => {
        if (db == null) return resolve();

        const request = db
          .transaction(['states'], 'readwrite')
          .objectStore('states')
          .put({ value: value, storedAt: new Date().toString() }, key);

        request.onsuccess = resolve;
        request.onerror = reject;
      });
    });
  }

  load(key) {
    return this.dbPromise.then(db => {
      if (!db) return;

      return new Promise((resolve, reject) => {
        const request = db
          .transaction(['states'])
          .objectStore('states')
          .get(key);

        request.onsuccess = event => {
          let result = event.target.result;
          if (result && !result.isJSON) {
            resolve(result.value);
          } else {
            resolve(null);
          }
        };

        request.onerror = event => reject(event);
      });
    });
  }

  delete(key) {
    return new Promise((resolve, reject) => {
      this.dbPromise.then(db => {
        if (db == null) return resolve();

        const request = db
          .transaction(['states'], 'readwrite')
          .objectStore('states')
          .delete(key);

        request.onsuccess = resolve;
        request.onerror = reject;
      });
    });
  }

  clear() {
    return this.dbPromise.then(db => {
      if (!db) return;

      return new Promise((resolve, reject) => {
        const request = db
          .transaction(['states'], 'readwrite')
          .objectStore('states')
          .clear();

        request.onsuccess = resolve;
        request.onerror = reject;
      });
    });
  }

  count() {
    return this.dbPromise.then(db => {
      if (!db) return;

      return new Promise((resolve, reject) => {
        const request = db
          .transaction(['states'])
          .objectStore('states')
          .count();

        request.onsuccess = () => {
          resolve(request.result);
        };
        request.onerror = reject;
      });
    });
  }
};
