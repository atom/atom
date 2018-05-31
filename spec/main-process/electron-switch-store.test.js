const temp = require('temp').track()
const fs = require('fs-plus')
const path = require('path')
const ElectronSwitchStore = require('../../src/main-process/electron-switch-store')

describe.only('entries()', function () {
  let userDataDir, electronSwitchesFilePath

  beforeEach(() => {
    userDataDir = fs.realpathSync(temp.mkdirSync('atom-home'))
    electronSwitchesFilePath = path.join(userDataDir, '.electron-switches')
  })

  afterEach(async () => {
    if (fs.existsSync(electronSwitchesFilePath)) {
      fs.unlinkSync(electronSwitchesFilePath)
    }
  })

  it('returns an iterator over each switch specified in the config file', () => {
    const fileContents = '\n' +
      'force-color-profile srgb\n' +
      'foo bar'

    fs.writeFileSync(electronSwitchesFilePath, fileContents)

    const store = new ElectronSwitchStore({filePath: electronSwitchesFilePath})
    const entries = new Map(store.entries())
    assert.equal(entries.size, 2)
    assert.equal(entries.get('force-color-profile'), 'srgb')
    assert.equal(entries.get('foo'), 'bar')
  })

  it('returns an empty iterator when the config file does not exist', () => {
    assert(!fs.existsSync(electronSwitchesFilePath))
    const store = new ElectronSwitchStore({filePath: electronSwitchesFilePath})
    const entries = new Map(store.entries())
    assert.equal(entries.size, 0)
  })

  it('returns an empty iterator when the config file is empty', () => {
    fs.writeFileSync(electronSwitchesFilePath, '')
    const store = new ElectronSwitchStore({filePath: electronSwitchesFilePath})
    const entries = new Map(store.entries())
    assert.equal(entries.size, 0)
  })
})
