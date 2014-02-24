temp = require 'temp'
Git = require '../src/git'
fs = require 'fs-plus'
path = require 'path'
Task = require '../src/task'

describe "Git", ->
  repo = null

  beforeEach ->
    gitPath = path.join(temp.dir, '.git')
    fs.removeSync(gitPath) if fs.isDirectorySync(gitPath)

  afterEach ->
    repo.destroy() if repo?.repo?

  describe "@open(path)", ->
    it "returns null when no repository is found", ->
      expect(Git.open(path.join(temp.dir, 'nogit.txt'))).toBeNull()

  describe "new Git(path)", ->
    it "throws an exception when no repository is found", ->
      expect(-> new Git(path.join(temp.dir, 'nogit.txt'))).toThrow()

  describe ".getPath()", ->
    it "returns the repository path for a .git directory path", ->
      repo = new Git(path.join(__dirname, 'fixtures', 'git', 'master.git', 'HEAD'))
      expect(repo.getPath()).toBe path.join(__dirname, 'fixtures', 'git', 'master.git')

    it "returns the repository path for a repository path", ->
      repo = new Git(path.join(__dirname, 'fixtures', 'git', 'master.git'))
      expect(repo.getPath()).toBe path.join(__dirname, 'fixtures', 'git', 'master.git')

  describe ".isPathIgnored(path)", ->
    it "returns true for an ignored path", ->
      repo = new Git(path.join(__dirname, 'fixtures', 'git', 'ignore.git'))
      expect(repo.isPathIgnored('a.txt')).toBeTruthy()

    it "returns false for a non-ignored path", ->
      repo = new Git(path.join(__dirname, 'fixtures', 'git', 'ignore.git'))
      expect(repo.isPathIgnored('b.txt')).toBeFalsy()

  describe ".isPathModified(path)", ->
    [repo, filePath, newPath, originalPathText] = []

    beforeEach ->
      repo = new Git(path.join(__dirname, 'fixtures', 'git', 'working-dir'))
      filePath = require.resolve('./fixtures/git/working-dir/file.txt')
      newPath = path.join(__dirname, 'fixtures', 'git', 'working-dir', 'new-path.txt')
      originalPathText = fs.readFileSync(filePath, 'utf8')

    afterEach ->
      fs.writeFileSync(filePath, originalPathText)
      fs.removeSync(newPath) if fs.existsSync(newPath)

    describe "when the path is unstaged", ->
      it "returns false if the path has not been modified", ->
        expect(repo.isPathModified(filePath)).toBeFalsy()

      it "returns true if the path is modified", ->
        fs.writeFileSync(filePath, "change")
        expect(repo.isPathModified(filePath)).toBeTruthy()

      it "returns true if the path is deleted", ->
        fs.removeSync(filePath)
        expect(repo.isPathModified(filePath)).toBeTruthy()

      it "returns false if the path is new", ->
        expect(repo.isPathModified(newPath)).toBeFalsy()

  describe ".isPathNew(path)", ->
    [filePath, newPath] = []

    beforeEach ->
      repo = new Git(path.join(__dirname, 'fixtures', 'git', 'working-dir'))
      filePath = require.resolve('./fixtures/git/working-dir/file.txt')
      newPath = path.join(__dirname, 'fixtures', 'git', 'working-dir', 'new-path.txt')
      fs.writeFileSync(newPath, "i'm new here")

    afterEach ->
      fs.removeSync(newPath) if fs.existsSync(newPath)

    describe "when the path is unstaged", ->
      it "returns true if the path is new", ->
        expect(repo.isPathNew(newPath)).toBeTruthy()

      it "returns false if the path isn't new", ->
        expect(repo.isPathNew(filePath)).toBeFalsy()

  describe ".checkoutHead(path)", ->
    [path1, path2, originalPath1Text, originalPath2Text] = []

    beforeEach ->
      repo = new Git(path.join(__dirname, 'fixtures', 'git', 'working-dir'))
      path1 = require.resolve('./fixtures/git/working-dir/file.txt')
      originalPath1Text = fs.readFileSync(path1, 'utf8')
      path2 = require.resolve('./fixtures/git/working-dir/other.txt')
      originalPath2Text = fs.readFileSync(path2, 'utf8')

    afterEach ->
      fs.writeFileSync(path1, originalPath1Text)
      fs.writeFileSync(path2, originalPath2Text)

    it "no longer reports a path as modified after checkout", ->
      expect(repo.isPathModified(path1)).toBeFalsy()
      fs.writeFileSync(path1, '')
      expect(repo.isPathModified(path1)).toBeTruthy()
      expect(repo.checkoutHead(path1)).toBeTruthy()
      expect(repo.isPathModified(path1)).toBeFalsy()

    it "restores the contents of the path to the original text", ->
      fs.writeFileSync(path1, '')
      expect(repo.checkoutHead(path1)).toBeTruthy()
      expect(fs.readFileSync(path1, 'utf8')).toBe(originalPath1Text)

    it "only restores the path specified", ->
      fs.writeFileSync(path2, 'path 2 is edited')
      expect(repo.isPathModified(path2)).toBeTruthy()
      expect(repo.checkoutHead(path1)).toBeTruthy()
      expect(fs.readFileSync(path2, 'utf8')).toBe('path 2 is edited')
      expect(repo.isPathModified(path2)).toBeTruthy()

    it "fires a status-changed event if the checkout completes successfully", ->
      fs.writeFileSync(path1, '')
      repo.getPathStatus(path1)
      statusHandler = jasmine.createSpy('statusHandler')
      repo.on 'status-changed', statusHandler
      repo.checkoutHead(path1)
      expect(statusHandler.callCount).toBe 1
      expect(statusHandler.argsForCall[0][0..1]).toEqual [path1, 0]

      repo.checkoutHead(path1)
      expect(statusHandler.callCount).toBe 1

  describe ".destroy()", ->
    it "throws an exception when any method is called after it is called", ->
      repo = new Git(require.resolve('./fixtures/git/master.git/HEAD'))
      repo.destroy()
      expect(-> repo.getShortHead()).toThrow()

  describe ".getDiffStats(path)", ->
    [filePath, originalPathText] = []

    beforeEach ->
      repo = new Git(path.join(__dirname, 'fixtures', 'git', 'working-dir'))
      filePath = require.resolve('./fixtures/git/working-dir/file.txt')
      originalPathText = fs.readFileSync(filePath, 'utf8')

    afterEach ->
      fs.writeFileSync(filePath, originalPathText)

    it "returns the number of lines added and deleted", ->
      expect(repo.getDiffStats(filePath)).toEqual {added: 0, deleted: 0}
      fs.writeFileSync(filePath, "#{originalPathText} edited line")
      expect(repo.getDiffStats(filePath)).toEqual {added: 1, deleted: 1}

  describe ".getPathStatus(path)", ->
    [filePath, originalPathText] = []

    beforeEach ->
      repo = new Git(path.join(__dirname, 'fixtures', 'git', 'working-dir'))
      filePath = require.resolve('./fixtures/git/working-dir/file.txt')
      originalPathText = fs.readFileSync(filePath, 'utf8')

    afterEach ->
      fs.writeFileSync(filePath, originalPathText)

    it "trigger a status-changed event when the new status differs from the last cached one", ->
      statusHandler = jasmine.createSpy("statusHandler")
      repo.on 'status-changed', statusHandler
      fs.writeFileSync(filePath, '')
      status = repo.getPathStatus(filePath)
      expect(statusHandler.callCount).toBe 1
      expect(statusHandler.argsForCall[0][0..1]).toEqual [filePath, status]

      fs.writeFileSync(filePath, 'abc')
      status = repo.getPathStatus(filePath)
      expect(statusHandler.callCount).toBe 1

  describe ".refreshStatus()", ->
    [newPath, modifiedPath, cleanPath, originalModifiedPathText] = []

    beforeEach ->
      repo = new Git(path.join(__dirname, 'fixtures', 'git', 'working-dir'))
      modifiedPath = atom.project.resolve('git/working-dir/file.txt')
      originalModifiedPathText = fs.readFileSync(modifiedPath, 'utf8')
      newPath = atom.project.resolve('git/working-dir/untracked.txt')
      cleanPath = atom.project.resolve('git/working-dir/other.txt')
      fs.writeFileSync(newPath, '')
      newPath = fs.absolute newPath  # specs could be running under symbol path.

    afterEach ->
      fs.writeFileSync(modifiedPath, originalModifiedPathText)
      fs.removeSync(newPath) if fs.existsSync(newPath)

    it "returns status information for all new and modified files", ->
      fs.writeFileSync(modifiedPath, 'making this path modified')
      statusHandler = jasmine.createSpy('statusHandler')
      repo.on 'statuses-changed', statusHandler
      repo.refreshStatus()

      waitsFor ->
        statusHandler.callCount > 0

      runs ->
        statuses = repo.statuses
        expect(statuses[cleanPath]).toBeUndefined()
        expect(repo.isStatusNew(statuses[newPath])).toBeTruthy()
        expect(repo.isStatusModified(statuses[modifiedPath])).toBeTruthy()

  describe "buffer events", ->
    [originalContent, editor] = []

    beforeEach ->
      editor = atom.project.openSync('sample.js')
      originalContent = editor.getText()

    afterEach ->
      fs.writeFileSync(editor.getPath(), originalContent)

    it "emits a status-changed event when a buffer is saved", ->
      editor.insertNewline()

      statusHandler = jasmine.createSpy('statusHandler')
      atom.project.getRepo().on 'status-changed', statusHandler
      editor.save()
      expect(statusHandler.callCount).toBe 1
      expect(statusHandler).toHaveBeenCalledWith editor.getPath(), 256

    it "emits a status-changed event when a buffer is reloaded", ->
      fs.writeFileSync(editor.getPath(), 'changed')

      statusHandler = jasmine.createSpy('statusHandler')
      atom.project.getRepo().on 'status-changed', statusHandler
      editor.getBuffer().reload()
      expect(statusHandler.callCount).toBe 1
      expect(statusHandler).toHaveBeenCalledWith editor.getPath(), 256
      editor.getBuffer().reload()
      expect(statusHandler.callCount).toBe 1

    it "emits a status-changed event when a buffer's path changes", ->
      fs.writeFileSync(editor.getPath(), 'changed')

      statusHandler = jasmine.createSpy('statusHandler')
      atom.project.getRepo().on 'status-changed', statusHandler
      editor.getBuffer().emit 'path-changed'
      expect(statusHandler.callCount).toBe 1
      expect(statusHandler).toHaveBeenCalledWith editor.getPath(), 256
      editor.getBuffer().emit 'path-changed'
      expect(statusHandler.callCount).toBe 1

  describe "when a project is deserialized", ->
    [originalContent, buffer, project2] = []

    afterEach ->
      fs.writeFileSync(buffer.getPath(), originalContent)
      project2?.destroy()

    it "subscribes to all the serialized buffers in the project", ->
      atom.project.openSync('sample.js')
      project2 = atom.project.testSerialization()
      buffer = project2.getBuffers()[0]

      waitsFor ->
        buffer.loaded

      runs ->
        originalContent = buffer.getText()
        buffer.append('changes')

        statusHandler = jasmine.createSpy('statusHandler')
        project2.getRepo().on 'status-changed', statusHandler
        buffer.save()
        expect(statusHandler.callCount).toBe 1
        expect(statusHandler).toHaveBeenCalledWith buffer.getPath(), 256
