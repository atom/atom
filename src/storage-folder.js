import path from 'path'
import fs from 'fs-plus'

export default class StorageFolder {
  constructor (containingPath) {
    if (containingPath) {
      this.path = path.join(containingPath, 'storage')
    }
  }

  clear () {
    if (!this.path) return

    try {
      return fs.removeSync(this.path)
    } catch (error) {
      console.warn(`Error deleting ${this.path}`, error.stack, error)
    }
  }

  storeSync (name, object) {
    if (!this.path) return

    return fs.writeFileSync(this.pathForKey(name), JSON.stringify(object), 'utf8')
  }

  load (name) {
    if (!this.path) return

    let statePath = this.pathForKey(name)
    let stateString
    try {
      stateString = fs.readFileSync(statePath, 'utf8')
    } catch (error) {
      if (error.code !== 'ENOENT') {
        console.warn(`Error reading state file: ${statePath}`, error.stack, error)
      }
      return
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
