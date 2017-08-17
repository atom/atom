'use babel'

import Registry from 'winreg'
import Path from 'path'

let appPath = `\"${process.execPath}\"`
let fileIconPath = `\"${Path.join(process.execPath, '..', 'resources', 'cli', 'file.ico')}\"`

class ClassesOption {
  constructor (parts) {
    this.isRegistered = this.isRegistered.bind(this)
    this.register = this.register.bind(this)
    this.deregister = this.deregister.bind(this)
    this.update = this.update.bind(this)
    this.parts = parts
  }

  isRegistered (part, callback) {
    new Registry({hive: 'HKCR', key: this.parts[0].key})
      .get(part.name, (err, val) => callback((err == null) && (val != null) && val.value === this.parts[0].value))
  }

  register (callback) {
    let doneCount = this.parts.length
    this.parts.forEach(part => {
      let reg = new Registry({hive: 'HKCR', key: part.key})
      return reg.create(() => reg.set(part.name, Registry.REG_SZ, part.value, () => { if (--doneCount === 0) return callback() }))
    })
  }

  deregister (callback) {
    this.parts.forEach(part => {
      this.isRegistered(part, isRegistered => {
        if (isRegistered) {
          new Registry({hive: 'HKCR', key: part.key}).destroy(() => callback(null, true))
        } else {
          callback(null, false)
        }
      })
    })
  }

  update (callback) {
    new Registry({hive: 'HKCR', key: this.parts[0].key})
      .get(this.parts[0].name, (err, val) => {
        if ((err != null) || (val == null)) {
          callback(err)
        } else {
          this.register(callback)
        }
      })
  }
}

exports.protocolHandler = new ClassesOption('',
  [
    {key: 'atm', name: '', value: 'URL:Atom Text Editor Protocol'},
    {key: 'atm', name: 'URL Protocol', value: ''},
    {key: 'atom\\DefaultIcon', name: '', value: fileIconPath},
    {key: 'atm\\shell\\open\\command', name: '', value: `${appPath} \"%1\"`}
  ]
)
