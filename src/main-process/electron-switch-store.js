const fs = require('fs')

module.exports =
class ElectronSwitchStore {
  constructor ({filePath}) {
    this.store = this.load(filePath)
  }

  entries () {
    return this.store.entries()
  }

  // Private
  load (filePath) {
    const map = new Map()

    if (fs.existsSync(filePath)) {
      const lines = fs.readFileSync(filePath, 'utf8').split(/\r?\n/g)
      for (const line of lines) {
        const indexOfNameValueSeparator = line.indexOf(' ')
        const name = line.slice(0, indexOfNameValueSeparator)
        const value = line.slice(indexOfNameValueSeparator + 1)
        if (name.length > 0) {
          map.set(name, value)
        }
      }
    }

    return map
  }
}
