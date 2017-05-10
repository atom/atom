/** @babel */

/* global advanceClock, HTMLElement, waits */

const path = require('path')
const temp = require('temp').track()
const TextEditor = require('../src/text-editor')
const Workspace = require('../src/workspace')
const Project = require('../src/project')
const platform = require('./spec-helper-platform')
const _ = require('underscore-plus')
const fstream = require('fstream')
const fs = require('fs-plus')
const AtomEnvironment = require('../src/atom-environment')
const {it, fit, ffit, fffit, beforeEach, afterEach} = require('./async-spec-helpers')

describe('Workspace', () => {
  let workspace
  let setDocumentEdited

  beforeEach(() => {
    workspace = atom.workspace
    workspace.resetFontSize()
    spyOn(atom.applicationDelegate, 'confirm')
    setDocumentEdited = spyOn(atom.applicationDelegate, 'setWindowDocumentEdited')
    atom.project.setPaths([atom.project.getDirectories()[0].resolve('dir')])
    waits(1)

    waitsForPromise(() => atom.workspace.itemLocationStore.clear())
  })

  afterEach(() => temp.cleanupSync())

  describe('serialization', () => {
    const simulateReload = () => {
      const workspaceState = atom.workspace.serialize()
      const projectState = atom.project.serialize({isUnloading: true})
      atom.workspace.destroy()
      atom.project.destroy()
      atom.project = new Project({
        notificationManager: atom.notifications,
        packageManager: atom.packages,
        confirm: atom.confirm.bind(atom),
        applicationDelegate: atom.applicationDelegate
      })
      atom.project.deserialize(projectState)
      atom.workspace = new Workspace({
        config: atom.config,
        project: atom.project,
        packageManager: atom.packages,
        grammarRegistry: atom.grammars,
        styleManager: atom.styles,
        deserializerManager: atom.deserializers,
        notificationManager: atom.notifications,
        applicationDelegate: atom.applicationDelegate,
        viewRegistry: atom.views,
        assert: atom.assert.bind(atom),
        textEditorRegistry: atom.textEditors
      })
      return atom.workspace.deserialize(workspaceState, atom.deserializers)
    }

    describe('when the workspace contains text editors', () => {
      it('constructs the view with the same panes', () => {
        const pane1 = atom.workspace.getActivePane()
        const pane2 = pane1.splitRight({copyActiveItem: true})
        const pane3 = pane2.splitRight({copyActiveItem: true})
        let pane4 = null

        waitsForPromise(() => atom.workspace.open(null).then(editor => editor.setText('An untitled editor.')))

        waitsForPromise(() =>
          atom.workspace.open('b').then(editor => pane2.activateItem(editor.copy()))
        )

        waitsForPromise(() =>
          atom.workspace.open('../sample.js').then(editor => pane3.activateItem(editor))
        )

        runs(() => {
          pane3.activeItem.setCursorScreenPosition([2, 4])
          pane4 = pane2.splitDown()
        })

        waitsForPromise(() =>
          atom.workspace.open('../sample.txt').then(editor => pane4.activateItem(editor))
        )

        runs(() => {
          pane4.getActiveItem().setCursorScreenPosition([0, 2])
          pane2.activate()

          simulateReload()

          expect(atom.workspace.getTextEditors().length).toBe(5)
          const [editor1, editor2, untitledEditor, editor3, editor4] = atom.workspace.getTextEditors()
          const firstDirectory = atom.project.getDirectories()[0]
          expect(firstDirectory).toBeDefined()
          expect(editor1.getPath()).toBe(firstDirectory.resolve('b'))
          expect(editor2.getPath()).toBe(firstDirectory.resolve('../sample.txt'))
          expect(editor2.getCursorScreenPosition()).toEqual([0, 2])
          expect(editor3.getPath()).toBe(firstDirectory.resolve('b'))
          expect(editor4.getPath()).toBe(firstDirectory.resolve('../sample.js'))
          expect(editor4.getCursorScreenPosition()).toEqual([2, 4])
          expect(untitledEditor.getPath()).toBeUndefined()
          expect(untitledEditor.getText()).toBe('An untitled editor.')

          expect(atom.workspace.getActiveTextEditor().getPath()).toBe(editor3.getPath())
          const pathEscaped = fs.tildify(escapeStringRegex(atom.project.getPaths()[0]))
          expect(document.title).toMatch(new RegExp(`^${path.basename(editor3.getLongTitle())} \\u2014 ${pathEscaped}`))
        })
      })
    })

    describe('where there are no open panes or editors', () => {
      it('constructs the view with no open editors', () => {
        atom.workspace.getActivePane().destroy()
        expect(atom.workspace.getTextEditors().length).toBe(0)
        simulateReload()
        expect(atom.workspace.getTextEditors().length).toBe(0)
      })
    })

    describe('where a dock contains an editor', () => {
      afterEach(() => {
        atom.workspace.getRightDock().paneContainer.destroy()
      })

      it('constructs the view with the same panes', () => {
        const pane1 = atom.workspace.getRightDock().getActivePane()
        const pane2 = pane1.splitRight({copyActiveItem: true})
        const pane3 = pane2.splitRight({copyActiveItem: true})
        let pane4 = null

        waitsForPromise(() =>
          atom.workspace.open(null, {location: 'right'}).then(editor => editor.setText('An untitled editor.'))
        )

        waitsForPromise(() =>
          atom.workspace.open('b', {location: 'right'}).then(editor => pane2.activateItem(editor.copy()))
        )

        waitsForPromise(() =>
          atom.workspace.open('../sample.js', {location: 'right'}).then(editor => pane3.activateItem(editor))
        )

        runs(() => {
          pane3.activeItem.setCursorScreenPosition([2, 4])
          pane4 = pane2.splitDown()
        })

        waitsForPromise(() =>
          atom.workspace.open('../sample.txt', {location: 'right'}).then(editor => pane4.activateItem(editor))
        )

        runs(() => {
          pane4.getActiveItem().setCursorScreenPosition([0, 2])
          pane2.activate()

          simulateReload()

          expect(atom.workspace.getTextEditors().length).toBe(5)
          const [editor1, editor2, untitledEditor, editor3, editor4] = atom.workspace.getTextEditors()
          const firstDirectory = atom.project.getDirectories()[0]
          expect(firstDirectory).toBeDefined()
          expect(editor1.getPath()).toBe(firstDirectory.resolve('b'))
          expect(editor2.getPath()).toBe(firstDirectory.resolve('../sample.txt'))
          expect(editor2.getCursorScreenPosition()).toEqual([0, 2])
          expect(editor3.getPath()).toBe(firstDirectory.resolve('b'))
          expect(editor4.getPath()).toBe(firstDirectory.resolve('../sample.js'))
          expect(editor4.getCursorScreenPosition()).toEqual([2, 4])
          expect(untitledEditor.getPath()).toBeUndefined()
          expect(untitledEditor.getText()).toBe('An untitled editor.')

          expect(atom.workspace.getRightDock().getActiveTextEditor().getPath()).toBe(editor3.getPath())
        })
      })
    })
  })

  describe('::open(itemOrURI, options)', () => {
    let openEvents = null

    beforeEach(() => {
      openEvents = []
      workspace.onDidOpen(event => openEvents.push(event))
      spyOn(workspace.getActivePane(), 'activate').andCallThrough()
    })

    describe("when the 'searchAllPanes' option is false (default)", () => {
      describe('when called without a uri or item', () => {
        it('adds and activates an empty editor on the active pane', () => {
          let editor1
          let editor2

          waitsForPromise(() => workspace.open().then(editor => { editor1 = editor }))

          runs(() => {
            expect(editor1.getPath()).toBeUndefined()
            expect(workspace.getActivePane().items).toEqual([editor1])
            expect(workspace.getActivePaneItem()).toBe(editor1)
            expect(workspace.getActivePane().activate).toHaveBeenCalled()
            expect(openEvents).toEqual([{uri: undefined, pane: workspace.getActivePane(), item: editor1, index: 0}])
            openEvents = []
          })

          waitsForPromise(() => workspace.open().then(editor => { editor2 = editor }))

          runs(() => {
            expect(editor2.getPath()).toBeUndefined()
            expect(workspace.getActivePane().items).toEqual([editor1, editor2])
            expect(workspace.getActivePaneItem()).toBe(editor2)
            expect(workspace.getActivePane().activate).toHaveBeenCalled()
            expect(openEvents).toEqual([{uri: undefined, pane: workspace.getActivePane(), item: editor2, index: 1}])
          })
        })
      })

      describe('when called with a uri', () => {
        describe('when the active pane already has an editor for the given uri', () => {
          it('activates the existing editor on the active pane', () => {
            let editor = null
            let editor1 = null
            let editor2 = null

            waitsForPromise(() =>
              workspace.open('a').then(o => {
                editor1 = o
                return workspace.open('b').then(o => {
                  editor2 = o
                  return workspace.open('a').then(o => { editor = o })
                })
              })
            )

            runs(() => {
              expect(editor).toBe(editor1)
              expect(workspace.getActivePaneItem()).toBe(editor)
              expect(workspace.getActivePane().activate).toHaveBeenCalled()
              const firstDirectory = atom.project.getDirectories()[0]
              expect(firstDirectory).toBeDefined()
              expect(openEvents).toEqual([
                {
                  uri: firstDirectory.resolve('a'),
                  item: editor1,
                  pane: atom.workspace.getActivePane(),
                  index: 0
                },
                {
                  uri: firstDirectory.resolve('b'),
                  item: editor2,
                  pane: atom.workspace.getActivePane(),
                  index: 1
                },
                {
                  uri: firstDirectory.resolve('a'),
                  item: editor1,
                  pane: atom.workspace.getActivePane(),
                  index: 0
                }
              ])
            })
          })

          it('finds items in docks', () => {
            const dock = atom.workspace.getRightDock()
            const ITEM_URI = 'atom://test'
            const item = {
              getURI: () => ITEM_URI,
              getDefaultLocation: () => 'left',
              getElement: () => document.createElement('div')
            }
            dock.getActivePane().addItem(item)
            expect(dock.getPaneItems()).toHaveLength(1)
            waitsForPromise(() => atom.workspace.open(ITEM_URI, {searchAllPanes: true}))
            runs(() => {
              expect(atom.workspace.getPaneItems()).toHaveLength(1)
              expect(dock.getPaneItems()).toHaveLength(1)
              expect(dock.getPaneItems()[0]).toBe(item)
            })
          })
        })

        describe("when the 'activateItem' option is false", () => {
          it('adds the item to the workspace', () => {
            let editor
            waitsForPromise(() => workspace.open('a'))
            waitsForPromise(() => workspace.open('b', {activateItem: false}).then(o => { editor = o }))
            runs(() => {
              expect(workspace.getPaneItems()).toContain(editor)
              expect(workspace.getActivePaneItem()).not.toBe(editor)
            })
          })
        })

        describe('when the active pane does not have an editor for the given uri', () => {
          beforeEach(() => {
            atom.workspace.enablePersistence = true
          })

          afterEach(async () => {
            await atom.workspace.itemLocationStore.clear()
            atom.workspace.enablePersistence = false
          })

          it('adds and activates a new editor for the given path on the active pane', () => {
            let editor = null
            waitsForPromise(() => workspace.open('a').then(o => { editor = o }))

            runs(() => {
              const firstDirectory = atom.project.getDirectories()[0]
              expect(firstDirectory).toBeDefined()
              expect(editor.getURI()).toBe(firstDirectory.resolve('a'))
              expect(workspace.getActivePaneItem()).toBe(editor)
              expect(workspace.getActivePane().items).toEqual([editor])
              expect(workspace.getActivePane().activate).toHaveBeenCalled()
            })
          })

          it("uses the location specified by the model's `getDefaultLocation()` method", () => {
            const item = {
              getDefaultLocation: jasmine.createSpy().andReturn('right'),
              getElement: () => document.createElement('div')
            }
            const opener = jasmine.createSpy().andReturn(item)
            const dock = atom.workspace.getRightDock()
            spyOn(atom.workspace.itemLocationStore, 'load').andReturn(Promise.resolve())
            spyOn(atom.workspace, 'getOpeners').andReturn([opener])
            expect(dock.getPaneItems()).toHaveLength(0)
            waitsForPromise(() => atom.workspace.open('a'))
            runs(() => {
              expect(dock.getPaneItems()).toHaveLength(1)
              expect(opener).toHaveBeenCalled()
              expect(item.getDefaultLocation).toHaveBeenCalled()
            })
          })

          it('prefers the last location the user used for that item', () => {
            const ITEM_URI = 'atom://test'
            const item = {
              getURI: () => ITEM_URI,
              getDefaultLocation: () => 'left',
              getElement: () => document.createElement('div')
            }
            const opener = uri => uri === ITEM_URI ? item : null
            const dock = atom.workspace.getRightDock()
            spyOn(atom.workspace.itemLocationStore, 'load').andCallFake(uri =>
              uri === 'atom://test' ? Promise.resolve('right') : Promise.resolve()
            )
            spyOn(atom.workspace, 'getOpeners').andReturn([opener])
            expect(dock.getPaneItems()).toHaveLength(0)
            waitsForPromise(() => atom.workspace.open(ITEM_URI))
            runs(() => {
              expect(dock.getPaneItems()).toHaveLength(1)
              expect(dock.getPaneItems()[0]).toBe(item)
            })
          })
        })
      })

      describe('when an item with the given uri exists in an inactive pane container', () => {
        it('activates that item if it is in that container\'s active pane', async () => {
          const item = await atom.workspace.open('a')
          atom.workspace.getLeftDock().activate()
          expect(await atom.workspace.open('a', {searchAllPanes: false})).toBe(item)
          expect(atom.workspace.getActivePaneContainer().getLocation()).toBe('center')
          expect(atom.workspace.getPaneItems()).toEqual([item])

          atom.workspace.getActivePane().splitRight()
          atom.workspace.getLeftDock().activate()
          const item2 = await atom.workspace.open('a', {searchAllPanes: false})
          expect(item2).not.toBe(item)
          expect(atom.workspace.getActivePaneContainer().getLocation()).toBe('center')
          expect(atom.workspace.getPaneItems()).toEqual([item, item2])
        })
      })
    })

    describe("when the 'searchAllPanes' option is true", () => {
      describe('when an editor for the given uri is already open on an inactive pane', () => {
        it('activates the existing editor on the inactive pane, then activates that pane', () => {
          let editor1 = null
          let editor2 = null
          const pane1 = workspace.getActivePane()
          const pane2 = workspace.getActivePane().splitRight()

          waitsForPromise(() => {
            pane1.activate()
            return workspace.open('a').then(o => { editor1 = o })
          })

          waitsForPromise(() => {
            pane2.activate()
            return workspace.open('b').then(o => { editor2 = o })
          })

          runs(() => expect(workspace.getActivePaneItem()).toBe(editor2))

          waitsForPromise(() => workspace.open('a', {searchAllPanes: true}))

          runs(() => {
            expect(workspace.getActivePane()).toBe(pane1)
            expect(workspace.getActivePaneItem()).toBe(editor1)
          })
        })

        it('activates the pane in the dock with the matching item', () => {
          const dock = atom.workspace.getRightDock()
          const ITEM_URI = 'atom://test'
          const item = {
            getURI: () => ITEM_URI,
            getDefaultLocation: jasmine.createSpy().andReturn('left'),
            getElement: () => document.createElement('div')
          }
          dock.getActivePane().addItem(item)
          spyOn(dock.paneForItem(item), 'activate')
          waitsForPromise(() => atom.workspace.open(ITEM_URI, {searchAllPanes: true}))
          runs(() => expect(dock.paneForItem(item).activate).toHaveBeenCalled())
        })
      })

      describe('when no editor for the given uri is open in any pane', () => {
        it('opens an editor for the given uri in the active pane', () => {
          let editor = null
          waitsForPromise(() => workspace.open('a', {searchAllPanes: true}).then(o => { editor = o }))

          runs(() => expect(workspace.getActivePaneItem()).toBe(editor))
        })
      })
    })

    describe('when called with an item rather than a URI', () => {
      it('adds the item itself to the workspace', async () => {
        const item = document.createElement('div')
        await atom.workspace.open(item)
        expect(atom.workspace.getActivePaneItem()).toBe(item)
      })

      describe('when the active pane already contains the item', () => {
        it('activates the item', async () => {
          const item = document.createElement('div')

          await atom.workspace.open(item)
          await atom.workspace.open()
          expect(atom.workspace.getActivePaneItem()).not.toBe(item)
          expect(atom.workspace.getActivePane().getItems().length).toBe(2)

          await atom.workspace.open(item)
          expect(atom.workspace.getActivePaneItem()).toBe(item)
          expect(atom.workspace.getActivePane().getItems().length).toBe(2)
        })
      })

      describe('when the item already exists in another pane', () => {
        it('rejects the promise', async () => {
          const item = document.createElement('div')

          await atom.workspace.open(item)
          await atom.workspace.open(null, {split: 'right'})
          expect(atom.workspace.getActivePaneItem()).not.toBe(item)
          expect(atom.workspace.getActivePane().getItems().length).toBe(1)

          let rejection
          try {
            await atom.workspace.open(item)
          } catch (error) {
            rejection = error
          }

          expect(rejection.message).toMatch(/The workspace can only contain one instance of item/)
        })
      })
    })

    describe("when the 'split' option is set", () => {
      describe("when the 'split' option is 'left'", () => {
        it('opens the editor in the leftmost pane of the current pane axis', () => {
          const pane1 = workspace.getActivePane()
          const pane2 = pane1.splitRight()
          expect(workspace.getActivePane()).toBe(pane2)

          let editor = null
          waitsForPromise(() => workspace.open('a', {split: 'left'}).then(o => { editor = o }))

          runs(() => {
            expect(workspace.getActivePane()).toBe(pane1)
            expect(pane1.items).toEqual([editor])
            expect(pane2.items).toEqual([])
          })

          // Focus right pane and reopen the file on the left
          waitsForPromise(() => {
            pane2.focus()
            return workspace.open('a', {split: 'left'}).then(o => { editor = o })
          })

          runs(() => {
            expect(workspace.getActivePane()).toBe(pane1)
            expect(pane1.items).toEqual([editor])
            expect(pane2.items).toEqual([])
          })
        })
      })

      describe('when a pane axis is the leftmost sibling of the current pane', () => {
        it('opens the new item in the current pane', () => {
          let editor = null
          const pane1 = workspace.getActivePane()
          const pane2 = pane1.splitLeft()
          pane2.splitDown()
          pane1.activate()
          expect(workspace.getActivePane()).toBe(pane1)

          waitsForPromise(() => workspace.open('a', {split: 'left'}).then(o => { editor = o }))

          runs(() => {
            expect(workspace.getActivePane()).toBe(pane1)
            expect(pane1.items).toEqual([editor])
          })
        })
      })

      describe("when the 'split' option is 'right'", () => {
        it('opens the editor in the rightmost pane of the current pane axis', () => {
          let editor = null
          const pane1 = workspace.getActivePane()
          let pane2 = null
          waitsForPromise(() => workspace.open('a', {split: 'right'}).then(o => { editor = o }))

          runs(() => {
            pane2 = workspace.getPanes().filter(p => p !== pane1)[0]
            expect(workspace.getActivePane()).toBe(pane2)
            expect(pane1.items).toEqual([])
            expect(pane2.items).toEqual([editor])
          })

          // Focus right pane and reopen the file on the right
          waitsForPromise(() => {
            pane1.focus()
            return workspace.open('a', {split: 'right'}).then(o => { editor = o })
          })

          runs(() => {
            expect(workspace.getActivePane()).toBe(pane2)
            expect(pane1.items).toEqual([])
            expect(pane2.items).toEqual([editor])
          })
        })

        describe('when a pane axis is the rightmost sibling of the current pane', () => {
          it('opens the new item in a new pane split to the right of the current pane', () => {
            let editor = null
            const pane1 = workspace.getActivePane()
            const pane2 = pane1.splitRight()
            pane2.splitDown()
            pane1.activate()
            expect(workspace.getActivePane()).toBe(pane1)
            let pane4 = null

            waitsForPromise(() => workspace.open('a', {split: 'right'}).then(o => { editor = o }))

            runs(() => {
              pane4 = workspace.getPanes().filter(p => p !== pane1)[0]
              expect(workspace.getActivePane()).toBe(pane4)
              expect(pane4.items).toEqual([editor])
              expect(workspace.getCenter().paneContainer.root.children[0]).toBe(pane1)
              expect(workspace.getCenter().paneContainer.root.children[1]).toBe(pane4)
            })
          })
        })
      })

      describe("when the 'split' option is 'up'", () => {
        it('opens the editor in the topmost pane of the current pane axis', () => {
          const pane1 = workspace.getActivePane()
          const pane2 = pane1.splitDown()
          expect(workspace.getActivePane()).toBe(pane2)

          let editor = null
          waitsForPromise(() => workspace.open('a', {split: 'up'}).then(o => { editor = o }))

          runs(() => {
            expect(workspace.getActivePane()).toBe(pane1)
            expect(pane1.items).toEqual([editor])
            expect(pane2.items).toEqual([])
          })

          // Focus bottom pane and reopen the file on the top
          waitsForPromise(() => {
            pane2.focus()
            return workspace.open('a', {split: 'up'}).then(o => { editor = o })
          })

          runs(() => {
            expect(workspace.getActivePane()).toBe(pane1)
            expect(pane1.items).toEqual([editor])
            expect(pane2.items).toEqual([])
          })
        })
      })

      describe('when a pane axis is the topmost sibling of the current pane', () => {
        it('opens the new item in the current pane', () => {
          let editor = null
          const pane1 = workspace.getActivePane()
          const pane2 = pane1.splitUp()
          pane2.splitRight()
          pane1.activate()
          expect(workspace.getActivePane()).toBe(pane1)

          waitsForPromise(() => workspace.open('a', {split: 'up'}).then(o => { editor = o }))

          runs(() => {
            expect(workspace.getActivePane()).toBe(pane1)
            expect(pane1.items).toEqual([editor])
          })
        })
      })

      describe("when the 'split' option is 'down'", () => {
        it('opens the editor in the bottommost pane of the current pane axis', () => {
          let editor = null
          const pane1 = workspace.getActivePane()
          let pane2 = null
          waitsForPromise(() => workspace.open('a', {split: 'down'}).then(o => { editor = o }))

          runs(() => {
            pane2 = workspace.getPanes().filter(p => p !== pane1)[0]
            expect(workspace.getActivePane()).toBe(pane2)
            expect(pane1.items).toEqual([])
            expect(pane2.items).toEqual([editor])
          })

          // Focus bottom pane and reopen the file on the right
          waitsForPromise(() => {
            pane1.focus()
            return workspace.open('a', {split: 'down'}).then(o => { editor = o })
          })

          runs(() => {
            expect(workspace.getActivePane()).toBe(pane2)
            expect(pane1.items).toEqual([])
            expect(pane2.items).toEqual([editor])
          })
        })

        describe('when a pane axis is the bottommost sibling of the current pane', () => {
          it('opens the new item in a new pane split to the bottom of the current pane', () => {
            let editor = null
            const pane1 = workspace.getActivePane()
            const pane2 = pane1.splitDown()
            pane1.activate()
            expect(workspace.getActivePane()).toBe(pane1)
            let pane4 = null

            waitsForPromise(() => workspace.open('a', {split: 'down'}).then(o => { editor = o }))

            runs(() => {
              pane4 = workspace.getPanes().filter(p => p !== pane1)[0]
              expect(workspace.getActivePane()).toBe(pane4)
              expect(pane4.items).toEqual([editor])
              expect(workspace.getCenter().paneContainer.root.children[0]).toBe(pane1)
              expect(workspace.getCenter().paneContainer.root.children[1]).toBe(pane2)
            })
          })
        })
      })
    })

    describe('when an initialLine and initialColumn are specified', () => {
      it('moves the cursor to the indicated location', () => {
        waitsForPromise(() => workspace.open('a', {initialLine: 1, initialColumn: 5}))

        runs(() => expect(workspace.getActiveTextEditor().getCursorBufferPosition()).toEqual([1, 5]))

        waitsForPromise(() => workspace.open('a', {initialLine: 2, initialColumn: 4}))

        runs(() => expect(workspace.getActiveTextEditor().getCursorBufferPosition()).toEqual([2, 4]))

        waitsForPromise(() => workspace.open('a', {initialLine: 0, initialColumn: 0}))

        runs(() => expect(workspace.getActiveTextEditor().getCursorBufferPosition()).toEqual([0, 0]))

        waitsForPromise(() => workspace.open('a', {initialLine: NaN, initialColumn: 4}))

        runs(() => expect(workspace.getActiveTextEditor().getCursorBufferPosition()).toEqual([0, 4]))

        waitsForPromise(() => workspace.open('a', {initialLine: 2, initialColumn: NaN}))

        runs(() => expect(workspace.getActiveTextEditor().getCursorBufferPosition()).toEqual([2, 0]))

        waitsForPromise(() => workspace.open('a', {initialLine: Infinity, initialColumn: Infinity}))

        runs(() => expect(workspace.getActiveTextEditor().getCursorBufferPosition()).toEqual([2, 11]))
      })
    })

    describe('when the file is over 2MB', () => {
      it('opens the editor with largeFileMode: true', () => {
        spyOn(fs, 'getSizeSync').andReturn(2 * 1048577) // 2MB

        let editor = null
        waitsForPromise(() => workspace.open('sample.js').then(e => { editor = e }))

        runs(() => expect(editor.largeFileMode).toBe(true))
      })
    })

    describe('when the file is over user-defined limit', () => {
      const shouldPromptForFileOfSize = (size, shouldPrompt) => {
        spyOn(fs, 'getSizeSync').andReturn(size * 1048577)
        atom.applicationDelegate.confirm.andCallFake(() => selectedButtonIndex)
        atom.applicationDelegate.confirm()
        var selectedButtonIndex = 1 // cancel

        let editor = null
        waitsForPromise(() => workspace.open('sample.js').then(e => { editor = e }))
        if (shouldPrompt) {
          runs(() => {
            expect(editor).toBeUndefined()
            expect(atom.applicationDelegate.confirm).toHaveBeenCalled()

            atom.applicationDelegate.confirm.reset()
            selectedButtonIndex = 0
          }) // open the file

          waitsForPromise(() => workspace.open('sample.js').then(e => { editor = e }))

          runs(() => {
            expect(atom.applicationDelegate.confirm).toHaveBeenCalled()
            expect(editor.largeFileMode).toBe(true)
          })
        } else {
          runs(() => expect(editor).not.toBeUndefined())
        }
      }

      it('prompts the user to make sure they want to open a file this big', () => {
        atom.config.set('core.warnOnLargeFileLimit', 20)
        shouldPromptForFileOfSize(20, true)
      })

      it("doesn't prompt on files below the limit", () => {
        atom.config.set('core.warnOnLargeFileLimit', 30)
        shouldPromptForFileOfSize(20, false)
      })

      it('prompts for smaller files with a lower limit', () => {
        atom.config.set('core.warnOnLargeFileLimit', 5)
        shouldPromptForFileOfSize(10, true)
      })
    })

    describe('when passed a path that matches a custom opener', () => {
      it('returns the resource returned by the custom opener', () => {
        const fooOpener = (pathToOpen, options) => {
          if (pathToOpen != null ? pathToOpen.match(/\.foo/) : undefined) {
            return {foo: pathToOpen, options}
          }
        }
        const barOpener = (pathToOpen) => {
          if (pathToOpen != null ? pathToOpen.match(/^bar:\/\//) : undefined) {
            return {bar: pathToOpen}
          }
        }
        workspace.addOpener(fooOpener)
        workspace.addOpener(barOpener)

        waitsForPromise(() => {
          const pathToOpen = atom.project.getDirectories()[0].resolve('a.foo')
          return workspace.open(pathToOpen, {hey: 'there'}).then(item => expect(item).toEqual({foo: pathToOpen, options: {hey: 'there'}}))
        })

        waitsForPromise(() =>
          workspace.open('bar://baz').then(item => expect(item).toEqual({bar: 'bar://baz'})))
      })
    })

    it("adds the file to the application's recent documents list", () => {
      if (process.platform !== 'darwin') { return } // Feature only supported on macOS
      spyOn(atom.applicationDelegate, 'addRecentDocument')

      waitsForPromise(() => workspace.open())

      runs(() => expect(atom.applicationDelegate.addRecentDocument).not.toHaveBeenCalled())

      waitsForPromise(() => workspace.open('something://a/url'))

      runs(() => expect(atom.applicationDelegate.addRecentDocument).not.toHaveBeenCalled())

      waitsForPromise(() => workspace.open(__filename))

      runs(() => expect(atom.applicationDelegate.addRecentDocument).toHaveBeenCalledWith(__filename))
    })

    it('notifies ::onDidAddTextEditor observers', () => {
      const absolutePath = require.resolve('./fixtures/dir/a')
      const newEditorHandler = jasmine.createSpy('newEditorHandler')
      workspace.onDidAddTextEditor(newEditorHandler)

      let editor = null
      waitsForPromise(() => workspace.open(absolutePath).then(e => { editor = e }))

      runs(() => expect(newEditorHandler.argsForCall[0][0].textEditor).toBe(editor))
    })

    describe('when there is an error opening the file', () => {
      let notificationSpy = null
      beforeEach(() => atom.notifications.onDidAddNotification(notificationSpy = jasmine.createSpy()))

      describe('when a file does not exist', () => {
        it('creates an empty buffer for the specified path', () => {
          waitsForPromise(() => workspace.open('not-a-file.md'))

          runs(() => {
            const editor = workspace.getActiveTextEditor()
            expect(notificationSpy).not.toHaveBeenCalled()
            expect(editor.getPath()).toContain('not-a-file.md')
          })
        })
      })

      describe('when the user does not have access to the file', () => {
        beforeEach(() =>
          spyOn(fs, 'openSync').andCallFake(path => {
            const error = new Error(`EACCES, permission denied '${path}'`)
            error.path = path
            error.code = 'EACCES'
            throw error
          })
        )

        it('creates a notification', () => {
          waitsForPromise(() => workspace.open('file1'))

          runs(() => {
            expect(notificationSpy).toHaveBeenCalled()
            const notification = notificationSpy.mostRecentCall.args[0]
            expect(notification.getType()).toBe('warning')
            expect(notification.getMessage()).toContain('Permission denied')
            expect(notification.getMessage()).toContain('file1')
          })
        })
      })

      describe('when the the operation is not permitted', () => {
        beforeEach(() =>
          spyOn(fs, 'openSync').andCallFake(path => {
            const error = new Error(`EPERM, operation not permitted '${path}'`)
            error.path = path
            error.code = 'EPERM'
            throw error
          })
        )

        it('creates a notification', () => {
          waitsForPromise(() => workspace.open('file1'))

          runs(() => {
            expect(notificationSpy).toHaveBeenCalled()
            const notification = notificationSpy.mostRecentCall.args[0]
            expect(notification.getType()).toBe('warning')
            expect(notification.getMessage()).toContain('Unable to open')
            expect(notification.getMessage()).toContain('file1')
          })
        })
      })

      describe('when the the file is already open in windows', () => {
        beforeEach(() =>
          spyOn(fs, 'openSync').andCallFake(path => {
            const error = new Error(`EBUSY, resource busy or locked '${path}'`)
            error.path = path
            error.code = 'EBUSY'
            throw error
          })
        )

        it('creates a notification', () => {
          waitsForPromise(() => workspace.open('file1'))

          runs(() => {
            expect(notificationSpy).toHaveBeenCalled()
            const notification = notificationSpy.mostRecentCall.args[0]
            expect(notification.getType()).toBe('warning')
            expect(notification.getMessage()).toContain('Unable to open')
            expect(notification.getMessage()).toContain('file1')
          })
        })
      })

      describe('when there is an unhandled error', () => {
        beforeEach(() =>
          spyOn(fs, 'openSync').andCallFake(path => {
            throw new Error('I dont even know what is happening right now!!')
          })
        )

        it('rejects the promise', () => {
          waitsFor((done) => {
            workspace.open('file1').catch(error => {
              expect(error.message).toBe('I dont even know what is happening right now!!')
              done()
            })
          })
        })
      })
    })

    describe('when the file is already open in pending state', () => {
      it('should terminate the pending state', () => {
        let editor = null
        let pane = null

        waitsForPromise(() =>
          atom.workspace.open('sample.js', {pending: true}).then(o => {
            editor = o
            pane = atom.workspace.getActivePane()
          })
        )

        runs(() => expect(pane.getPendingItem()).toEqual(editor))

        waitsForPromise(() => atom.workspace.open('sample.js'))

        runs(() => expect(pane.getPendingItem()).toBeNull())
      })
    })

    describe('when opening will switch from a pending tab to a permanent tab', () => {
      it('keeps the pending tab open', () => {
        let editor1 = null
        let editor2 = null

        waitsForPromise(() =>
          atom.workspace.open('sample.txt').then(o => { editor1 = o })
        )

        waitsForPromise(() =>
          atom.workspace.open('sample2.txt', {pending: true}).then(o => { editor2 = o })
        )

        runs(() => {
          const pane = atom.workspace.getActivePane()
          pane.activateItem(editor1)
          expect(pane.getItems().length).toBe(2)
          expect(pane.getItems()).toEqual([editor1, editor2])
        })
      })
    })

    describe('when replacing a pending item which is the last item in a second pane', () => {
      it('does not destroy the pane even if core.destroyEmptyPanes is on', () => {
        atom.config.set('core.destroyEmptyPanes', true)
        let editor1 = null
        let editor2 = null
        const leftPane = atom.workspace.getActivePane()
        let rightPane = null

        waitsForPromise(() =>
          atom.workspace.open('sample.js', {pending: true, split: 'right'}).then(o => {
            editor1 = o
            rightPane = atom.workspace.getActivePane()
            spyOn(rightPane, 'destroy').andCallThrough()
          })
        )

        runs(() => {
          expect(leftPane).not.toBe(rightPane)
          expect(atom.workspace.getActivePane()).toBe(rightPane)
          expect(atom.workspace.getActivePane().getItems().length).toBe(1)
          expect(rightPane.getPendingItem()).toBe(editor1)
        })

        waitsForPromise(() =>
          atom.workspace.open('sample.txt', {pending: true}).then(o => { editor2 = o })
        )

        runs(() => {
          expect(rightPane.getPendingItem()).toBe(editor2)
          expect(rightPane.destroy.callCount).toBe(0)
        })
      })
    })
  })

  describe('finding items in the workspace', () => {
    it('can identify the pane and pane container for a given item or URI', () => {
      const uri = 'atom://test-pane-for-item'
      const item = {
        element: document.createElement('div'),
        getURI () { return uri }
      }

      atom.workspace.getActivePane().activateItem(item)
      expect(atom.workspace.paneForItem(item)).toBe(atom.workspace.getCenter().getActivePane())
      expect(atom.workspace.paneContainerForItem(item)).toBe(atom.workspace.getCenter())
      expect(atom.workspace.paneForURI(uri)).toBe(atom.workspace.getCenter().getActivePane())
      expect(atom.workspace.paneContainerForURI(uri)).toBe(atom.workspace.getCenter())

      atom.workspace.getActivePane().destroyActiveItem()
      atom.workspace.getLeftDock().getActivePane().activateItem(item)
      expect(atom.workspace.paneForItem(item)).toBe(atom.workspace.getLeftDock().getActivePane())
      expect(atom.workspace.paneContainerForItem(item)).toBe(atom.workspace.getLeftDock())
      expect(atom.workspace.paneForURI(uri)).toBe(atom.workspace.getLeftDock().getActivePane())
      expect(atom.workspace.paneContainerForURI(uri)).toBe(atom.workspace.getLeftDock())
    })
  })

  describe('::hide(uri)', () => {
    let item
    const URI = 'atom://hide-test'

    beforeEach(() => {
      const el = document.createElement('div')
      item = {
        getTitle: () => 'Item',
        getElement: () => el,
        getURI: () => URI
      }
    })

    describe('when called with a URI', () => {
      it('if the item for the given URI is in the center, removes it', () => {
        const pane = atom.workspace.getActivePane()
        pane.addItem(item)
        atom.workspace.hide(URI)
        expect(pane.getItems().length).toBe(0)
      })

      it('if the item for the given URI is in a dock, hides the dock', () => {
        const dock = atom.workspace.getLeftDock()
        const pane = dock.getActivePane()
        pane.addItem(item)
        dock.activate()
        expect(dock.isVisible()).toBe(true)
        const itemFound = atom.workspace.hide(URI)
        expect(itemFound).toBe(true)
        expect(dock.isVisible()).toBe(false)
      })
    })

    describe('when called with an item', () => {
      it('if the item is in the center, removes it', () => {
        const pane = atom.workspace.getActivePane()
        pane.addItem(item)
        atom.workspace.hide(item)
        expect(pane.getItems().length).toBe(0)
      })

      it('if the item is in a dock, hides the dock', () => {
        const dock = atom.workspace.getLeftDock()
        const pane = dock.getActivePane()
        pane.addItem(item)
        dock.activate()
        expect(dock.isVisible()).toBe(true)
        const itemFound = atom.workspace.hide(item)
        expect(itemFound).toBe(true)
        expect(dock.isVisible()).toBe(false)
      })
    })
  })

  describe('::toggle(itemOrUri)', () => {
    describe('when the location resolves to a dock', () => {
      it('adds or shows the item and its dock if it is not currently visible, and otherwise hides the containing dock', async () => {
        const item1 = {
          getDefaultLocation () { return 'left' },
          getElement () { return (this.element = document.createElement('div')) }
        }

        const item2 = {
          getDefaultLocation () { return 'left' },
          getElement () { return (this.element = document.createElement('div')) }
        }

        const dock = workspace.getLeftDock()
        expect(dock.isVisible()).toBe(false)

        await workspace.toggle(item1)
        expect(dock.isVisible()).toBe(true)
        expect(dock.getActivePaneItem()).toBe(item1)

        await workspace.toggle(item2)
        expect(dock.isVisible()).toBe(true)
        expect(dock.getActivePaneItem()).toBe(item2)

        await workspace.toggle(item1)
        expect(dock.isVisible()).toBe(true)
        expect(dock.getActivePaneItem()).toBe(item1)

        await workspace.toggle(item1)
        expect(dock.isVisible()).toBe(false)
        expect(dock.getActivePaneItem()).toBe(item1)

        await workspace.toggle(item2)
        expect(dock.isVisible()).toBe(true)
        expect(dock.getActivePaneItem()).toBe(item2)
      })
    })

    describe('when the location resolves to the center', () => {
      it('adds or shows the item if it is not currently the active pane item, and otherwise removes the item', async () => {
        const item1 = {
          getDefaultLocation () { return 'center' },
          getElement () { return (this.element = document.createElement('div')) }
        }

        const item2 = {
          getDefaultLocation () { return 'center' },
          getElement () { return (this.element = document.createElement('div')) }
        }

        expect(workspace.getActivePaneItem()).toBeUndefined()
        await workspace.toggle(item1)
        expect(workspace.getActivePaneItem()).toBe(item1)
        await workspace.toggle(item2)
        expect(workspace.getActivePaneItem()).toBe(item2)
        await workspace.toggle(item1)
        expect(workspace.getActivePaneItem()).toBe(item1)
        await workspace.toggle(item1)
        expect(workspace.paneForItem(item1)).toBeUndefined()
        expect(workspace.getActivePaneItem()).toBe(item2)
      })
    })
  })

  describe('active pane containers', () => {
    it('maintains the active pane and item globally across active pane containers', () => {
      const leftDock = workspace.getLeftDock()
      const leftItem1 = {element: document.createElement('div')}
      const leftItem2 = {element: document.createElement('div')}
      const leftItem3 = {element: document.createElement('div')}
      const leftPane1 = leftDock.getActivePane()
      leftPane1.addItems([leftItem1, leftItem2])
      const leftPane2 = leftPane1.splitDown({items: [leftItem3]})

      const rightDock = workspace.getRightDock()
      const rightItem1 = {element: document.createElement('div')}
      const rightItem2 = {element: document.createElement('div')}
      const rightItem3 = {element: document.createElement('div')}
      const rightPane1 = rightDock.getActivePane()
      rightPane1.addItems([rightItem1, rightItem2])
      const rightPane2 = rightPane1.splitDown({items: [rightItem3]})

      const bottomDock = workspace.getBottomDock()
      const bottomItem1 = {element: document.createElement('div')}
      const bottomItem2 = {element: document.createElement('div')}
      const bottomItem3 = {element: document.createElement('div')}
      const bottomPane1 = bottomDock.getActivePane()
      bottomPane1.addItems([bottomItem1, bottomItem2])
      const bottomPane2 = bottomPane1.splitDown({items: [bottomItem3]})

      const center = workspace.getCenter()
      const centerItem1 = {element: document.createElement('div')}
      const centerItem2 = {element: document.createElement('div')}
      const centerItem3 = {element: document.createElement('div')}
      const centerPane1 = center.getActivePane()
      centerPane1.addItems([centerItem1, centerItem2])
      const centerPane2 = centerPane1.splitDown({items: [centerItem3]})

      const activePaneContainers = []
      const activePanes = []
      const activeItems = []
      workspace.onDidChangeActivePaneContainer((container) => activePaneContainers.push(container))
      workspace.onDidChangeActivePane((pane) => activePanes.push(pane))
      workspace.onDidChangeActivePaneItem((item) => activeItems.push(item))
      function clearEvents () {
        activePaneContainers.length = 0
        activePanes.length = 0
        activeItems.length = 0
      }

      expect(workspace.getActivePaneContainer()).toBe(center)
      expect(workspace.getActivePane()).toBe(centerPane2)
      expect(workspace.getActivePaneItem()).toBe(centerItem3)

      leftDock.activate()
      expect(workspace.getActivePaneContainer()).toBe(leftDock)
      expect(workspace.getActivePane()).toBe(leftPane2)
      expect(workspace.getActivePaneItem()).toBe(leftItem3)
      expect(activePaneContainers).toEqual([leftDock])
      expect(activePanes).toEqual([leftPane2])
      expect(activeItems).toEqual([leftItem3])

      clearEvents()
      leftPane1.activate()
      leftPane1.activate()
      expect(workspace.getActivePaneContainer()).toBe(leftDock)
      expect(workspace.getActivePane()).toBe(leftPane1)
      expect(workspace.getActivePaneItem()).toBe(leftItem1)
      expect(activePaneContainers).toEqual([])
      expect(activePanes).toEqual([leftPane1])
      expect(activeItems).toEqual([leftItem1])

      clearEvents()
      leftPane1.activateItem(leftItem2)
      leftPane1.activateItem(leftItem2)
      expect(workspace.getActivePaneContainer()).toBe(leftDock)
      expect(workspace.getActivePane()).toBe(leftPane1)
      expect(workspace.getActivePaneItem()).toBe(leftItem2)
      expect(activePaneContainers).toEqual([])
      expect(activePanes).toEqual([])
      expect(activeItems).toEqual([leftItem2])

      clearEvents()
      expect(rightDock.getActivePane()).toBe(rightPane2)
      rightPane1.activate()
      rightPane1.activate()
      expect(workspace.getActivePaneContainer()).toBe(rightDock)
      expect(workspace.getActivePane()).toBe(rightPane1)
      expect(workspace.getActivePaneItem()).toBe(rightItem1)
      expect(activePaneContainers).toEqual([rightDock])
      expect(activePanes).toEqual([rightPane1])
      expect(activeItems).toEqual([rightItem1])

      clearEvents()
      rightPane1.activateItem(rightItem2)
      expect(workspace.getActivePaneContainer()).toBe(rightDock)
      expect(workspace.getActivePane()).toBe(rightPane1)
      expect(workspace.getActivePaneItem()).toBe(rightItem2)
      expect(activePaneContainers).toEqual([])
      expect(activePanes).toEqual([])
      expect(activeItems).toEqual([rightItem2])

      clearEvents()
      expect(bottomDock.getActivePane()).toBe(bottomPane2)
      bottomPane2.activate()
      bottomPane2.activate()
      expect(workspace.getActivePaneContainer()).toBe(bottomDock)
      expect(workspace.getActivePane()).toBe(bottomPane2)
      expect(workspace.getActivePaneItem()).toBe(bottomItem3)
      expect(activePaneContainers).toEqual([bottomDock])
      expect(activePanes).toEqual([bottomPane2])
      expect(activeItems).toEqual([bottomItem3])

      clearEvents()
      center.activate()
      center.activate()
      expect(workspace.getActivePaneContainer()).toBe(center)
      expect(workspace.getActivePane()).toBe(centerPane2)
      expect(workspace.getActivePaneItem()).toBe(centerItem3)
      expect(activePaneContainers).toEqual([center])
      expect(activePanes).toEqual([centerPane2])
      expect(activeItems).toEqual([centerItem3])

      clearEvents()
      centerPane1.activate()
      centerPane1.activate()
      expect(workspace.getActivePaneContainer()).toBe(center)
      expect(workspace.getActivePane()).toBe(centerPane1)
      expect(workspace.getActivePaneItem()).toBe(centerItem1)
      expect(activePaneContainers).toEqual([])
      expect(activePanes).toEqual([centerPane1])
      expect(activeItems).toEqual([centerItem1])
    })
  })

  describe('::onDidStopChangingActivePaneItem()', function () {
    it('invokes observers when the active item of the active pane stops changing', function () {
      const pane1 = atom.workspace.getCenter().getActivePane()
      const pane2 = pane1.splitRight({items: [document.createElement('div'), document.createElement('div')]});
      atom.workspace.getLeftDock().getActivePane().addItem(document.createElement('div'))

      emittedItems = []
      atom.workspace.onDidStopChangingActivePaneItem(item => emittedItems.push(item))

      pane2.activateNextItem()
      pane2.activateNextItem()
      pane1.activate()
      atom.workspace.getLeftDock().activate()

      advanceClock(100)
      expect(emittedItems).toEqual([atom.workspace.getLeftDock().getActivePaneItem()])
    })
  })

  describe('the grammar-used hook', () => {
    it('fires when opening a file or changing the grammar of an open file', () => {
      let editor = null
      let javascriptGrammarUsed = false
      let coffeescriptGrammarUsed = false

      atom.packages.triggerDeferredActivationHooks()

      runs(() => {
        atom.packages.onDidTriggerActivationHook('language-javascript:grammar-used', () => { javascriptGrammarUsed = true })
        atom.packages.onDidTriggerActivationHook('language-coffee-script:grammar-used', () => { coffeescriptGrammarUsed = true })
      })

      waitsForPromise(() => atom.workspace.open('sample.js', {autoIndent: false}).then(o => { editor = o }))

      waitsForPromise(() => atom.packages.activatePackage('language-javascript'))

      waitsFor(() => javascriptGrammarUsed)

      waitsForPromise(() => atom.packages.activatePackage('language-coffee-script'))

      runs(() => editor.setGrammar(atom.grammars.selectGrammar('.coffee')))

      waitsFor(() => coffeescriptGrammarUsed)
    })
  })

  describe('::reopenItem()', () => {
    it("opens the uri associated with the last closed pane that isn't currently open", () => {
      const pane = workspace.getActivePane()
      waitsForPromise(() =>
        workspace.open('a').then(() =>
          workspace.open('b').then(() =>
            workspace.open('file1').then(() => workspace.open())
          )
        )
      )

      runs(() => {
        // does not reopen items with no uri
        expect(workspace.getActivePaneItem().getURI()).toBeUndefined()
        pane.destroyActiveItem()
      })

      waitsForPromise(() => workspace.reopenItem())

      const firstDirectory = atom.project.getDirectories()[0]
      expect(firstDirectory).toBeDefined()

      runs(() => {
        expect(workspace.getActivePaneItem().getURI()).not.toBeUndefined()

        // destroy all items
        expect(workspace.getActivePaneItem().getURI()).toBe(firstDirectory.resolve('file1'))
        pane.destroyActiveItem()
        expect(workspace.getActivePaneItem().getURI()).toBe(firstDirectory.resolve('b'))
        pane.destroyActiveItem()
        expect(workspace.getActivePaneItem().getURI()).toBe(firstDirectory.resolve('a'))
        pane.destroyActiveItem()

        // reopens items with uris
        expect(workspace.getActivePaneItem()).toBeUndefined()
      })

      waitsForPromise(() => workspace.reopenItem())

      runs(() => expect(workspace.getActivePaneItem().getURI()).toBe(firstDirectory.resolve('a')))

      // does not reopen items that are already open
      waitsForPromise(() => workspace.open('b'))

      runs(() => expect(workspace.getActivePaneItem().getURI()).toBe(firstDirectory.resolve('b')))

      waitsForPromise(() => workspace.reopenItem())

      runs(() => expect(workspace.getActivePaneItem().getURI()).toBe(firstDirectory.resolve('file1')))
    })
  })

  describe('::increase/decreaseFontSize()', () => {
    it('increases/decreases the font size without going below 1', () => {
      atom.config.set('editor.fontSize', 1)
      workspace.increaseFontSize()
      expect(atom.config.get('editor.fontSize')).toBe(2)
      workspace.increaseFontSize()
      expect(atom.config.get('editor.fontSize')).toBe(3)
      workspace.decreaseFontSize()
      expect(atom.config.get('editor.fontSize')).toBe(2)
      workspace.decreaseFontSize()
      expect(atom.config.get('editor.fontSize')).toBe(1)
      workspace.decreaseFontSize()
      expect(atom.config.get('editor.fontSize')).toBe(1)
    })
  })

  describe('::resetFontSize()', () => {
    it("resets the font size to the window's starting font size", () => {
      const originalFontSize = atom.config.get('editor.fontSize')

      workspace.increaseFontSize()
      expect(atom.config.get('editor.fontSize')).toBe(originalFontSize + 1)
      workspace.resetFontSize()
      expect(atom.config.get('editor.fontSize')).toBe(originalFontSize)
      workspace.decreaseFontSize()
      expect(atom.config.get('editor.fontSize')).toBe(originalFontSize - 1)
      workspace.resetFontSize()
      expect(atom.config.get('editor.fontSize')).toBe(originalFontSize)
    })

    it('does nothing if the font size has not been changed', () => {
      const originalFontSize = atom.config.get('editor.fontSize')

      workspace.resetFontSize()
      expect(atom.config.get('editor.fontSize')).toBe(originalFontSize)
    })

    it("resets the font size when the editor's font size changes", () => {
      const originalFontSize = atom.config.get('editor.fontSize')

      atom.config.set('editor.fontSize', originalFontSize + 1)
      workspace.resetFontSize()
      expect(atom.config.get('editor.fontSize')).toBe(originalFontSize)
      atom.config.set('editor.fontSize', originalFontSize - 1)
      workspace.resetFontSize()
      expect(atom.config.get('editor.fontSize')).toBe(originalFontSize)
    })
  })

  describe('::openLicense()', () => {
    it('opens the license as plain-text in a buffer', () => {
      waitsForPromise(() => workspace.openLicense())
      runs(() => expect(workspace.getActivePaneItem().getText()).toMatch(/Copyright/))
    })
  })

  describe('::isTextEditor(obj)', () => {
    it('returns true when the passed object is an instance of `TextEditor`', () => {
      expect(workspace.isTextEditor(new TextEditor())).toBe(true)
      expect(workspace.isTextEditor({getText: () => null})).toBe(false)
      expect(workspace.isTextEditor(null)).toBe(false)
      expect(workspace.isTextEditor(undefined)).toBe(false)
    })
  })

  describe('::observeTextEditors()', () => {
    it('invokes the observer with current and future text editors', () => {
      const observed = []

      waitsForPromise(() => workspace.open())
      waitsForPromise(() => workspace.open())
      waitsForPromise(() => workspace.openLicense())

      runs(() => workspace.observeTextEditors(editor => observed.push(editor)))

      waitsForPromise(() => workspace.open())

      expect(observed).toEqual(workspace.getTextEditors())
    })
  })

  describe('when an editor is destroyed', () => {
    it('removes the editor', () => {
      let editor = null

      waitsForPromise(() => workspace.open('a').then(e => { editor = e }))

      runs(() => {
        expect(workspace.getTextEditors()).toHaveLength(1)
        editor.destroy()
        expect(workspace.getTextEditors()).toHaveLength(0)
      })
    })
  })

  describe('when an editor is copied because its pane is split', () => {
    it('sets up the new editor to be configured by the text editor registry', () => {
      waitsForPromise(() => atom.packages.activatePackage('language-javascript'))

      waitsForPromise(() =>
        workspace.open('a').then(editor => {
          atom.textEditors.setGrammarOverride(editor, 'source.js')
          expect(editor.getGrammar().name).toBe('JavaScript')

          workspace.getActivePane().splitRight({copyActiveItem: true})
          const newEditor = workspace.getActiveTextEditor()
          expect(newEditor).not.toBe(editor)
          expect(newEditor.getGrammar().name).toBe('JavaScript')
        })
      )
    })
  })

  it('stores the active grammars used by all the open editors', () => {
    waitsForPromise(() => atom.packages.activatePackage('language-javascript'))

    waitsForPromise(() => atom.packages.activatePackage('language-coffee-script'))

    waitsForPromise(() => atom.packages.activatePackage('language-todo'))

    waitsForPromise(() => atom.workspace.open('sample.coffee'))

    runs(function () {
      atom.workspace.getActiveTextEditor().setText(`\
i = /test/; #FIXME\
`
      )

      const atom2 = new AtomEnvironment({applicationDelegate: atom.applicationDelegate})
      atom2.initialize({
        window: document.createElement('div'),
        document: Object.assign(
          document.createElement('div'),
          {
            body: document.createElement('div'),
            head: document.createElement('div')
          }
        )
      })

      atom2.packages.loadPackage('language-javascript')
      atom2.packages.loadPackage('language-coffee-script')
      atom2.packages.loadPackage('language-todo')
      atom2.project.deserialize(atom.project.serialize())
      atom2.workspace.deserialize(atom.workspace.serialize(), atom2.deserializers)

      expect(atom2.grammars.getGrammars().map(grammar => grammar.name).sort()).toEqual([
        'CoffeeScript',
        'CoffeeScript (Literate)',
        'JavaScript',
        'Null Grammar',
        'Regular Expression Replacement (JavaScript)',
        'Regular Expressions (JavaScript)',
        'TODO'
      ])

      atom2.destroy()
    })
  })

  describe('document.title', () => {
    describe('when there is no item open', () => {
      it('sets the title to the project path', () => expect(document.title).toMatch(escapeStringRegex(fs.tildify(atom.project.getPaths()[0]))))

      it("sets the title to 'untitled' if there is no project path", () => {
        atom.project.setPaths([])
        expect(document.title).toMatch(/^untitled/)
      })
    })

    describe("when the active pane item's path is not inside a project path", () => {
      beforeEach(() =>
        waitsForPromise(() =>
          atom.workspace.open('b').then(() => atom.project.setPaths([]))
        )
      )

      it("sets the title to the pane item's title plus the item's path", () => {
        const item = atom.workspace.getActivePaneItem()
        const pathEscaped = fs.tildify(escapeStringRegex(path.dirname(item.getPath())))
        expect(document.title).toMatch(new RegExp(`^${item.getTitle()} \\u2014 ${pathEscaped}`))
      })

      describe('when the title of the active pane item changes', () => {
        it("updates the window title based on the item's new title", () => {
          const editor = atom.workspace.getActivePaneItem()
          editor.buffer.setPath(path.join(temp.dir, 'hi'))
          const pathEscaped = fs.tildify(escapeStringRegex(path.dirname(editor.getPath())))
          expect(document.title).toMatch(new RegExp(`^${editor.getTitle()} \\u2014 ${pathEscaped}`))
        })
      })

      describe("when the active pane's item changes", () => {
        it("updates the title to the new item's title plus the project path", () => {
          atom.workspace.getActivePane().activateNextItem()
          const item = atom.workspace.getActivePaneItem()
          const pathEscaped = fs.tildify(escapeStringRegex(path.dirname(item.getPath())))
          expect(document.title).toMatch(new RegExp(`^${item.getTitle()} \\u2014 ${pathEscaped}`))
        })
      })

      describe("when an inactive pane's item changes", () => {
        it('does not update the title', () => {
          const pane = atom.workspace.getActivePane()
          pane.splitRight()
          const initialTitle = document.title
          pane.activateNextItem()
          expect(document.title).toBe(initialTitle)
        })
      })
    })

    describe('when the active pane item is inside a project path', () => {
      beforeEach(() =>
        waitsForPromise(() => atom.workspace.open('b'))
      )

      describe('when there is an active pane item', () => {
        it("sets the title to the pane item's title plus the project path", () => {
          const item = atom.workspace.getActivePaneItem()
          const pathEscaped = fs.tildify(escapeStringRegex(atom.project.getPaths()[0]))
          expect(document.title).toMatch(new RegExp(`^${item.getTitle()} \\u2014 ${pathEscaped}`))
        })
      })

      describe('when the title of the active pane item changes', () => {
        it("updates the window title based on the item's new title", () => {
          const editor = atom.workspace.getActivePaneItem()
          editor.buffer.setPath(path.join(atom.project.getPaths()[0], 'hi'))
          const pathEscaped = fs.tildify(escapeStringRegex(atom.project.getPaths()[0]))
          expect(document.title).toMatch(new RegExp(`^${editor.getTitle()} \\u2014 ${pathEscaped}`))
        })
      })

      describe("when the active pane's item changes", () => {
        it("updates the title to the new item's title plus the project path", () => {
          atom.workspace.getActivePane().activateNextItem()
          const item = atom.workspace.getActivePaneItem()
          const pathEscaped = fs.tildify(escapeStringRegex(atom.project.getPaths()[0]))
          expect(document.title).toMatch(new RegExp(`^${item.getTitle()} \\u2014 ${pathEscaped}`))
        })
      })

      describe('when the last pane item is removed', () => {
        it("updates the title to the project's first path", () => {
          atom.workspace.getActivePane().destroy()
          expect(atom.workspace.getActivePaneItem()).toBeUndefined()
          expect(document.title).toMatch(escapeStringRegex(fs.tildify(atom.project.getPaths()[0])))
        })
      })

      describe("when an inactive pane's item changes", () => {
        it('does not update the title', () => {
          const pane = atom.workspace.getActivePane()
          pane.splitRight()
          const initialTitle = document.title
          pane.activateNextItem()
          expect(document.title).toBe(initialTitle)
        })
      })
    })

    describe('when the workspace is deserialized', () => {
      beforeEach(() => waitsForPromise(() => atom.workspace.open('a')))

      it("updates the title to contain the project's path", () => {
        document.title = null

        const atom2 = new AtomEnvironment({applicationDelegate: atom.applicationDelegate})
        atom2.initialize({
          window: document.createElement('div'),
          document: Object.assign(
            document.createElement('div'),
            {
              body: document.createElement('div'),
              head: document.createElement('div')
            }
          )
        })

        atom2.project.deserialize(atom.project.serialize())
        atom2.workspace.deserialize(atom.workspace.serialize(), atom2.deserializers)
        const item = atom2.workspace.getActivePaneItem()
        const pathEscaped = fs.tildify(escapeStringRegex(atom.project.getPaths()[0]))
        expect(document.title).toMatch(new RegExp(`^${item.getLongTitle()} \\u2014 ${pathEscaped}`))

        atom2.destroy()
      })
    })
  })

  describe('document edited status', () => {
    let item1
    let item2

    beforeEach(() => {
      waitsForPromise(() => atom.workspace.open('a'))
      waitsForPromise(() => atom.workspace.open('b'))
      runs(() => {
        [item1, item2] = atom.workspace.getPaneItems()
      })
    })

    it('calls setDocumentEdited when the active item changes', () => {
      expect(atom.workspace.getActivePaneItem()).toBe(item2)
      item1.insertText('a')
      expect(item1.isModified()).toBe(true)
      atom.workspace.getActivePane().activateNextItem()

      expect(setDocumentEdited).toHaveBeenCalledWith(true)
    })

    it("calls atom.setDocumentEdited when the active item's modified status changes", () => {
      expect(atom.workspace.getActivePaneItem()).toBe(item2)
      item2.insertText('a')
      advanceClock(item2.getBuffer().getStoppedChangingDelay())

      expect(item2.isModified()).toBe(true)
      expect(setDocumentEdited).toHaveBeenCalledWith(true)

      item2.undo()
      advanceClock(item2.getBuffer().getStoppedChangingDelay())

      expect(item2.isModified()).toBe(false)
      expect(setDocumentEdited).toHaveBeenCalledWith(false)
    })
  })

  describe('adding panels', () => {
    class TestItem {}

    // Don't use ES6 classes because then we'll have to call `super()` which we can't do with
    // HTMLElement
    function TestItemElement () { this.constructor = TestItemElement }
    function Ctor () { this.constructor = TestItemElement }
    Ctor.prototype = HTMLElement.prototype
    TestItemElement.prototype = new Ctor()
    TestItemElement.__super__ = HTMLElement.prototype
    TestItemElement.prototype.initialize = function (model) { this.model = model; return this }
    TestItemElement.prototype.getModel = function () { return this.model }

    beforeEach(() =>
      atom.views.addViewProvider(TestItem, model => new TestItemElement().initialize(model))
    )

    describe('::addLeftPanel(model)', () => {
      it('adds a panel to the correct panel container', () => {
        let addPanelSpy
        expect(atom.workspace.getLeftPanels().length).toBe(0)
        atom.workspace.panelContainers.left.onDidAddPanel(addPanelSpy = jasmine.createSpy())

        const model = new TestItem()
        const panel = atom.workspace.addLeftPanel({item: model})

        expect(panel).toBeDefined()
        expect(addPanelSpy).toHaveBeenCalledWith({panel, index: 0})

        const itemView = atom.views.getView(atom.workspace.getLeftPanels()[0].getItem())
        expect(itemView instanceof TestItemElement).toBe(true)
        expect(itemView.getModel()).toBe(model)
      })
    })

    describe('::addRightPanel(model)', () => {
      it('adds a panel to the correct panel container', () => {
        let addPanelSpy
        expect(atom.workspace.getRightPanels().length).toBe(0)
        atom.workspace.panelContainers.right.onDidAddPanel(addPanelSpy = jasmine.createSpy())

        const model = new TestItem()
        const panel = atom.workspace.addRightPanel({item: model})

        expect(panel).toBeDefined()
        expect(addPanelSpy).toHaveBeenCalledWith({panel, index: 0})

        const itemView = atom.views.getView(atom.workspace.getRightPanels()[0].getItem())
        expect(itemView instanceof TestItemElement).toBe(true)
        expect(itemView.getModel()).toBe(model)
      })
    })

    describe('::addTopPanel(model)', () => {
      it('adds a panel to the correct panel container', () => {
        let addPanelSpy
        expect(atom.workspace.getTopPanels().length).toBe(0)
        atom.workspace.panelContainers.top.onDidAddPanel(addPanelSpy = jasmine.createSpy())

        const model = new TestItem()
        const panel = atom.workspace.addTopPanel({item: model})

        expect(panel).toBeDefined()
        expect(addPanelSpy).toHaveBeenCalledWith({panel, index: 0})

        const itemView = atom.views.getView(atom.workspace.getTopPanels()[0].getItem())
        expect(itemView instanceof TestItemElement).toBe(true)
        expect(itemView.getModel()).toBe(model)
      })
    })

    describe('::addBottomPanel(model)', () => {
      it('adds a panel to the correct panel container', () => {
        let addPanelSpy
        expect(atom.workspace.getBottomPanels().length).toBe(0)
        atom.workspace.panelContainers.bottom.onDidAddPanel(addPanelSpy = jasmine.createSpy())

        const model = new TestItem()
        const panel = atom.workspace.addBottomPanel({item: model})

        expect(panel).toBeDefined()
        expect(addPanelSpy).toHaveBeenCalledWith({panel, index: 0})

        const itemView = atom.views.getView(atom.workspace.getBottomPanels()[0].getItem())
        expect(itemView instanceof TestItemElement).toBe(true)
        expect(itemView.getModel()).toBe(model)
      })
    })

    describe('::addHeaderPanel(model)', () => {
      it('adds a panel to the correct panel container', () => {
        let addPanelSpy
        expect(atom.workspace.getHeaderPanels().length).toBe(0)
        atom.workspace.panelContainers.header.onDidAddPanel(addPanelSpy = jasmine.createSpy())

        const model = new TestItem()
        const panel = atom.workspace.addHeaderPanel({item: model})

        expect(panel).toBeDefined()
        expect(addPanelSpy).toHaveBeenCalledWith({panel, index: 0})

        const itemView = atom.views.getView(atom.workspace.getHeaderPanels()[0].getItem())
        expect(itemView instanceof TestItemElement).toBe(true)
        expect(itemView.getModel()).toBe(model)
      })
    })

    describe('::addFooterPanel(model)', () => {
      it('adds a panel to the correct panel container', () => {
        let addPanelSpy
        expect(atom.workspace.getFooterPanels().length).toBe(0)
        atom.workspace.panelContainers.footer.onDidAddPanel(addPanelSpy = jasmine.createSpy())

        const model = new TestItem()
        const panel = atom.workspace.addFooterPanel({item: model})

        expect(panel).toBeDefined()
        expect(addPanelSpy).toHaveBeenCalledWith({panel, index: 0})

        const itemView = atom.views.getView(atom.workspace.getFooterPanels()[0].getItem())
        expect(itemView instanceof TestItemElement).toBe(true)
        expect(itemView.getModel()).toBe(model)
      })
    })

    describe('::addModalPanel(model)', () => {
      it('adds a panel to the correct panel container', () => {
        let addPanelSpy
        expect(atom.workspace.getModalPanels().length).toBe(0)
        atom.workspace.panelContainers.modal.onDidAddPanel(addPanelSpy = jasmine.createSpy())

        const model = new TestItem()
        const panel = atom.workspace.addModalPanel({item: model})

        expect(panel).toBeDefined()
        expect(addPanelSpy).toHaveBeenCalledWith({panel, index: 0})

        const itemView = atom.views.getView(atom.workspace.getModalPanels()[0].getItem())
        expect(itemView instanceof TestItemElement).toBe(true)
        expect(itemView.getModel()).toBe(model)
      })
    })

    describe('::panelForItem(item)', () => {
      it('returns the panel associated with the item', () => {
        const item = new TestItem()
        const panel = atom.workspace.addLeftPanel({item})

        const itemWithNoPanel = new TestItem()

        expect(atom.workspace.panelForItem(item)).toBe(panel)
        expect(atom.workspace.panelForItem(itemWithNoPanel)).toBe(null)
      })
    })
  })

  describe('::scan(regex, options, callback)', () => {
    describe('when called with a regex', () => {
      it('calls the callback with all regex results in all files in the project', () => {
        const results = []
        waitsForPromise(() =>
          atom.workspace.scan(
            /(a)+/, {leadingContextLineCount: 1, trailingContextLineCount: 1},
            result => results.push(result))
        )

        runs(() => {
          expect(results).toHaveLength(3)
          expect(results[0].filePath).toBe(atom.project.getDirectories()[0].resolve('a'))
          expect(results[0].matches).toHaveLength(3)
          expect(results[0].matches[0]).toEqual({
            matchText: 'aaa',
            lineText: 'aaa bbb',
            lineTextOffset: 0,
            range: [[0, 0], [0, 3]],
            leadingContextLines: [],
            trailingContextLines: ['cc aa cc']
          })
        })
      })

      it('works with with escaped literals (like $ and ^)', () => {
        const results = []
        waitsForPromise(() => atom.workspace.scan(
          /\$\w+/, {leadingContextLineCount: 1, trailingContextLineCount: 1},
          result => results.push(result)))

        runs(() => {
          expect(results.length).toBe(1)
          const {filePath, matches} = results[0]
          expect(filePath).toBe(atom.project.getDirectories()[0].resolve('a'))
          expect(matches).toHaveLength(1)
          expect(matches[0]).toEqual({
            matchText: '$bill',
            lineText: 'dollar$bill',
            lineTextOffset: 0,
            range: [[2, 6], [2, 11]],
            leadingContextLines: ['cc aa cc'],
            trailingContextLines: []
          })
        })
      })

      it('works on evil filenames', () => {
        atom.config.set('core.excludeVcsIgnoredPaths', false)
        platform.generateEvilFiles()
        atom.project.setPaths([path.join(__dirname, 'fixtures', 'evil-files')])
        const paths = []
        let matches = []
        waitsForPromise(() =>
          atom.workspace.scan(/evil/, result => {
            paths.push(result.filePath)
            matches = matches.concat(result.matches)
          })
        )

        runs(() => {
          _.each(matches, m => expect(m.matchText).toEqual('evil'))

          if (platform.isWindows()) {
            expect(paths.length).toBe(3)
            expect(paths[0]).toMatch(/a_file_with_utf8.txt$/)
            expect(paths[1]).toMatch(/file with spaces.txt$/)
            expect(path.basename(paths[2])).toBe('utfa\u0306.md')
          } else {
            expect(paths.length).toBe(5)
            expect(paths[0]).toMatch(/a_file_with_utf8.txt$/)
            expect(paths[1]).toMatch(/file with spaces.txt$/)
            expect(paths[2]).toMatch(/goddam\nnewlines$/m)
            expect(paths[3]).toMatch(/quote".txt$/m)
            expect(path.basename(paths[4])).toBe('utfa\u0306.md')
          }
        })
      })

      it('ignores case if the regex includes the `i` flag', () => {
        const results = []
        waitsForPromise(() => atom.workspace.scan(/DOLLAR/i, result => results.push(result)))

        runs(() => expect(results).toHaveLength(1))
      })

      describe('when the core.excludeVcsIgnoredPaths config is truthy', () => {
        let projectPath
        let ignoredPath

        beforeEach(() => {
          const sourceProjectPath = path.join(__dirname, 'fixtures', 'git', 'working-dir')
          projectPath = path.join(temp.mkdirSync('atom'))

          const writerStream = fstream.Writer(projectPath)
          fstream.Reader(sourceProjectPath).pipe(writerStream)

          waitsFor(done => {
            writerStream.on('close', done)
            writerStream.on('error', done)
          })

          runs(() => {
            fs.rename(path.join(projectPath, 'git.git'), path.join(projectPath, '.git'))
            ignoredPath = path.join(projectPath, 'ignored.txt')
            fs.writeFileSync(ignoredPath, 'this match should not be included')
          })
        })

        afterEach(() => {
          if (fs.existsSync(projectPath)) {
            fs.removeSync(projectPath)
          }
        })

        it('excludes ignored files', () => {
          atom.project.setPaths([projectPath])
          atom.config.set('core.excludeVcsIgnoredPaths', true)
          const resultHandler = jasmine.createSpy('result found')
          waitsForPromise(() =>
            atom.workspace.scan(/match/, results => resultHandler())
          )

          runs(() => expect(resultHandler).not.toHaveBeenCalled())
        })
      })

      it('includes only files when a directory filter is specified', () => {
        const projectPath = path.join(path.join(__dirname, 'fixtures', 'dir'))
        atom.project.setPaths([projectPath])

        const filePath = path.join(projectPath, 'a-dir', 'oh-git')

        const paths = []
        let matches = []
        waitsForPromise(() =>
          atom.workspace.scan(/aaa/, {paths: [`a-dir${path.sep}`]}, result => {
            paths.push(result.filePath)
            matches = matches.concat(result.matches)
          })
        )

        runs(() => {
          expect(paths.length).toBe(1)
          expect(paths[0]).toBe(filePath)
          expect(matches.length).toBe(1)
        })
      })

      it("includes files and folders that begin with a '.'", () => {
        const projectPath = temp.mkdirSync('atom-spec-workspace')
        const filePath = path.join(projectPath, '.text')
        fs.writeFileSync(filePath, 'match this')
        atom.project.setPaths([projectPath])
        const paths = []
        let matches = []
        waitsForPromise(() =>
          atom.workspace.scan(/match this/, result => {
            paths.push(result.filePath)
            matches = matches.concat(result.matches)
          })
        )

        runs(() => {
          expect(paths.length).toBe(1)
          expect(paths[0]).toBe(filePath)
          expect(matches.length).toBe(1)
        })
      })

      it('excludes values in core.ignoredNames', () => {
        const ignoredNames = atom.config.get('core.ignoredNames')
        ignoredNames.push('a')
        atom.config.set('core.ignoredNames', ignoredNames)

        const resultHandler = jasmine.createSpy('result found')
        waitsForPromise(() =>
          atom.workspace.scan(/dollar/, results => resultHandler())
        )

        runs(() => expect(resultHandler).not.toHaveBeenCalled())
      })

      it('scans buffer contents if the buffer is modified', () => {
        let editor = null
        const results = []

        waitsForPromise(() =>
          atom.workspace.open('a').then(o => {
            editor = o
            editor.setText('Elephant')
          })
        )

        waitsForPromise(() => atom.workspace.scan(/a|Elephant/, result => results.push(result)))

        runs(() => {
          expect(results).toHaveLength(3)
          const resultForA = _.find(results, ({filePath}) => path.basename(filePath) === 'a')
          expect(resultForA.matches).toHaveLength(1)
          expect(resultForA.matches[0].matchText).toBe('Elephant')
        })
      })

      it('ignores buffers outside the project', () => {
        let editor = null
        const results = []

        waitsForPromise(() =>
          atom.workspace.open(temp.openSync().path).then(o => {
            editor = o
            editor.setText('Elephant')
          })
        )

        waitsForPromise(() => atom.workspace.scan(/Elephant/, result => results.push(result)))

        runs(() => expect(results).toHaveLength(0))
      })

      describe('when the project has multiple root directories', () => {
        let dir1
        let dir2
        let file1
        let file2

        beforeEach(() => {
          dir1 = atom.project.getPaths()[0]
          file1 = path.join(dir1, 'a-dir', 'oh-git')

          dir2 = temp.mkdirSync('a-second-dir')
          const aDir2 = path.join(dir2, 'a-dir')
          file2 = path.join(aDir2, 'a-file')
          fs.mkdirSync(aDir2)
          fs.writeFileSync(file2, 'ccc aaaa')

          atom.project.addPath(dir2)
        })

        it("searches matching files in all of the project's root directories", () => {
          const resultPaths = []
          waitsForPromise(() =>
            atom.workspace.scan(/aaaa/, ({filePath}) => resultPaths.push(filePath))
          )

          runs(() => expect(resultPaths.sort()).toEqual([file1, file2].sort()))
        })

        describe('when an inclusion path starts with the basename of a root directory', () => {
          it('interprets the inclusion path as starting from that directory', () => {
            waitsForPromise(() => {
              const resultPaths = []
              return atom.workspace
                .scan(/aaaa/, {paths: ['dir']}, ({filePath}) => {
                  if (!resultPaths.includes(filePath)) {
                    resultPaths.push(filePath)
                  }
                })
                .then(() => expect(resultPaths).toEqual([file1]))
            })

            waitsForPromise(() => {
              const resultPaths = []
              return atom.workspace
                .scan(/aaaa/, {paths: [path.join('dir', 'a-dir')]}, ({filePath}) => {
                  if (!resultPaths.includes(filePath)) {
                    resultPaths.push(filePath)
                  }
                })
                .then(() => expect(resultPaths).toEqual([file1]))
            })

            waitsForPromise(() => {
              const resultPaths = []
              return atom.workspace
                .scan(/aaaa/, {paths: [path.basename(dir2)]}, ({filePath}) => {
                  if (!resultPaths.includes(filePath)) {
                    resultPaths.push(filePath)
                  }
                })
                .then(() => expect(resultPaths).toEqual([file2]))
            })

            waitsForPromise(() => {
              const resultPaths = []
              return atom.workspace
                .scan(/aaaa/, {paths: [path.join(path.basename(dir2), 'a-dir')]}, ({filePath}) => {
                  if (!resultPaths.includes(filePath)) {
                    resultPaths.push(filePath)
                  }
                })
                .then(() => expect(resultPaths).toEqual([file2]))
            })
          })
        })

        describe('when a custom directory searcher is registered', () => {
          let fakeSearch = null
          // Function that is invoked once all of the fields on fakeSearch are set.
          let onFakeSearchCreated = null

          class FakeSearch {
            constructor (options) {
              // Note that hoisting resolve and reject in this way is generally frowned upon.
              this.options = options
              this.promise = new Promise((resolve, reject) => {
                this.hoistedResolve = resolve
                this.hoistedReject = reject
                if (typeof onFakeSearchCreated === 'function') {
                  onFakeSearchCreated(this)
                }
              })
            }
            then (...args) {
              return this.promise.then.apply(this.promise, args)
            }
            cancel () {
              this.cancelled = true
              // According to the spec for a DirectorySearcher, invoking `cancel()` should
              // resolve the thenable rather than reject it.
              this.hoistedResolve()
            }
          }

          beforeEach(() => {
            fakeSearch = null
            onFakeSearchCreated = null
            atom.packages.serviceHub.provide('atom.directory-searcher', '0.1.0', {
              canSearchDirectory (directory) { return directory.getPath() === dir1 },
              search (directory, regex, options) {
                fakeSearch = new FakeSearch(options)
                return fakeSearch
              }
            })

            waitsFor(() => atom.workspace.directorySearchers.length > 0)
          })

          it('can override the DefaultDirectorySearcher on a per-directory basis', () => {
            const foreignFilePath = 'ssh://foreign-directory:8080/hello.txt'
            const numPathsSearchedInDir2 = 1
            const numPathsToPretendToSearchInCustomDirectorySearcher = 10
            const searchResult = {
              filePath: foreignFilePath,
              matches: [
                {
                  lineText: 'Hello world',
                  lineTextOffset: 0,
                  matchText: 'Hello',
                  range: [[0, 0], [0, 5]]
                }
              ]
            }
            onFakeSearchCreated = fakeSearch => {
              fakeSearch.options.didMatch(searchResult)
              fakeSearch.options.didSearchPaths(numPathsToPretendToSearchInCustomDirectorySearcher)
              fakeSearch.hoistedResolve()
            }

            const resultPaths = []
            const onPathsSearched = jasmine.createSpy('onPathsSearched')
            waitsForPromise(() =>
              atom.workspace.scan(/aaaa/, {onPathsSearched}, ({filePath}) => resultPaths.push(filePath))
            )

            runs(() => {
              expect(resultPaths.sort()).toEqual([foreignFilePath, file2].sort())
              // onPathsSearched should be called once by each DirectorySearcher. The order is not
              // guaranteed, so we can only verify the total number of paths searched is correct
              // after the second call.
              expect(onPathsSearched.callCount).toBe(2)
              expect(onPathsSearched.mostRecentCall.args[0]).toBe(
                numPathsToPretendToSearchInCustomDirectorySearcher + numPathsSearchedInDir2)
            })
          })

          it('can be cancelled when the object returned by scan() has its cancel() method invoked', () => {
            const thenable = atom.workspace.scan(/aaaa/, () => {})
            let resultOfPromiseSearch = null

            waitsFor('fakeSearch to be defined', () => fakeSearch != null)

            runs(() => {
              expect(fakeSearch.cancelled).toBe(undefined)
              thenable.cancel()
              expect(fakeSearch.cancelled).toBe(true)
            })

            waitsForPromise(() => thenable.then(promiseResult => { resultOfPromiseSearch = promiseResult }))

            runs(() => expect(resultOfPromiseSearch).toBe('cancelled'))
          })

          it('will have the side-effect of failing the overall search if it fails', () => {
            // This provider's search should be cancelled when the first provider fails
            let cancelableSearch
            let fakeSearch2 = null
            atom.packages.serviceHub.provide('atom.directory-searcher', '0.1.0', {
              canSearchDirectory (directory) { return directory.getPath() === dir2 },
              search (directory, regex, options) {
                fakeSearch2 = new FakeSearch(options)
                return fakeSearch2
              }
            })

            let didReject = false
            const promise = cancelableSearch = atom.workspace.scan(/aaaa/, () => {})
            waitsFor('fakeSearch to be defined', () => fakeSearch != null)

            runs(() => fakeSearch.hoistedReject())

            waitsForPromise(() => cancelableSearch.catch(() => { didReject = true }))

            waitsFor(done => promise.then(null, done))

            runs(() => {
              expect(didReject).toBe(true)
              expect(fakeSearch2.cancelled).toBe(true)
            })
          })
        })
      })
    })
  }) // Cancels other ongoing searches

  describe('::replace(regex, replacementText, paths, iterator)', () => {
    let filePath
    let commentFilePath
    let sampleContent
    let sampleCommentContent

    beforeEach(() => {
      atom.project.setPaths([atom.project.getDirectories()[0].resolve('../')])

      filePath = atom.project.getDirectories()[0].resolve('sample.js')
      commentFilePath = atom.project.getDirectories()[0].resolve('sample-with-comments.js')
      sampleContent = fs.readFileSync(filePath).toString()
      sampleCommentContent = fs.readFileSync(commentFilePath).toString()
    })

    afterEach(() => {
      fs.writeFileSync(filePath, sampleContent)
      fs.writeFileSync(commentFilePath, sampleCommentContent)
    })

    describe("when a file doesn't exist", () => {
      it('calls back with an error', () => {
        const errors = []
        const missingPath = path.resolve('/not-a-file.js')
        expect(fs.existsSync(missingPath)).toBeFalsy()

        waitsForPromise(() =>
          atom.workspace.replace(/items/gi, 'items', [missingPath], (result, error) => errors.push(error))
        )

        runs(() => {
          expect(errors).toHaveLength(1)
          expect(errors[0].path).toBe(missingPath)
        })
      })
    })

    describe('when called with unopened files', () => {
      it('replaces properly', () => {
        const results = []
        waitsForPromise(() =>
          atom.workspace.replace(/items/gi, 'items', [filePath], result => results.push(result))
        )

        runs(() => {
          expect(results).toHaveLength(1)
          expect(results[0].filePath).toBe(filePath)
          expect(results[0].replacements).toBe(6)
        })
      })
    })

    describe('when a buffer is already open', () => {
      it('replaces properly and saves when not modified', () => {
        let editor = null
        const results = []

        waitsForPromise(() => atom.workspace.open('sample.js').then(o => { editor = o }))

        runs(() => expect(editor.isModified()).toBeFalsy())

        waitsForPromise(() =>
          atom.workspace.replace(/items/gi, 'items', [filePath], result => results.push(result))
        )

        runs(() => {
          expect(results).toHaveLength(1)
          expect(results[0].filePath).toBe(filePath)
          expect(results[0].replacements).toBe(6)

          expect(editor.isModified()).toBeFalsy()
        })
      })

      it('does not replace when the path is not specified', () => {
        const results = []

        waitsForPromise(() => atom.workspace.open('sample-with-comments.js'))

        waitsForPromise(() =>
          atom.workspace.replace(/items/gi, 'items', [commentFilePath], result => results.push(result))
        )

        runs(() => {
          expect(results).toHaveLength(1)
          expect(results[0].filePath).toBe(commentFilePath)
        })
      })

      it('does NOT save when modified', () => {
        let editor = null
        const results = []

        waitsForPromise(() => atom.workspace.open('sample.js').then(o => { editor = o }))

        runs(() => {
          editor.buffer.setTextInRange([[0, 0], [0, 0]], 'omg')
          expect(editor.isModified()).toBeTruthy()
        })

        waitsForPromise(() =>
          atom.workspace.replace(/items/gi, 'okthen', [filePath], result => results.push(result))
        )

        runs(() => {
          expect(results).toHaveLength(1)
          expect(results[0].filePath).toBe(filePath)
          expect(results[0].replacements).toBe(6)

          expect(editor.isModified()).toBeTruthy()
        })
      })
    })
  })

  describe('::saveActivePaneItem()', () => {
    let editor = null
    beforeEach(() =>
      waitsForPromise(() => atom.workspace.open('sample.js').then(o => { editor = o }))
    )

    describe('when there is an error', () => {
      it('emits a warning notification when the file cannot be saved', () => {
        let addedSpy
        spyOn(editor, 'save').andCallFake(() => {
          throw new Error("'/some/file' is a directory")
        })

        atom.notifications.onDidAddNotification(addedSpy = jasmine.createSpy())
        atom.workspace.saveActivePaneItem()
        expect(addedSpy).toHaveBeenCalled()
        expect(addedSpy.mostRecentCall.args[0].getType()).toBe('warning')
      })

      it('emits a warning notification when the directory cannot be written to', () => {
        let addedSpy
        spyOn(editor, 'save').andCallFake(() => {
          throw new Error("ENOTDIR, not a directory '/Some/dir/and-a-file.js'")
        })

        atom.notifications.onDidAddNotification(addedSpy = jasmine.createSpy())
        atom.workspace.saveActivePaneItem()
        expect(addedSpy).toHaveBeenCalled()
        expect(addedSpy.mostRecentCall.args[0].getType()).toBe('warning')
      })

      it('emits a warning notification when the user does not have permission', () => {
        let addedSpy
        spyOn(editor, 'save').andCallFake(() => {
          const error = new Error("EACCES, permission denied '/Some/dir/and-a-file.js'")
          error.code = 'EACCES'
          error.path = '/Some/dir/and-a-file.js'
          throw error
        })

        atom.notifications.onDidAddNotification(addedSpy = jasmine.createSpy())
        atom.workspace.saveActivePaneItem()
        expect(addedSpy).toHaveBeenCalled()
        expect(addedSpy.mostRecentCall.args[0].getType()).toBe('warning')
      })

      it('emits a warning notification when the operation is not permitted', () => {
        spyOn(editor, 'save').andCallFake(() => {
          const error = new Error("EPERM, operation not permitted '/Some/dir/and-a-file.js'")
          error.code = 'EPERM'
          error.path = '/Some/dir/and-a-file.js'
          throw error
        })
      })

      it('emits a warning notification when the file is already open by another app', () => {
        let addedSpy
        spyOn(editor, 'save').andCallFake(() => {
          const error = new Error("EBUSY, resource busy or locked '/Some/dir/and-a-file.js'")
          error.code = 'EBUSY'
          error.path = '/Some/dir/and-a-file.js'
          throw error
        })

        atom.notifications.onDidAddNotification(addedSpy = jasmine.createSpy())
        atom.workspace.saveActivePaneItem()
        expect(addedSpy).toHaveBeenCalled()

        const notificaiton = addedSpy.mostRecentCall.args[0]
        expect(notificaiton.getType()).toBe('warning')
        expect(notificaiton.getMessage()).toContain('Unable to save')
      })

      it('emits a warning notification when the file system is read-only', () => {
        let addedSpy
        spyOn(editor, 'save').andCallFake(() => {
          const error = new Error("EROFS, read-only file system '/Some/dir/and-a-file.js'")
          error.code = 'EROFS'
          error.path = '/Some/dir/and-a-file.js'
          throw error
        })

        atom.notifications.onDidAddNotification(addedSpy = jasmine.createSpy())
        atom.workspace.saveActivePaneItem()
        expect(addedSpy).toHaveBeenCalled()

        const notification = addedSpy.mostRecentCall.args[0]
        expect(notification.getType()).toBe('warning')
        expect(notification.getMessage()).toContain('Unable to save')
      })

      it('emits a warning notification when the file cannot be saved', () => {
        spyOn(editor, 'save').andCallFake(() => {
          throw new Error('no one knows')
        })

        const save = () => atom.workspace.saveActivePaneItem()
        expect(save).toThrow()
      })
    })
  })

  describe('::closeActivePaneItemOrEmptyPaneOrWindow', () => {
    beforeEach(() => {
      spyOn(atom, 'close')
      waitsForPromise(() => atom.workspace.open())
    })

    it('closes the active center pane item, or the active center pane if it is empty, or the current window if there is only the empty root pane in the center', async () => {
      atom.config.set('core.destroyEmptyPanes', false)

      const pane1 = atom.workspace.getActivePane()
      const pane2 = pane1.splitRight({copyActiveItem: true})

      expect(atom.workspace.getCenter().getPanes().length).toBe(2)
      expect(pane2.getItems().length).toBe(1)
      atom.workspace.closeActivePaneItemOrEmptyPaneOrWindow()

      expect(atom.workspace.getCenter().getPanes().length).toBe(2)
      expect(pane2.getItems().length).toBe(0)

      atom.workspace.closeActivePaneItemOrEmptyPaneOrWindow()

      expect(atom.workspace.getCenter().getPanes().length).toBe(1)
      expect(pane1.getItems().length).toBe(1)

      atom.workspace.closeActivePaneItemOrEmptyPaneOrWindow()
      expect(atom.workspace.getCenter().getPanes().length).toBe(1)
      expect(pane1.getItems().length).toBe(0)
      expect(atom.workspace.getCenter().getPanes().length).toBe(1)

      // The dock items should not be closed
      await atom.workspace.open({
        getTitle: () => 'Permanent Dock Item',
        element: document.createElement('div'),
        getDefaultLocation: () => 'left',
        isPermanentDockItem: () => true
      })
      await atom.workspace.open({
        getTitle: () => 'Impermanent Dock Item',
        element: document.createElement('div'),
        getDefaultLocation: () => 'left'
      })

      expect(atom.workspace.getLeftDock().getPaneItems().length).toBe(2)
      atom.workspace.closeActivePaneItemOrEmptyPaneOrWindow()
      expect(atom.close).toHaveBeenCalled()
    })
  })

  describe('when the core.allowPendingPaneItems option is falsey', () => {
    it('does not open item with `pending: true` option as pending', () => {
      let pane = null
      atom.config.set('core.allowPendingPaneItems', false)

      waitsForPromise(() =>
        atom.workspace.open('sample.js', {pending: true}).then(() => {
          pane = atom.workspace.getActivePane()
        })
      )

      runs(() => expect(pane.getPendingItem()).toBeFalsy())
    })
  })

  describe('grammar activation', () => {
    it('notifies the workspace of which grammar is used', () => {
      atom.packages.triggerDeferredActivationHooks()

      const javascriptGrammarUsed = jasmine.createSpy('js grammar used')
      const rubyGrammarUsed = jasmine.createSpy('ruby grammar used')
      const cGrammarUsed = jasmine.createSpy('c grammar used')

      atom.packages.onDidTriggerActivationHook('language-javascript:grammar-used', javascriptGrammarUsed)
      atom.packages.onDidTriggerActivationHook('language-ruby:grammar-used', rubyGrammarUsed)
      atom.packages.onDidTriggerActivationHook('language-c:grammar-used', cGrammarUsed)

      waitsForPromise(() => atom.packages.activatePackage('language-ruby'))
      waitsForPromise(() => atom.packages.activatePackage('language-javascript'))
      waitsForPromise(() => atom.packages.activatePackage('language-c'))
      waitsForPromise(() => atom.workspace.open('sample-with-comments.js'))

      runs(() => {
        // Hooks are triggered when opening new editors
        expect(javascriptGrammarUsed).toHaveBeenCalled()

        // Hooks are triggered when changing existing editors grammars
        atom.workspace.getActiveTextEditor().setGrammar(atom.grammars.grammarForScopeName('source.c'))
        expect(cGrammarUsed).toHaveBeenCalled()

        // Hooks are triggered when editors are added in other ways.
        atom.workspace.getActivePane().splitRight({copyActiveItem: true})
        atom.workspace.getActiveTextEditor().setGrammar(atom.grammars.grammarForScopeName('source.ruby'))
        expect(rubyGrammarUsed).toHaveBeenCalled()
      })
    })
  })

  describe('.checkoutHeadRevision()', () => {
    let editor = null
    beforeEach(() => {
      atom.config.set('editor.confirmCheckoutHeadRevision', false)

      waitsForPromise(() => atom.workspace.open('sample-with-comments.js').then(o => { editor = o }))
    })

    it('reverts to the version of its file checked into the project repository', () => {
      editor.setCursorBufferPosition([0, 0])
      editor.insertText('---\n')
      expect(editor.lineTextForBufferRow(0)).toBe('---')

      waitsForPromise(() => atom.workspace.checkoutHeadRevision(editor))

      runs(() => expect(editor.lineTextForBufferRow(0)).toBe(''))
    })

    describe("when there's no repository for the editor's file", () => {
      it("doesn't do anything", () => {
        editor = new TextEditor()
        editor.setText('stuff')
        atom.workspace.checkoutHeadRevision(editor)

        waitsForPromise(() => atom.workspace.checkoutHeadRevision(editor))
      })
    })
  })

  describe('when an item is moved', () => {
    beforeEach(() => {
      atom.workspace.enablePersistence = true
    })

    afterEach(async () => {
      await atom.workspace.itemLocationStore.clear()
      atom.workspace.enablePersistence = false
    })

    it("stores the new location if it's not the default", () => {
      const ITEM_URI = 'atom://test'
      const item = {
        getURI: () => ITEM_URI,
        getDefaultLocation: () => 'left',
        getElement: () => document.createElement('div')
      }
      const centerPane = workspace.getActivePane()
      centerPane.addItem(item)
      const dockPane = atom.workspace.getRightDock().getActivePane()
      spyOn(workspace.itemLocationStore, 'save')
      centerPane.moveItemToPane(item, dockPane)
      expect(workspace.itemLocationStore.save).toHaveBeenCalledWith(ITEM_URI, 'right')
    })

    it("clears the location if it's the default", () => {
      const ITEM_URI = 'atom://test'
      const item = {
        getURI: () => ITEM_URI,
        getDefaultLocation: () => 'right',
        getElement: () => document.createElement('div')
      }
      const centerPane = workspace.getActivePane()
      centerPane.addItem(item)
      const dockPane = atom.workspace.getRightDock().getActivePane()
      spyOn(workspace.itemLocationStore, 'save')
      spyOn(workspace.itemLocationStore, 'delete')
      centerPane.moveItemToPane(item, dockPane)
      expect(workspace.itemLocationStore.delete).toHaveBeenCalledWith(ITEM_URI)
      expect(workspace.itemLocationStore.save).not.toHaveBeenCalled()
    })
  })
})

const escapeStringRegex = str => str.replace(/[|\\{}()[\]^$+*?.]/g, '\\$&')
