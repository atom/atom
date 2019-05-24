const fs = require('fs-plus')
const path = require('path')
const season = require('season')
const temp = require('temp').track()
const runAtom = require('./helpers/start-atom')

describe('Smoke Test', () => {
  // Fails on win32
  if (process.platform !== 'darwin') {
    return
  }

  const atomHome = temp.mkdirSync('atom-home')

  beforeEach(() => {
    jasmine.useRealClock()
    season.writeFileSync(path.join(atomHome, 'config.cson'), {
      '*': {
        welcome: {showOnStartup: false},
        core: {
          telemetryConsent: 'no',
          disabledPackages: ['github']
        }
      }
    })
  })

  it('can open a file in Atom and perform basic operations on it', async () => {
    const tempDirPath = temp.mkdirSync('empty-dir')
    const filePath = path.join(tempDirPath, 'new-file')

    fs.writeFileSync(filePath, '', {encoding: 'utf8'})

    runAtom([filePath], {ATOM_HOME: atomHome}, async client => {
      const roots = await client.treeViewRootDirectories()
      expect(roots).toEqual([])

      await client.$('atom-text-editor').waitForExist(5000)

      await client.waitForPaneItemCount(1, 1000)

      client.$('atom-text-editor').click()

      await client.waitUntil(function () {
        return this.execute(() => document.activeElement.closest('atom-text-editor'))
      }, 5000)

      const text = client.keys('Hello!').execute(() => atom.workspace.getActiveTextEditor().getText())
      expect(text).toBe('Hello!')

      await client.dispatchCommand('editor:delete-line')
    })
  })
})
