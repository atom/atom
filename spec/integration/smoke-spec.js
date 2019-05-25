const fs = require('fs-plus')
const path = require('path')
const season = require('season')
const temp = require('temp').track()
const runAtom = require('./helpers/start-atom')

fdescribe('Smoke Test', () => {
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

    runAtom([tempDirPath], {ATOM_HOME: atomHome}, async client => {
      console.log('>>> Waiting for root directories')
      const roots = await client.treeViewRootDirectories()
      expect(roots).toEqual([tempDirPath])

      console.log('>>> Waiting for editor to open')
      await client.execute(async filePath => await atom.workspace.open(filePath), filePath)

      console.log('>>> Waiting for editor to exist')
      const textEditorElement = await client.$('atom-text-editor')
      await textEditorElement.waitForExist(5000)

      console.log('>>> Waiting for there to be one pane item')
      await client.waitForPaneItemCount(1, 1000)

      textEditorElement.click()

      console.log('>>> Waiting for active element to be atom-text-editor')
      await client.waitUntil(function () {
        return this.execute(() => document.activeElement.closest('atom-text-editor'))
      }, 5000)

      console.log('>>> Waiting for text to be inserted')
      await client.keys('Hello!')

      console.log('>>> Waiting for text')
      const text = await client.execute(() => atom.workspace.getActiveTextEditor().getText())
      expect(text).toBe('Hello!')

      console.log('>>> Waiting to delete line')
      await client.dispatchCommand('editor:delete-line')

      console.log('>>> Done!')
    })
  })
})
