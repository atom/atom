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

describe('Workspace', function () {
  let escapeStringRegex
  let [workspace, setDocumentEdited] = Array.from([])

  beforeEach(function () {
    ({ workspace } = atom)
    workspace.resetFontSize()
    spyOn(atom.applicationDelegate, 'confirm')
    setDocumentEdited = spyOn(atom.applicationDelegate, 'setWindowDocumentEdited')
    atom.project.setPaths([__guard__(atom.project.getDirectories()[0], x => x.resolve('dir'))])
    return waits(1)
  })

  afterEach(() => temp.cleanupSync())

  describe('serialization', function () {
    const simulateReload = function () {
      const workspaceState = atom.workspace.serialize()
      const projectState = atom.project.serialize({isUnloading: true})
      atom.workspace.destroy()
      atom.project.destroy()
      atom.project = new Project({notificationManager: atom.notifications, packageManager: atom.packages, confirm: atom.confirm.bind(atom), applicationDelegate: atom.applicationDelegate})
      atom.project.deserialize(projectState)
      atom.workspace = new Workspace({
        config: atom.config,
        project: atom.project,
        packageManager: atom.packages,
        grammarRegistry: atom.grammars,
        deserializerManager: atom.deserializers,
        notificationManager: atom.notifications,
        applicationDelegate: atom.applicationDelegate,
        viewRegistry: atom.views,
        assert: atom.assert.bind(atom),
        textEditorRegistry: atom.textEditors
      })
      return atom.workspace.deserialize(workspaceState, atom.deserializers)
    }

    describe('when the workspace contains text editors', () =>
      it('constructs the view with the same panes', function () {
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

        runs(function () {
          pane3.activeItem.setCursorScreenPosition([2, 4])
          return (pane4 = pane2.splitDown())
        })

        waitsForPromise(() =>
          atom.workspace.open('../sample.txt').then(editor => pane4.activateItem(editor))
        )

        return runs(function () {
          pane4.getActiveItem().setCursorScreenPosition([0, 2])
          pane2.activate()

          simulateReload()

          expect(atom.workspace.getTextEditors().length).toBe(5)
          const [editor1, editor2, untitledEditor, editor3, editor4] = Array.from(atom.workspace.getTextEditors())
          expect(editor1.getPath()).toBe(__guard__(atom.project.getDirectories()[0], x => x.resolve('b')))
          expect(editor2.getPath()).toBe(__guard__(atom.project.getDirectories()[0], x1 => x1.resolve('../sample.txt')))
          expect(editor2.getCursorScreenPosition()).toEqual([0, 2])
          expect(editor3.getPath()).toBe(__guard__(atom.project.getDirectories()[0], x2 => x2.resolve('b')))
          expect(editor4.getPath()).toBe(__guard__(atom.project.getDirectories()[0], x3 => x3.resolve('../sample.js')))
          expect(editor4.getCursorScreenPosition()).toEqual([2, 4])
          expect(untitledEditor.getPath()).toBeUndefined()
          expect(untitledEditor.getText()).toBe('An untitled editor.')

          expect(atom.workspace.getActiveTextEditor().getPath()).toBe(editor3.getPath())
          const pathEscaped = fs.tildify(escapeStringRegex(atom.project.getPaths()[0]))
          return expect(document.title).toMatch(new RegExp(`^${path.basename(editor3.getLongTitle())} \\u2014 ${pathEscaped}`))
        })
      })
    )

    return describe('where there are no open panes or editors', () =>
      it('constructs the view with no open editors', function () {
        atom.workspace.getActivePane().destroy()
        expect(atom.workspace.getTextEditors().length).toBe(0)
        simulateReload()
        return expect(atom.workspace.getTextEditors().length).toBe(0)
      })
    )
  })

  describe('::open(uri, options)', function () {
    let openEvents = null

    beforeEach(function () {
      openEvents = []
      workspace.onDidOpen(event => openEvents.push(event))
      return spyOn(workspace.getActivePane(), 'activate').andCallThrough()
    })

    describe("when the 'searchAllPanes' option is false (default)", function () {
      describe('when called without a uri', () =>
        it('adds and activates an empty editor on the active pane', function () {
          let [editor1, editor2] = Array.from([])

          waitsForPromise(() => workspace.open().then(editor => (editor1 = editor)))

          runs(function () {
            expect(editor1.getPath()).toBeUndefined()
            expect(workspace.getActivePane().items).toEqual([editor1])
            expect(workspace.getActivePaneItem()).toBe(editor1)
            expect(workspace.getActivePane().activate).toHaveBeenCalled()
            expect(openEvents).toEqual([{uri: undefined, pane: workspace.getActivePane(), item: editor1, index: 0}])
            return (openEvents = [])
          })

          waitsForPromise(() => workspace.open().then(editor => (editor2 = editor)))

          return runs(function () {
            expect(editor2.getPath()).toBeUndefined()
            expect(workspace.getActivePane().items).toEqual([editor1, editor2])
            expect(workspace.getActivePaneItem()).toBe(editor2)
            expect(workspace.getActivePane().activate).toHaveBeenCalled()
            return expect(openEvents).toEqual([{uri: undefined, pane: workspace.getActivePane(), item: editor2, index: 1}])
          })
        })
      )

      return describe('when called with a uri', function () {
        describe('when the active pane already has an editor for the given uri', () =>
          it('activates the existing editor on the active pane', function () {
            let editor = null
            let editor1 = null
            let editor2 = null

            waitsForPromise(() =>
              workspace.open('a').then(function (o) {
                editor1 = o
                return workspace.open('b').then(function (o) {
                  editor2 = o
                  return workspace.open('a').then(o => (editor = o))
                })
              })
            )

            return runs(function () {
              expect(editor).toBe(editor1)
              expect(workspace.getActivePaneItem()).toBe(editor)
              expect(workspace.getActivePane().activate).toHaveBeenCalled()

              return expect(openEvents).toEqual([
                {
                  uri: __guard__(atom.project.getDirectories()[0], x => x.resolve('a')),
                  item: editor1,
                  pane: atom.workspace.getActivePane(),
                  index: 0
                },
                {
                  uri: __guard__(atom.project.getDirectories()[0], x1 => x1.resolve('b')),
                  item: editor2,
                  pane: atom.workspace.getActivePane(),
                  index: 1
                },
                {
                  uri: __guard__(atom.project.getDirectories()[0], x2 => x2.resolve('a')),
                  item: editor1,
                  pane: atom.workspace.getActivePane(),
                  index: 0
                }
              ])
            })
          })
        )

        return describe('when the active pane does not have an editor for the given uri', () =>
          it('adds and activates a new editor for the given path on the active pane', function () {
            let editor = null
            waitsForPromise(() => workspace.open('a').then(o => (editor = o)))

            return runs(function () {
              expect(editor.getURI()).toBe(__guard__(atom.project.getDirectories()[0], x => x.resolve('a')))
              expect(workspace.getActivePaneItem()).toBe(editor)
              expect(workspace.getActivePane().items).toEqual([editor])
              return expect(workspace.getActivePane().activate).toHaveBeenCalled()
            })
          })
        )
      })
    })

    describe("when the 'searchAllPanes' option is true", function () {
      describe('when an editor for the given uri is already open on an inactive pane', () =>
        it('activates the existing editor on the inactive pane, then activates that pane', function () {
          let editor1 = null
          let editor2 = null
          const pane1 = workspace.getActivePane()
          const pane2 = workspace.getActivePane().splitRight()

          waitsForPromise(function () {
            pane1.activate()
            return workspace.open('a').then(o => (editor1 = o))
          })

          waitsForPromise(function () {
            pane2.activate()
            return workspace.open('b').then(o => (editor2 = o))
          })

          runs(() => expect(workspace.getActivePaneItem()).toBe(editor2))

          waitsForPromise(() => workspace.open('a', {searchAllPanes: true}))

          return runs(function () {
            expect(workspace.getActivePane()).toBe(pane1)
            return expect(workspace.getActivePaneItem()).toBe(editor1)
          })
        })
      )

      return describe('when no editor for the given uri is open in any pane', () =>
        it('opens an editor for the given uri in the active pane', function () {
          let editor = null
          waitsForPromise(() => workspace.open('a', {searchAllPanes: true}).then(o => (editor = o)))

          return runs(() => expect(workspace.getActivePaneItem()).toBe(editor))
        })
      )
    })

    describe("when the 'split' option is set", function () {
      describe("when the 'split' option is 'left'", () =>
        it('opens the editor in the leftmost pane of the current pane axis', function () {
          const pane1 = workspace.getActivePane()
          const pane2 = pane1.splitRight()
          expect(workspace.getActivePane()).toBe(pane2)

          let editor = null
          waitsForPromise(() => workspace.open('a', {split: 'left'}).then(o => (editor = o)))

          runs(function () {
            expect(workspace.getActivePane()).toBe(pane1)
            expect(pane1.items).toEqual([editor])
            return expect(pane2.items).toEqual([])
          })

          // Focus right pane and reopen the file on the left
          waitsForPromise(function () {
            pane2.focus()
            return workspace.open('a', {split: 'left'}).then(o => (editor = o))
          })

          return runs(function () {
            expect(workspace.getActivePane()).toBe(pane1)
            expect(pane1.items).toEqual([editor])
            return expect(pane2.items).toEqual([])
          })
        })
      )

      describe('when a pane axis is the leftmost sibling of the current pane', () =>
        it('opens the new item in the current pane', function () {
          let editor = null
          const pane1 = workspace.getActivePane()
          const pane2 = pane1.splitLeft()
          pane2.splitDown()
          pane1.activate()
          expect(workspace.getActivePane()).toBe(pane1)

          waitsForPromise(() => workspace.open('a', {split: 'left'}).then(o => (editor = o)))

          return runs(function () {
            expect(workspace.getActivePane()).toBe(pane1)
            return expect(pane1.items).toEqual([editor])
          })
        })
      )

      describe("when the 'split' option is 'right'", function () {
        it('opens the editor in the rightmost pane of the current pane axis', function () {
          let editor = null
          const pane1 = workspace.getActivePane()
          let pane2 = null
          waitsForPromise(() => workspace.open('a', {split: 'right'}).then(o => (editor = o)))

          runs(function () {
            pane2 = workspace.getPanes().filter(p => p !== pane1)[0]
            expect(workspace.getActivePane()).toBe(pane2)
            expect(pane1.items).toEqual([])
            return expect(pane2.items).toEqual([editor])
          })

          // Focus right pane and reopen the file on the right
          waitsForPromise(function () {
            pane1.focus()
            return workspace.open('a', {split: 'right'}).then(o => (editor = o))
          })

          return runs(function () {
            expect(workspace.getActivePane()).toBe(pane2)
            expect(pane1.items).toEqual([])
            return expect(pane2.items).toEqual([editor])
          })
        })

        return describe('when a pane axis is the rightmost sibling of the current pane', () =>
          it('opens the new item in a new pane split to the right of the current pane', function () {
            let editor = null
            const pane1 = workspace.getActivePane()
            const pane2 = pane1.splitRight()
            pane2.splitDown()
            pane1.activate()
            expect(workspace.getActivePane()).toBe(pane1)
            let pane4 = null

            waitsForPromise(() => workspace.open('a', {split: 'right'}).then(o => (editor = o)))

            return runs(function () {
              pane4 = workspace.getPanes().filter(p => p !== pane1)[0]
              expect(workspace.getActivePane()).toBe(pane4)
              expect(pane4.items).toEqual([editor])
              expect(workspace.paneContainer.root.children[0]).toBe(pane1)
              return expect(workspace.paneContainer.root.children[1]).toBe(pane4)
            })
          })
        )
      })

      describe("when the 'split' option is 'up'", () =>
        it('opens the editor in the topmost pane of the current pane axis', function () {
          const pane1 = workspace.getActivePane()
          const pane2 = pane1.splitDown()
          expect(workspace.getActivePane()).toBe(pane2)

          let editor = null
          waitsForPromise(() => workspace.open('a', {split: 'up'}).then(o => (editor = o)))

          runs(function () {
            expect(workspace.getActivePane()).toBe(pane1)
            expect(pane1.items).toEqual([editor])
            return expect(pane2.items).toEqual([])
          })

          // Focus bottom pane and reopen the file on the top
          waitsForPromise(function () {
            pane2.focus()
            return workspace.open('a', {split: 'up'}).then(o => (editor = o))
          })

          return runs(function () {
            expect(workspace.getActivePane()).toBe(pane1)
            expect(pane1.items).toEqual([editor])
            return expect(pane2.items).toEqual([])
          })
        })
      )

      describe('when a pane axis is the topmost sibling of the current pane', () =>
        it('opens the new item in the current pane', function () {
          let editor = null
          const pane1 = workspace.getActivePane()
          const pane2 = pane1.splitUp()
          pane2.splitRight()
          pane1.activate()
          expect(workspace.getActivePane()).toBe(pane1)

          waitsForPromise(() => workspace.open('a', {split: 'up'}).then(o => (editor = o)))

          return runs(function () {
            expect(workspace.getActivePane()).toBe(pane1)
            return expect(pane1.items).toEqual([editor])
          })
        })
      )

      return describe("when the 'split' option is 'down'", function () {
        it('opens the editor in the bottommost pane of the current pane axis', function () {
          let editor = null
          const pane1 = workspace.getActivePane()
          let pane2 = null
          waitsForPromise(() => workspace.open('a', {split: 'down'}).then(o => (editor = o)))

          runs(function () {
            pane2 = workspace.getPanes().filter(p => p !== pane1)[0]
            expect(workspace.getActivePane()).toBe(pane2)
            expect(pane1.items).toEqual([])
            return expect(pane2.items).toEqual([editor])
          })

          // Focus bottom pane and reopen the file on the right
          waitsForPromise(function () {
            pane1.focus()
            return workspace.open('a', {split: 'down'}).then(o => (editor = o))
          })

          return runs(function () {
            expect(workspace.getActivePane()).toBe(pane2)
            expect(pane1.items).toEqual([])
            return expect(pane2.items).toEqual([editor])
          })
        })

        return describe('when a pane axis is the bottommost sibling of the current pane', () =>
          it('opens the new item in a new pane split to the bottom of the current pane', function () {
            let editor = null
            const pane1 = workspace.getActivePane()
            const pane2 = pane1.splitDown()
            pane1.activate()
            expect(workspace.getActivePane()).toBe(pane1)
            let pane4 = null

            waitsForPromise(() => workspace.open('a', {split: 'down'}).then(o => (editor = o)))

            return runs(function () {
              pane4 = workspace.getPanes().filter(p => p !== pane1)[0]
              expect(workspace.getActivePane()).toBe(pane4)
              expect(pane4.items).toEqual([editor])
              expect(workspace.paneContainer.root.children[0]).toBe(pane1)
              return expect(workspace.paneContainer.root.children[1]).toBe(pane2)
            })
          })
        )
      })
    })

    describe('when an initialLine and initialColumn are specified', () =>
      it('moves the cursor to the indicated location', function () {
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

        return runs(() => expect(workspace.getActiveTextEditor().getCursorBufferPosition()).toEqual([2, 11]))
      })
    )

    describe('when the file is over 2MB', () =>
      it('opens the editor with largeFileMode: true', function () {
        spyOn(fs, 'getSizeSync').andReturn(2 * 1048577) // 2MB

        let editor = null
        waitsForPromise(() => workspace.open('sample.js').then(e => (editor = e)))

        return runs(() => expect(editor.largeFileMode).toBe(true))
      })
    )

    describe('when the file is over user-defined limit', function () {
      const shouldPromptForFileOfSize = function (size, shouldPrompt) {
        spyOn(fs, 'getSizeSync').andReturn(size * 1048577)
        atom.applicationDelegate.confirm.andCallFake(() => selectedButtonIndex)
        atom.applicationDelegate.confirm()
        var selectedButtonIndex = 1 // cancel

        let editor = null
        waitsForPromise(() => workspace.open('sample.js').then(e => (editor = e)))
        if (shouldPrompt) {
          runs(function () {
            expect(editor).toBeUndefined()
            expect(atom.applicationDelegate.confirm).toHaveBeenCalled()

            atom.applicationDelegate.confirm.reset()
            return (selectedButtonIndex = 0)
          }) // open the file

          waitsForPromise(() => workspace.open('sample.js').then(e => (editor = e)))

          return runs(function () {
            expect(atom.applicationDelegate.confirm).toHaveBeenCalled()
            return expect(editor.largeFileMode).toBe(true)
          })
        } else {
          return runs(() => expect(editor).not.toBeUndefined())
        }
      }

      it('prompts the user to make sure they want to open a file this big', function () {
        atom.config.set('core.warnOnLargeFileLimit', 20)
        return shouldPromptForFileOfSize(20, true)
      })

      it("doesn't prompt on files below the limit", function () {
        atom.config.set('core.warnOnLargeFileLimit', 30)
        return shouldPromptForFileOfSize(20, false)
      })

      return it('prompts for smaller files with a lower limit', function () {
        atom.config.set('core.warnOnLargeFileLimit', 5)
        return shouldPromptForFileOfSize(10, true)
      })
    })

    describe('when passed a path that matches a custom opener', () =>
      it('returns the resource returned by the custom opener', function () {
        const fooOpener = function (pathToOpen, options) { if (pathToOpen != null ? pathToOpen.match(/\.foo/) : undefined) { return {foo: pathToOpen, options} } }
        const barOpener = function (pathToOpen) { if (pathToOpen != null ? pathToOpen.match(/^bar:\/\//) : undefined) { return {bar: pathToOpen} } }
        workspace.addOpener(fooOpener)
        workspace.addOpener(barOpener)

        waitsForPromise(function () {
          const pathToOpen = __guard__(atom.project.getDirectories()[0], x => x.resolve('a.foo'))
          return workspace.open(pathToOpen, {hey: 'there'}).then(item => expect(item).toEqual({foo: pathToOpen, options: {hey: 'there'}}))
        })

        return waitsForPromise(() =>
          workspace.open('bar://baz').then(item => expect(item).toEqual({bar: 'bar://baz'})))
      })
    )

    it("adds the file to the application's recent documents list", function () {
      if (process.platform !== 'darwin') { return } // Feature only supported on macOS
      spyOn(atom.applicationDelegate, 'addRecentDocument')

      waitsForPromise(() => workspace.open())

      runs(() => expect(atom.applicationDelegate.addRecentDocument).not.toHaveBeenCalled())

      waitsForPromise(() => workspace.open('something://a/url'))

      runs(() => expect(atom.applicationDelegate.addRecentDocument).not.toHaveBeenCalled())

      waitsForPromise(() => workspace.open(__filename))

      return runs(() => expect(atom.applicationDelegate.addRecentDocument).toHaveBeenCalledWith(__filename))
    })

    it('notifies ::onDidAddTextEditor observers', function () {
      const absolutePath = require.resolve('./fixtures/dir/a')
      const newEditorHandler = jasmine.createSpy('newEditorHandler')
      workspace.onDidAddTextEditor(newEditorHandler)

      let editor = null
      waitsForPromise(() => workspace.open(absolutePath).then(e => (editor = e)))

      return runs(() => expect(newEditorHandler.argsForCall[0][0].textEditor).toBe(editor))
    })

    describe('when there is an error opening the file', function () {
      let notificationSpy = null
      beforeEach(() => atom.notifications.onDidAddNotification(notificationSpy = jasmine.createSpy()))

      describe('when a file does not exist', () =>
        it('creates an empty buffer for the specified path', function () {
          waitsForPromise(() => workspace.open('not-a-file.md'))

          return runs(function () {
            const editor = workspace.getActiveTextEditor()
            expect(notificationSpy).not.toHaveBeenCalled()
            return expect(editor.getPath()).toContain('not-a-file.md')
          })
        })
      )

      describe('when the user does not have access to the file', function () {
        beforeEach(() =>
          spyOn(fs, 'openSync').andCallFake(function (path) {
            const error = new Error(`EACCES, permission denied '${path}'`)
            error.path = path
            error.code = 'EACCES'
            throw error
          })
        )

        return it('creates a notification', function () {
          waitsForPromise(() => workspace.open('file1'))

          return runs(function () {
            expect(notificationSpy).toHaveBeenCalled()
            const notification = notificationSpy.mostRecentCall.args[0]
            expect(notification.getType()).toBe('warning')
            expect(notification.getMessage()).toContain('Permission denied')
            return expect(notification.getMessage()).toContain('file1')
          })
        })
      })

      describe('when the the operation is not permitted', function () {
        beforeEach(() =>
          spyOn(fs, 'openSync').andCallFake(function (path) {
            const error = new Error(`EPERM, operation not permitted '${path}'`)
            error.path = path
            error.code = 'EPERM'
            throw error
          })
        )

        return it('creates a notification', function () {
          waitsForPromise(() => workspace.open('file1'))

          return runs(function () {
            expect(notificationSpy).toHaveBeenCalled()
            const notification = notificationSpy.mostRecentCall.args[0]
            expect(notification.getType()).toBe('warning')
            expect(notification.getMessage()).toContain('Unable to open')
            return expect(notification.getMessage()).toContain('file1')
          })
        })
      })

      describe('when the the file is already open in windows', function () {
        beforeEach(() =>
          spyOn(fs, 'openSync').andCallFake(function (path) {
            const error = new Error(`EBUSY, resource busy or locked '${path}'`)
            error.path = path
            error.code = 'EBUSY'
            throw error
          })
        )

        return it('creates a notification', function () {
          waitsForPromise(() => workspace.open('file1'))

          return runs(function () {
            expect(notificationSpy).toHaveBeenCalled()
            const notification = notificationSpy.mostRecentCall.args[0]
            expect(notification.getType()).toBe('warning')
            expect(notification.getMessage()).toContain('Unable to open')
            return expect(notification.getMessage()).toContain('file1')
          })
        })
      })

      return describe('when there is an unhandled error', function () {
        beforeEach(() =>
          spyOn(fs, 'openSync').andCallFake(function (path) {
            throw new Error('I dont even know what is happening right now!!')
          })
        )

        return it('creates a notification', function () {
          const open = () => workspace.open('file1', workspace.getActivePane())
          return expect(open).toThrow()
        })
      })
    })

    describe('when the file is already open in pending state', () =>
      it('should terminate the pending state', function () {
        let editor = null
        let pane = null

        waitsForPromise(() =>
          atom.workspace.open('sample.js', {pending: true}).then(function (o) {
            editor = o
            return (pane = atom.workspace.getActivePane())
          })
        )

        runs(() => expect(pane.getPendingItem()).toEqual(editor))

        waitsForPromise(() => atom.workspace.open('sample.js'))

        return runs(() => expect(pane.getPendingItem()).toBeNull())
      })
    )

    describe('when opening will switch from a pending tab to a permanent tab', () =>
      it('keeps the pending tab open', function () {
        let editor1 = null
        let editor2 = null

        waitsForPromise(() =>
          atom.workspace.open('sample.txt').then(o => (editor1 = o))
        )

        waitsForPromise(() =>
          atom.workspace.open('sample2.txt', {pending: true}).then(o => (editor2 = o))
        )

        return runs(function () {
          const pane = atom.workspace.getActivePane()
          pane.activateItem(editor1)
          expect(pane.getItems().length).toBe(2)
          return expect(pane.getItems()).toEqual([editor1, editor2])
        })
      })
    )

    return describe('when replacing a pending item which is the last item in a second pane', () =>
      it('does not destroy the pane even if core.destroyEmptyPanes is on', function () {
        atom.config.set('core.destroyEmptyPanes', true)
        let editor1 = null
        let editor2 = null
        const leftPane = atom.workspace.getActivePane()
        let rightPane = null

        waitsForPromise(() =>
          atom.workspace.open('sample.js', {pending: true, split: 'right'}).then(function (o) {
            editor1 = o
            rightPane = atom.workspace.getActivePane()
            return spyOn(rightPane, 'destroyed')
          })
        )

        runs(function () {
          expect(leftPane).not.toBe(rightPane)
          expect(atom.workspace.getActivePane()).toBe(rightPane)
          expect(atom.workspace.getActivePane().getItems().length).toBe(1)
          return expect(rightPane.getPendingItem()).toBe(editor1)
        })

        waitsForPromise(() =>
          atom.workspace.open('sample.txt', {pending: true}).then(o => (editor2 = o))
        )

        return runs(function () {
          expect(rightPane.getPendingItem()).toBe(editor2)
          return expect(rightPane.destroyed.callCount).toBe(0)
        })
      })
    )
  })

  describe('the grammar-used hook', () =>
    it('fires when opening a file or changing the grammar of an open file', function () {
      let editor = null
      let javascriptGrammarUsed = false
      let coffeescriptGrammarUsed = false

      atom.packages.triggerDeferredActivationHooks()

      runs(function () {
        atom.packages.onDidTriggerActivationHook('language-javascript:grammar-used', () => (javascriptGrammarUsed = true))
        return atom.packages.onDidTriggerActivationHook('language-coffee-script:grammar-used', () => (coffeescriptGrammarUsed = true))
      })

      waitsForPromise(() => atom.workspace.open('sample.js', {autoIndent: false}).then(o => (editor = o)))

      waitsForPromise(() => atom.packages.activatePackage('language-javascript'))

      waitsFor(() => javascriptGrammarUsed)

      waitsForPromise(() => atom.packages.activatePackage('language-coffee-script'))

      runs(() => editor.setGrammar(atom.grammars.selectGrammar('.coffee')))

      return waitsFor(() => coffeescriptGrammarUsed)
    })
  )

  describe('::reopenItem()', () =>
    it("opens the uri associated with the last closed pane that isn't currently open", function () {
      const pane = workspace.getActivePane()
      waitsForPromise(() =>
        workspace.open('a').then(() =>
          workspace.open('b').then(() =>
            workspace.open('file1').then(() => workspace.open())
          )
        )
      )

      runs(function () {
        // does not reopen items with no uri
        expect(workspace.getActivePaneItem().getURI()).toBeUndefined()
        return pane.destroyActiveItem()
      })

      waitsForPromise(() => workspace.reopenItem())

      runs(function () {
        expect(workspace.getActivePaneItem().getURI()).not.toBeUndefined()

        // destroy all items
        expect(workspace.getActivePaneItem().getURI()).toBe(__guard__(atom.project.getDirectories()[0], x => x.resolve('file1')))
        pane.destroyActiveItem()
        expect(workspace.getActivePaneItem().getURI()).toBe(__guard__(atom.project.getDirectories()[0], x1 => x1.resolve('b')))
        pane.destroyActiveItem()
        expect(workspace.getActivePaneItem().getURI()).toBe(__guard__(atom.project.getDirectories()[0], x2 => x2.resolve('a')))
        pane.destroyActiveItem()

        // reopens items with uris
        return expect(workspace.getActivePaneItem()).toBeUndefined()
      })

      waitsForPromise(() => workspace.reopenItem())

      runs(() => expect(workspace.getActivePaneItem().getURI()).toBe(__guard__(atom.project.getDirectories()[0], x => x.resolve('a'))))

      // does not reopen items that are already open
      waitsForPromise(() => workspace.open('b'))

      runs(() => expect(workspace.getActivePaneItem().getURI()).toBe(__guard__(atom.project.getDirectories()[0], x => x.resolve('b'))))

      waitsForPromise(() => workspace.reopenItem())

      return runs(() => expect(workspace.getActivePaneItem().getURI()).toBe(__guard__(atom.project.getDirectories()[0], x => x.resolve('file1'))))
    })
  )

  describe('::increase/decreaseFontSize()', () =>
    it('increases/decreases the font size without going below 1', function () {
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
      return expect(atom.config.get('editor.fontSize')).toBe(1)
    })
  )

  describe('::resetFontSize()', function () {
    it("resets the font size to the window's starting font size", function () {
      const originalFontSize = atom.config.get('editor.fontSize')

      workspace.increaseFontSize()
      expect(atom.config.get('editor.fontSize')).toBe(originalFontSize + 1)
      workspace.resetFontSize()
      expect(atom.config.get('editor.fontSize')).toBe(originalFontSize)
      workspace.decreaseFontSize()
      expect(atom.config.get('editor.fontSize')).toBe(originalFontSize - 1)
      workspace.resetFontSize()
      return expect(atom.config.get('editor.fontSize')).toBe(originalFontSize)
    })

    it('does nothing if the font size has not been changed', function () {
      const originalFontSize = atom.config.get('editor.fontSize')

      workspace.resetFontSize()
      return expect(atom.config.get('editor.fontSize')).toBe(originalFontSize)
    })

    return it("resets the font size when the editor's font size changes", function () {
      const originalFontSize = atom.config.get('editor.fontSize')

      atom.config.set('editor.fontSize', originalFontSize + 1)
      workspace.resetFontSize()
      expect(atom.config.get('editor.fontSize')).toBe(originalFontSize)
      atom.config.set('editor.fontSize', originalFontSize - 1)
      workspace.resetFontSize()
      return expect(atom.config.get('editor.fontSize')).toBe(originalFontSize)
    })
  })

  describe('::openLicense()', () =>
    it('opens the license as plain-text in a buffer', function () {
      waitsForPromise(() => workspace.openLicense())
      return runs(() => expect(workspace.getActivePaneItem().getText()).toMatch(/Copyright/))
    })
  )

  describe('::isTextEditor(obj)', () =>
    it('returns true when the passed object is an instance of `TextEditor`', function () {
      expect(workspace.isTextEditor(new TextEditor())).toBe(true)
      expect(workspace.isTextEditor({getText () { return null }})).toBe(false)
      expect(workspace.isTextEditor(null)).toBe(false)
      return expect(workspace.isTextEditor(undefined)).toBe(false)
    })
  )

  describe('::observeTextEditors()', () =>
    it('invokes the observer with current and future text editors', function () {
      const observed = []

      waitsForPromise(() => workspace.open())
      waitsForPromise(() => workspace.open())
      waitsForPromise(() => workspace.openLicense())

      runs(() => workspace.observeTextEditors(editor => observed.push(editor)))

      waitsForPromise(() => workspace.open())

      return expect(observed).toEqual(workspace.getTextEditors())
    })
  )

  describe('when an editor is destroyed', () =>
    it('removes the editor', function () {
      let editor = null

      waitsForPromise(() => workspace.open('a').then(e => (editor = e)))

      return runs(function () {
        expect(workspace.getTextEditors()).toHaveLength(1)
        editor.destroy()
        return expect(workspace.getTextEditors()).toHaveLength(0)
      })
    })
  )

  describe('when an editor is copied because its pane is split', () =>
    it('sets up the new editor to be configured by the text editor registry', function () {
      waitsForPromise(() => atom.packages.activatePackage('language-javascript'))

      return waitsForPromise(() =>
        workspace.open('a').then(function (editor) {
          atom.textEditors.setGrammarOverride(editor, 'source.js')
          expect(editor.getGrammar().name).toBe('JavaScript')

          workspace.getActivePane().splitRight({copyActiveItem: true})
          const newEditor = workspace.getActiveTextEditor()
          expect(newEditor).not.toBe(editor)
          return expect(newEditor.getGrammar().name).toBe('JavaScript')
        })
      )
    })
  )

  it('stores the active grammars used by all the open editors', function () {
    waitsForPromise(() => atom.packages.activatePackage('language-javascript'))

    waitsForPromise(() => atom.packages.activatePackage('language-coffee-script'))

    waitsForPromise(() => atom.packages.activatePackage('language-todo'))

    waitsForPromise(() => atom.workspace.open('sample.coffee'))

    return runs(function () {
      atom.workspace.getActiveTextEditor().setText(`\
i = /test/; #FIXME\
`
      )

      const atom2 = new AtomEnvironment({
        applicationDelegate: atom.applicationDelegate,
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

      return atom2.destroy()
    })
  })

  describe('document.title', function () {
    describe('when there is no item open', function () {
      it('sets the title to the project path', () => expect(document.title).toMatch(escapeStringRegex(fs.tildify(atom.project.getPaths()[0]))))

      return it("sets the title to 'untitled' if there is no project path", function () {
        atom.project.setPaths([])
        return expect(document.title).toMatch(/^untitled/)
      })
    })

    describe("when the active pane item's path is not inside a project path", function () {
      beforeEach(() =>
        waitsForPromise(() =>
          atom.workspace.open('b').then(() => atom.project.setPaths([]))
        )
      )

      it("sets the title to the pane item's title plus the item's path", function () {
        const item = atom.workspace.getActivePaneItem()
        const pathEscaped = fs.tildify(escapeStringRegex(path.dirname(item.getPath())))
        return expect(document.title).toMatch(new RegExp(`^${item.getTitle()} \\u2014 ${pathEscaped}`))
      })

      describe('when the title of the active pane item changes', () =>
        it("updates the window title based on the item's new title", function () {
          const editor = atom.workspace.getActivePaneItem()
          editor.buffer.setPath(path.join(temp.dir, 'hi'))
          const pathEscaped = fs.tildify(escapeStringRegex(path.dirname(editor.getPath())))
          return expect(document.title).toMatch(new RegExp(`^${editor.getTitle()} \\u2014 ${pathEscaped}`))
        })
      )

      describe("when the active pane's item changes", () =>
        it("updates the title to the new item's title plus the project path", function () {
          atom.workspace.getActivePane().activateNextItem()
          const item = atom.workspace.getActivePaneItem()
          const pathEscaped = fs.tildify(escapeStringRegex(path.dirname(item.getPath())))
          return expect(document.title).toMatch(new RegExp(`^${item.getTitle()} \\u2014 ${pathEscaped}`))
        })
      )

      return describe("when an inactive pane's item changes", () =>
        it('does not update the title', function () {
          const pane = atom.workspace.getActivePane()
          pane.splitRight()
          const initialTitle = document.title
          pane.activateNextItem()
          return expect(document.title).toBe(initialTitle)
        })
      )
    })

    describe('when the active pane item is inside a project path', function () {
      beforeEach(() =>
        waitsForPromise(() => atom.workspace.open('b'))
      )

      describe('when there is an active pane item', () =>
        it("sets the title to the pane item's title plus the project path", function () {
          const item = atom.workspace.getActivePaneItem()
          const pathEscaped = fs.tildify(escapeStringRegex(atom.project.getPaths()[0]))
          return expect(document.title).toMatch(new RegExp(`^${item.getTitle()} \\u2014 ${pathEscaped}`))
        })
      )

      describe('when the title of the active pane item changes', () =>
        it("updates the window title based on the item's new title", function () {
          const editor = atom.workspace.getActivePaneItem()
          editor.buffer.setPath(path.join(atom.project.getPaths()[0], 'hi'))
          const pathEscaped = fs.tildify(escapeStringRegex(atom.project.getPaths()[0]))
          return expect(document.title).toMatch(new RegExp(`^${editor.getTitle()} \\u2014 ${pathEscaped}`))
        })
      )

      describe("when the active pane's item changes", () =>
        it("updates the title to the new item's title plus the project path", function () {
          atom.workspace.getActivePane().activateNextItem()
          const item = atom.workspace.getActivePaneItem()
          const pathEscaped = fs.tildify(escapeStringRegex(atom.project.getPaths()[0]))
          return expect(document.title).toMatch(new RegExp(`^${item.getTitle()} \\u2014 ${pathEscaped}`))
        })
      )

      describe('when the last pane item is removed', () =>
        it("updates the title to the project's first path", function () {
          atom.workspace.getActivePane().destroy()
          expect(atom.workspace.getActivePaneItem()).toBeUndefined()
          return expect(document.title).toMatch(escapeStringRegex(fs.tildify(atom.project.getPaths()[0])))
        })
      )

      return describe("when an inactive pane's item changes", () =>
        it('does not update the title', function () {
          const pane = atom.workspace.getActivePane()
          pane.splitRight()
          const initialTitle = document.title
          pane.activateNextItem()
          return expect(document.title).toBe(initialTitle)
        })
      )
    })

    return describe('when the workspace is deserialized', function () {
      beforeEach(() => waitsForPromise(() => atom.workspace.open('a')))

      return it("updates the title to contain the project's path", function () {
        document.title = null

        const atom2 = new AtomEnvironment({
          applicationDelegate: atom.applicationDelegate,
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

        return atom2.destroy()
      })
    })
  })

  describe('document edited status', function () {
    let [item1, item2] = Array.from([])

    beforeEach(function () {
      waitsForPromise(() => atom.workspace.open('a'))
      waitsForPromise(() => atom.workspace.open('b'))
      return runs(() => ([item1, item2] = Array.from(atom.workspace.getPaneItems())))
    })

    it('calls setDocumentEdited when the active item changes', function () {
      expect(atom.workspace.getActivePaneItem()).toBe(item2)
      item1.insertText('a')
      expect(item1.isModified()).toBe(true)
      atom.workspace.getActivePane().activateNextItem()

      return expect(setDocumentEdited).toHaveBeenCalledWith(true)
    })

    return it("calls atom.setDocumentEdited when the active item's modified status changes", function () {
      expect(atom.workspace.getActivePaneItem()).toBe(item2)
      item2.insertText('a')
      advanceClock(item2.getBuffer().getStoppedChangingDelay())

      expect(item2.isModified()).toBe(true)
      expect(setDocumentEdited).toHaveBeenCalledWith(true)

      item2.undo()
      advanceClock(item2.getBuffer().getStoppedChangingDelay())

      expect(item2.isModified()).toBe(false)
      return expect(setDocumentEdited).toHaveBeenCalledWith(false)
    })
  })

  describe('adding panels', function () {
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

    describe('::addLeftPanel(model)', () =>
      it('adds a panel to the correct panel container', function () {
        let addPanelSpy
        expect(atom.workspace.getLeftPanels().length).toBe(0)
        atom.workspace.panelContainers.left.onDidAddPanel(addPanelSpy = jasmine.createSpy())

        const model = new TestItem()
        const panel = atom.workspace.addLeftPanel({item: model})

        expect(panel).toBeDefined()
        expect(addPanelSpy).toHaveBeenCalledWith({panel, index: 0})

        const itemView = atom.views.getView(atom.workspace.getLeftPanels()[0].getItem())
        expect(itemView instanceof TestItemElement).toBe(true)
        return expect(itemView.getModel()).toBe(model)
      })
    )

    describe('::addRightPanel(model)', () =>
      it('adds a panel to the correct panel container', function () {
        let addPanelSpy
        expect(atom.workspace.getRightPanels().length).toBe(0)
        atom.workspace.panelContainers.right.onDidAddPanel(addPanelSpy = jasmine.createSpy())

        const model = new TestItem()
        const panel = atom.workspace.addRightPanel({item: model})

        expect(panel).toBeDefined()
        expect(addPanelSpy).toHaveBeenCalledWith({panel, index: 0})

        const itemView = atom.views.getView(atom.workspace.getRightPanels()[0].getItem())
        expect(itemView instanceof TestItemElement).toBe(true)
        return expect(itemView.getModel()).toBe(model)
      })
    )

    describe('::addTopPanel(model)', () =>
      it('adds a panel to the correct panel container', function () {
        let addPanelSpy
        expect(atom.workspace.getTopPanels().length).toBe(0)
        atom.workspace.panelContainers.top.onDidAddPanel(addPanelSpy = jasmine.createSpy())

        const model = new TestItem()
        const panel = atom.workspace.addTopPanel({item: model})

        expect(panel).toBeDefined()
        expect(addPanelSpy).toHaveBeenCalledWith({panel, index: 0})

        const itemView = atom.views.getView(atom.workspace.getTopPanels()[0].getItem())
        expect(itemView instanceof TestItemElement).toBe(true)
        return expect(itemView.getModel()).toBe(model)
      })
    )

    describe('::addBottomPanel(model)', () =>
      it('adds a panel to the correct panel container', function () {
        let addPanelSpy
        expect(atom.workspace.getBottomPanels().length).toBe(0)
        atom.workspace.panelContainers.bottom.onDidAddPanel(addPanelSpy = jasmine.createSpy())

        const model = new TestItem()
        const panel = atom.workspace.addBottomPanel({item: model})

        expect(panel).toBeDefined()
        expect(addPanelSpy).toHaveBeenCalledWith({panel, index: 0})

        const itemView = atom.views.getView(atom.workspace.getBottomPanels()[0].getItem())
        expect(itemView instanceof TestItemElement).toBe(true)
        return expect(itemView.getModel()).toBe(model)
      })
    )

    describe('::addHeaderPanel(model)', () =>
      it('adds a panel to the correct panel container', function () {
        let addPanelSpy
        expect(atom.workspace.getHeaderPanels().length).toBe(0)
        atom.workspace.panelContainers.header.onDidAddPanel(addPanelSpy = jasmine.createSpy())

        const model = new TestItem()
        const panel = atom.workspace.addHeaderPanel({item: model})

        expect(panel).toBeDefined()
        expect(addPanelSpy).toHaveBeenCalledWith({panel, index: 0})

        const itemView = atom.views.getView(atom.workspace.getHeaderPanels()[0].getItem())
        expect(itemView instanceof TestItemElement).toBe(true)
        return expect(itemView.getModel()).toBe(model)
      })
    )

    describe('::addFooterPanel(model)', () =>
      it('adds a panel to the correct panel container', function () {
        let addPanelSpy
        expect(atom.workspace.getFooterPanels().length).toBe(0)
        atom.workspace.panelContainers.footer.onDidAddPanel(addPanelSpy = jasmine.createSpy())

        const model = new TestItem()
        const panel = atom.workspace.addFooterPanel({item: model})

        expect(panel).toBeDefined()
        expect(addPanelSpy).toHaveBeenCalledWith({panel, index: 0})

        const itemView = atom.views.getView(atom.workspace.getFooterPanels()[0].getItem())
        expect(itemView instanceof TestItemElement).toBe(true)
        return expect(itemView.getModel()).toBe(model)
      })
    )

    describe('::addModalPanel(model)', () =>
      it('adds a panel to the correct panel container', function () {
        let addPanelSpy
        expect(atom.workspace.getModalPanels().length).toBe(0)
        atom.workspace.panelContainers.modal.onDidAddPanel(addPanelSpy = jasmine.createSpy())

        const model = new TestItem()
        const panel = atom.workspace.addModalPanel({item: model})

        expect(panel).toBeDefined()
        expect(addPanelSpy).toHaveBeenCalledWith({panel, index: 0})

        const itemView = atom.views.getView(atom.workspace.getModalPanels()[0].getItem())
        expect(itemView instanceof TestItemElement).toBe(true)
        return expect(itemView.getModel()).toBe(model)
      })
    )

    return describe('::panelForItem(item)', () =>
      it('returns the panel associated with the item', function () {
        const item = new TestItem()
        const panel = atom.workspace.addLeftPanel({item})

        const itemWithNoPanel = new TestItem()

        expect(atom.workspace.panelForItem(item)).toBe(panel)
        return expect(atom.workspace.panelForItem(itemWithNoPanel)).toBe(null)
      })
    )
  })

  describe('::scan(regex, options, callback)', () =>
    describe('when called with a regex', function () {
      it('calls the callback with all regex results in all files in the project', function () {
        const results = []
        waitsForPromise(() =>
          atom.workspace.scan(/(a)+/, result => results.push(result))
        )

        return runs(function () {
          expect(results).toHaveLength(3)
          expect(results[0].filePath).toBe(__guard__(atom.project.getDirectories()[0], x => x.resolve('a')))
          expect(results[0].matches).toHaveLength(3)
          return expect(results[0].matches[0]).toEqual({
            matchText: 'aaa',
            lineText: 'aaa bbb',
            lineTextOffset: 0,
            range: [[0, 0], [0, 3]]
          })
        })
      })

      it('works with with escaped literals (like $ and ^)', function () {
        const results = []
        waitsForPromise(() => atom.workspace.scan(/\$\w+/, result => results.push(result)))

        return runs(function () {
          expect(results.length).toBe(1)

          const {filePath, matches} = results[0]
          expect(filePath).toBe(__guard__(atom.project.getDirectories()[0], x => x.resolve('a')))
          expect(matches).toHaveLength(1)
          return expect(matches[0]).toEqual({
            matchText: '$bill',
            lineText: 'dollar$bill',
            lineTextOffset: 0,
            range: [[2, 6], [2, 11]]
          })
        })
      })

      it('works on evil filenames', function () {
        atom.config.set('core.excludeVcsIgnoredPaths', false)
        platform.generateEvilFiles()
        atom.project.setPaths([path.join(__dirname, 'fixtures', 'evil-files')])
        const paths = []
        let matches = []
        waitsForPromise(() =>
          atom.workspace.scan(/evil/, function (result) {
            paths.push(result.filePath)
            return (matches = matches.concat(result.matches))
          })
        )

        return runs(function () {
          _.each(matches, m => expect(m.matchText).toEqual('evil'))

          if (platform.isWindows()) {
            expect(paths.length).toBe(3)
            expect(paths[0]).toMatch(/a_file_with_utf8.txt$/)
            expect(paths[1]).toMatch(/file with spaces.txt$/)
            return expect(path.basename(paths[2])).toBe('utfa\u0306.md')
          } else {
            expect(paths.length).toBe(5)
            expect(paths[0]).toMatch(/a_file_with_utf8.txt$/)
            expect(paths[1]).toMatch(/file with spaces.txt$/)
            expect(paths[2]).toMatch(/goddam\nnewlines$/m)
            expect(paths[3]).toMatch(/quote".txt$/m)
            return expect(path.basename(paths[4])).toBe('utfa\u0306.md')
          }
        })
      })

      it('ignores case if the regex includes the `i` flag', function () {
        const results = []
        waitsForPromise(() => atom.workspace.scan(/DOLLAR/i, result => results.push(result)))

        return runs(() => expect(results).toHaveLength(1))
      })

      describe('when the core.excludeVcsIgnoredPaths config is truthy', function () {
        let [projectPath, ignoredPath] = Array.from([])

        beforeEach(function () {
          const sourceProjectPath = path.join(__dirname, 'fixtures', 'git', 'working-dir')
          projectPath = path.join(temp.mkdirSync('atom'))

          const writerStream = fstream.Writer(projectPath)
          fstream.Reader(sourceProjectPath).pipe(writerStream)

          waitsFor(function (done) {
            writerStream.on('close', done)
            return writerStream.on('error', done)
          })

          return runs(function () {
            fs.rename(path.join(projectPath, 'git.git'), path.join(projectPath, '.git'))
            ignoredPath = path.join(projectPath, 'ignored.txt')
            return fs.writeFileSync(ignoredPath, 'this match should not be included')
          })
        })

        afterEach(function () {
          if (fs.existsSync(projectPath)) { return fs.removeSync(projectPath) }
        })

        return it('excludes ignored files', function () {
          atom.project.setPaths([projectPath])
          atom.config.set('core.excludeVcsIgnoredPaths', true)
          const resultHandler = jasmine.createSpy('result found')
          waitsForPromise(() =>
            atom.workspace.scan(/match/, results => resultHandler())
          )

          return runs(() => expect(resultHandler).not.toHaveBeenCalled())
        })
      })

      it('includes only files when a directory filter is specified', function () {
        const projectPath = path.join(path.join(__dirname, 'fixtures', 'dir'))
        atom.project.setPaths([projectPath])

        const filePath = path.join(projectPath, 'a-dir', 'oh-git')

        const paths = []
        let matches = []
        waitsForPromise(() =>
          atom.workspace.scan(/aaa/, {paths: [`a-dir${path.sep}`]}, function (result) {
            paths.push(result.filePath)
            return (matches = matches.concat(result.matches))
          })
        )

        return runs(function () {
          expect(paths.length).toBe(1)
          expect(paths[0]).toBe(filePath)
          return expect(matches.length).toBe(1)
        })
      })

      it("includes files and folders that begin with a '.'", function () {
        const projectPath = temp.mkdirSync('atom-spec-workspace')
        const filePath = path.join(projectPath, '.text')
        fs.writeFileSync(filePath, 'match this')
        atom.project.setPaths([projectPath])
        const paths = []
        let matches = []
        waitsForPromise(() =>
          atom.workspace.scan(/match this/, function (result) {
            paths.push(result.filePath)
            return (matches = matches.concat(result.matches))
          })
        )

        return runs(function () {
          expect(paths.length).toBe(1)
          expect(paths[0]).toBe(filePath)
          return expect(matches.length).toBe(1)
        })
      })

      it('excludes values in core.ignoredNames', function () {
        const ignoredNames = atom.config.get('core.ignoredNames')
        ignoredNames.push('a')
        atom.config.set('core.ignoredNames', ignoredNames)

        const resultHandler = jasmine.createSpy('result found')
        waitsForPromise(() =>
          atom.workspace.scan(/dollar/, results => resultHandler())
        )

        return runs(() => expect(resultHandler).not.toHaveBeenCalled())
      })

      it('scans buffer contents if the buffer is modified', function () {
        let editor = null
        const results = []

        waitsForPromise(() =>
          atom.workspace.open('a').then(function (o) {
            editor = o
            return editor.setText('Elephant')
          })
        )

        waitsForPromise(() => atom.workspace.scan(/a|Elephant/, result => results.push(result)))

        return runs(function () {
          expect(results).toHaveLength(3)
          const resultForA = _.find(results, ({filePath}) => path.basename(filePath) === 'a')
          expect(resultForA.matches).toHaveLength(1)
          return expect(resultForA.matches[0].matchText).toBe('Elephant')
        })
      })

      it('ignores buffers outside the project', function () {
        let editor = null
        const results = []

        waitsForPromise(() =>
          atom.workspace.open(temp.openSync().path).then(function (o) {
            editor = o
            return editor.setText('Elephant')
          })
        )

        waitsForPromise(() => atom.workspace.scan(/Elephant/, result => results.push(result)))

        return runs(() => expect(results).toHaveLength(0))
      })

      return describe('when the project has multiple root directories', function () {
        let [dir1, dir2, file1, file2] = Array.from([])

        beforeEach(function () {
          [dir1] = Array.from(atom.project.getPaths())
          file1 = path.join(dir1, 'a-dir', 'oh-git')

          dir2 = temp.mkdirSync('a-second-dir')
          const aDir2 = path.join(dir2, 'a-dir')
          file2 = path.join(aDir2, 'a-file')
          fs.mkdirSync(aDir2)
          fs.writeFileSync(file2, 'ccc aaaa')

          return atom.project.addPath(dir2)
        })

        it("searches matching files in all of the project's root directories", function () {
          const resultPaths = []
          waitsForPromise(() =>
            atom.workspace.scan(/aaaa/, ({filePath}) => resultPaths.push(filePath))
          )

          return runs(() => expect(resultPaths.sort()).toEqual([file1, file2].sort()))
        })

        describe('when an inclusion path starts with the basename of a root directory', () =>
          it('interprets the inclusion path as starting from that directory', function () {
            waitsForPromise(function () {
              const resultPaths = []
              return atom.workspace
                .scan(/aaaa/, {paths: ['dir']}, function ({filePath}) {
                  if (!Array.from(resultPaths).includes(filePath)) { return resultPaths.push(filePath) }
                })
                .then(() => expect(resultPaths).toEqual([file1]))
            })

            waitsForPromise(function () {
              const resultPaths = []
              return atom.workspace
                .scan(/aaaa/, {paths: [path.join('dir', 'a-dir')]}, function ({filePath}) {
                  if (!Array.from(resultPaths).includes(filePath)) { return resultPaths.push(filePath) }
                })
                .then(() => expect(resultPaths).toEqual([file1]))
            })

            waitsForPromise(function () {
              const resultPaths = []
              return atom.workspace
                .scan(/aaaa/, {paths: [path.basename(dir2)]}, function ({filePath}) {
                  if (!Array.from(resultPaths).includes(filePath)) { return resultPaths.push(filePath) }
                })
                .then(() => expect(resultPaths).toEqual([file2]))
            })

            return waitsForPromise(function () {
              const resultPaths = []
              return atom.workspace
                .scan(/aaaa/, {paths: [path.join(path.basename(dir2), 'a-dir')]}, function ({filePath}) {
                  if (!Array.from(resultPaths).includes(filePath)) { return resultPaths.push(filePath) }
                })
                .then(() => expect(resultPaths).toEqual([file2]))
            })
          })
        )

        return describe('when a custom directory searcher is registered', function () {
          let fakeSearch = null
          // Function that is invoked once all of the fields on fakeSearch are set.
          let onFakeSearchCreated = null

          class FakeSearch {
            constructor (options) {
              // Note that hoisting resolve and reject in this way is generally frowned upon.
              this.options = options
              this.promise = new Promise((function (resolve, reject) {
                this.hoistedResolve = resolve
                this.hoistedReject = reject
                return (typeof onFakeSearchCreated === 'function' ? onFakeSearchCreated(this) : undefined)
              }.bind(this)))
            }
            then (...args) {
              return this.promise.then.apply(this.promise, args)
            }
            cancel () {
              this.cancelled = true
              // According to the spec for a DirectorySearcher, invoking `cancel()` should
              // resolve the thenable rather than reject it.
              return this.hoistedResolve()
            }
          }

          beforeEach(function () {
            fakeSearch = null
            onFakeSearchCreated = null
            atom.packages.serviceHub.provide('atom.directory-searcher', '0.1.0', {
              canSearchDirectory (directory) { return directory.getPath() === dir1 },
              search (directory, regex, options) { return (fakeSearch = new FakeSearch(options)) }
            })

            return waitsFor(() => atom.workspace.directorySearchers.length > 0)
          })

          it('can override the DefaultDirectorySearcher on a per-directory basis', function () {
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
            onFakeSearchCreated = function (fakeSearch) {
              fakeSearch.options.didMatch(searchResult)
              fakeSearch.options.didSearchPaths(numPathsToPretendToSearchInCustomDirectorySearcher)
              return fakeSearch.hoistedResolve()
            }

            const resultPaths = []
            const onPathsSearched = jasmine.createSpy('onPathsSearched')
            waitsForPromise(() =>
              atom.workspace.scan(/aaaa/, {onPathsSearched}, ({filePath}) => resultPaths.push(filePath))
            )

            return runs(function () {
              expect(resultPaths.sort()).toEqual([foreignFilePath, file2].sort())
              // onPathsSearched should be called once by each DirectorySearcher. The order is not
              // guaranteed, so we can only verify the total number of paths searched is correct
              // after the second call.
              expect(onPathsSearched.callCount).toBe(2)
              return expect(onPathsSearched.mostRecentCall.args[0]).toBe(
                numPathsToPretendToSearchInCustomDirectorySearcher + numPathsSearchedInDir2)
            })
          })

          it('can be cancelled when the object returned by scan() has its cancel() method invoked', function () {
            const thenable = atom.workspace.scan(/aaaa/, function () {})
            let resultOfPromiseSearch = null

            waitsFor('fakeSearch to be defined', () => fakeSearch != null)

            runs(function () {
              expect(fakeSearch.cancelled).toBe(undefined)
              thenable.cancel()
              return expect(fakeSearch.cancelled).toBe(true)
            })

            waitsForPromise(() => thenable.then(promiseResult => (resultOfPromiseSearch = promiseResult)))

            return runs(() => expect(resultOfPromiseSearch).toBe('cancelled'))
          })

          return it('will have the side-effect of failing the overall search if it fails', function () {
            // This provider's search should be cancelled when the first provider fails
            let cancelableSearch
            let fakeSearch2 = null
            atom.packages.serviceHub.provide('atom.directory-searcher', '0.1.0', {
              canSearchDirectory (directory) { return directory.getPath() === dir2 },
              search (directory, regex, options) { return (fakeSearch2 = new FakeSearch(options)) }
            })

            let didReject = false
            const promise = cancelableSearch = atom.workspace.scan(/aaaa/, function () {})
            waitsFor('fakeSearch to be defined', () => fakeSearch != null)

            runs(() => fakeSearch.hoistedReject())

            waitsForPromise(() => cancelableSearch.catch(() => (didReject = true)))

            waitsFor(done => promise.then(null, done))

            return runs(function () {
              expect(didReject).toBe(true)
              return expect(fakeSearch2.cancelled).toBe(true)
            })
          })
        })
      })
    })
  ) // Cancels other ongoing searches

  describe('::replace(regex, replacementText, paths, iterator)', function () {
    let [filePath, commentFilePath, sampleContent, sampleCommentContent] = Array.from([])

    beforeEach(function () {
      atom.project.setPaths([__guard__(atom.project.getDirectories()[0], x => x.resolve('../'))])

      filePath = __guard__(atom.project.getDirectories()[0], x1 => x1.resolve('sample.js'))
      commentFilePath = __guard__(atom.project.getDirectories()[0], x2 => x2.resolve('sample-with-comments.js'))
      sampleContent = fs.readFileSync(filePath).toString()
      return (sampleCommentContent = fs.readFileSync(commentFilePath).toString())
    })

    afterEach(function () {
      fs.writeFileSync(filePath, sampleContent)
      return fs.writeFileSync(commentFilePath, sampleCommentContent)
    })

    describe("when a file doesn't exist", () =>
      it('calls back with an error', function () {
        const errors = []
        const missingPath = path.resolve('/not-a-file.js')
        expect(fs.existsSync(missingPath)).toBeFalsy()

        waitsForPromise(() =>
          atom.workspace.replace(/items/gi, 'items', [missingPath], (result, error) => errors.push(error))
        )

        return runs(function () {
          expect(errors).toHaveLength(1)
          return expect(errors[0].path).toBe(missingPath)
        })
      })
    )

    describe('when called with unopened files', () =>
      it('replaces properly', function () {
        const results = []
        waitsForPromise(() =>
          atom.workspace.replace(/items/gi, 'items', [filePath], result => results.push(result))
        )

        return runs(function () {
          expect(results).toHaveLength(1)
          expect(results[0].filePath).toBe(filePath)
          return expect(results[0].replacements).toBe(6)
        })
      })
    )

    return describe('when a buffer is already open', function () {
      it('replaces properly and saves when not modified', function () {
        let editor = null
        const results = []

        waitsForPromise(() => atom.workspace.open('sample.js').then(o => (editor = o)))

        runs(() => expect(editor.isModified()).toBeFalsy())

        waitsForPromise(() =>
          atom.workspace.replace(/items/gi, 'items', [filePath], result => results.push(result))
        )

        return runs(function () {
          expect(results).toHaveLength(1)
          expect(results[0].filePath).toBe(filePath)
          expect(results[0].replacements).toBe(6)

          return expect(editor.isModified()).toBeFalsy()
        })
      })

      it('does not replace when the path is not specified', function () {
        const results = []

        waitsForPromise(() => atom.workspace.open('sample-with-comments.js'))

        waitsForPromise(() =>
          atom.workspace.replace(/items/gi, 'items', [commentFilePath], result => results.push(result))
        )

        return runs(function () {
          expect(results).toHaveLength(1)
          return expect(results[0].filePath).toBe(commentFilePath)
        })
      })

      return it('does NOT save when modified', function () {
        let editor = null
        const results = []

        waitsForPromise(() => atom.workspace.open('sample.js').then(o => (editor = o)))

        runs(function () {
          editor.buffer.setTextInRange([[0, 0], [0, 0]], 'omg')
          return expect(editor.isModified()).toBeTruthy()
        })

        waitsForPromise(() =>
          atom.workspace.replace(/items/gi, 'okthen', [filePath], result => results.push(result))
        )

        return runs(function () {
          expect(results).toHaveLength(1)
          expect(results[0].filePath).toBe(filePath)
          expect(results[0].replacements).toBe(6)

          return expect(editor.isModified()).toBeTruthy()
        })
      })
    })
  })

  describe('::saveActivePaneItem()', function () {
    let editor = null
    beforeEach(() =>
      waitsForPromise(() => atom.workspace.open('sample.js').then(o => (editor = o)))
    )

    return describe('when there is an error', function () {
      it('emits a warning notification when the file cannot be saved', function () {
        let addedSpy
        spyOn(editor, 'save').andCallFake(function () {
          throw new Error("'/some/file' is a directory")
        })

        atom.notifications.onDidAddNotification(addedSpy = jasmine.createSpy())
        atom.workspace.saveActivePaneItem()
        expect(addedSpy).toHaveBeenCalled()
        return expect(addedSpy.mostRecentCall.args[0].getType()).toBe('warning')
      })

      it('emits a warning notification when the directory cannot be written to', function () {
        let addedSpy
        spyOn(editor, 'save').andCallFake(function () {
          throw new Error("ENOTDIR, not a directory '/Some/dir/and-a-file.js'")
        })

        atom.notifications.onDidAddNotification(addedSpy = jasmine.createSpy())
        atom.workspace.saveActivePaneItem()
        expect(addedSpy).toHaveBeenCalled()
        return expect(addedSpy.mostRecentCall.args[0].getType()).toBe('warning')
      })

      it('emits a warning notification when the user does not have permission', function () {
        let addedSpy
        spyOn(editor, 'save').andCallFake(function () {
          const error = new Error("EACCES, permission denied '/Some/dir/and-a-file.js'")
          error.code = 'EACCES'
          error.path = '/Some/dir/and-a-file.js'
          throw error
        })

        atom.notifications.onDidAddNotification(addedSpy = jasmine.createSpy())
        atom.workspace.saveActivePaneItem()
        expect(addedSpy).toHaveBeenCalled()
        return expect(addedSpy.mostRecentCall.args[0].getType()).toBe('warning')
      })

      it('emits a warning notification when the operation is not permitted', () =>
        spyOn(editor, 'save').andCallFake(function () {
          const error = new Error("EPERM, operation not permitted '/Some/dir/and-a-file.js'")
          error.code = 'EPERM'
          error.path = '/Some/dir/and-a-file.js'
          throw error
        })
      )

      it('emits a warning notification when the file is already open by another app', function () {
        let addedSpy
        spyOn(editor, 'save').andCallFake(function () {
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
        return expect(notificaiton.getMessage()).toContain('Unable to save')
      })

      it('emits a warning notification when the file system is read-only', function () {
        let addedSpy
        spyOn(editor, 'save').andCallFake(function () {
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
        return expect(notification.getMessage()).toContain('Unable to save')
      })

      return it('emits a warning notification when the file cannot be saved', function () {
        spyOn(editor, 'save').andCallFake(function () {
          throw new Error('no one knows')
        })

        const save = () => atom.workspace.saveActivePaneItem()
        return expect(save).toThrow()
      })
    })
  })

  describe('::closeActivePaneItemOrEmptyPaneOrWindow', function () {
    beforeEach(function () {
      spyOn(atom, 'close')
      return waitsForPromise(() => atom.workspace.open())
    })

    return it('closes the active pane item, or the active pane if it is empty, or the current window if there is only the empty root pane', function () {
      atom.config.set('core.destroyEmptyPanes', false)

      const pane1 = atom.workspace.getActivePane()
      const pane2 = pane1.splitRight({copyActiveItem: true})

      expect(atom.workspace.getPanes().length).toBe(2)
      expect(pane2.getItems().length).toBe(1)
      atom.workspace.closeActivePaneItemOrEmptyPaneOrWindow()

      expect(atom.workspace.getPanes().length).toBe(2)
      expect(pane2.getItems().length).toBe(0)

      atom.workspace.closeActivePaneItemOrEmptyPaneOrWindow()

      expect(atom.workspace.getPanes().length).toBe(1)
      expect(pane1.getItems().length).toBe(1)

      atom.workspace.closeActivePaneItemOrEmptyPaneOrWindow()
      expect(atom.workspace.getPanes().length).toBe(1)
      expect(pane1.getItems().length).toBe(0)

      atom.workspace.closeActivePaneItemOrEmptyPaneOrWindow()
      expect(atom.workspace.getPanes().length).toBe(1)

      atom.workspace.closeActivePaneItemOrEmptyPaneOrWindow()
      return expect(atom.close).toHaveBeenCalled()
    })
  })

  describe('when the core.allowPendingPaneItems option is falsey', () =>
    it('does not open item with `pending: true` option as pending', function () {
      let pane = null
      atom.config.set('core.allowPendingPaneItems', false)

      waitsForPromise(() =>
        atom.workspace.open('sample.js', {pending: true}).then(() => (pane = atom.workspace.getActivePane()))
      )

      return runs(() => expect(pane.getPendingItem()).toBeFalsy())
    })
  )

  describe('grammar activation', () =>
    it('notifies the workspace of which grammar is used', function () {
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

      return runs(function () {
        // Hooks are triggered when opening new editors
        expect(javascriptGrammarUsed).toHaveBeenCalled()

        // Hooks are triggered when changing existing editors grammars
        atom.workspace.getActiveTextEditor().setGrammar(atom.grammars.grammarForScopeName('source.c'))
        expect(cGrammarUsed).toHaveBeenCalled()

        // Hooks are triggered when editors are added in other ways.
        atom.workspace.getActivePane().splitRight({copyActiveItem: true})
        atom.workspace.getActiveTextEditor().setGrammar(atom.grammars.grammarForScopeName('source.ruby'))
        return expect(rubyGrammarUsed).toHaveBeenCalled()
      })
    })
  )

  describe('.checkoutHeadRevision()', function () {
    let editor = null
    beforeEach(function () {
      atom.config.set('editor.confirmCheckoutHeadRevision', false)

      return waitsForPromise(() => atom.workspace.open('sample-with-comments.js').then(o => (editor = o)))
    })

    it('reverts to the version of its file checked into the project repository', function () {
      editor.setCursorBufferPosition([0, 0])
      editor.insertText('---\n')
      expect(editor.lineTextForBufferRow(0)).toBe('---')

      waitsForPromise(() => atom.workspace.checkoutHeadRevision(editor))

      return runs(() => expect(editor.lineTextForBufferRow(0)).toBe(''))
    })

    return describe("when there's no repository for the editor's file", () =>
      it("doesn't do anything", function () {
        editor = new TextEditor()
        editor.setText('stuff')
        atom.workspace.checkoutHeadRevision(editor)

        return waitsForPromise(() => atom.workspace.checkoutHeadRevision(editor))
      })
    )
  })

  return (escapeStringRegex = str => str.replace(/[|\\{}()[\]^$+*?.]/g, '\\$&'))
})

function __guard__ (value, transform) {
  return (typeof value !== 'undefined' && value !== null) ? transform(value) : undefined
}
