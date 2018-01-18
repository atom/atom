const path = require('path')
const fs = require('fs-plus')

module.exports =
class StorageFolder {
  constructor (containingPath) {
    if (containingPath) {
      this.path = path.join(containingPath, 'storage')
    }
  }

  clear () {
    return new Promise(resolve => {
      if (!this.path) return
      fs.remove(this.path, error => {
        if (error) console.warn(`Error deleting ${this.path}`, error.stack, error)
        reolve()
      })
    })
  }

  storeSync (name, object) {
    if (!this.path) return

    fs.writeFileSync(this.pathForKey(name), JSON.stringify(object), 'utf8')
  }

  load (name) {
    if (!this.path) return

    const statePath = this.pathForKey(name)

    let stateString
    try {
      stateString = fs.readFileSync(statePath, 'utf8')
    } catch (error) {
      if (error.code !== 'ENOENT') {
        console.warn(`Error reading state file: ${statePath}`, error.stack, error)
      }
      return null
    }

    try {
      return JSON.parse(stateString)
    } catch (error) {
      console.warn(`Error parsing state file: ${statePath}`, error.stack, error)
    }
  }

  pathForKey (name) {
    return path.join(this.getPath(), name)
  }

  getPath () {
    return this.path
  }
}
