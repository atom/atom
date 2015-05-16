ipc = require 'ipc'
path = require 'path'
temp = require('temp').track()

describe "WorkspaceElement", ->
  workspaceElement = null

  beforeEach ->
    workspaceElement = atom.views.getView(atom.workspace)

  describe "the 'window:run-package-specs' command", ->
    it "runs the package specs for the active item's project path, or the first project path", ->
      spyOn(ipc, 'send')

      # No project paths. Don't try to run specs.
      atom.commands.dispatch(workspaceElement, "window:run-package-specs")
      expect(ipc.send).not.toHaveBeenCalledWith("run-package-specs")

      projectPaths = [temp.mkdirSync("dir1-"), temp.mkdirSync("dir2-")]
      atom.project.setPaths(projectPaths)

      # No active item. Use first project directory.
      atom.commands.dispatch(workspaceElement, "window:run-package-specs")
      expect(ipc.send).toHaveBeenCalledWith("run-package-specs", path.join(projectPaths[0], "spec"))
      ipc.send.reset()

      # Active item doesn't implement ::getPath(). Use first project directory.
      item = document.createElement("div")
      atom.workspace.getActivePane().activateItem(item)
      atom.commands.dispatch(workspaceElement, "window:run-package-specs")
      expect(ipc.send).toHaveBeenCalledWith("run-package-specs", path.join(projectPaths[0], "spec"))
      ipc.send.reset()

      # Active item has no path. Use first project directory.
      item.getPath = -> null
      atom.commands.dispatch(workspaceElement, "window:run-package-specs")
      expect(ipc.send).toHaveBeenCalledWith("run-package-specs", path.join(projectPaths[0], "spec"))
      ipc.send.reset()

      # Active item has path. Use project path for item path.
      item.getPath = -> path.join(projectPaths[1], "a-file.txt")
      atom.commands.dispatch(workspaceElement, "window:run-package-specs")
      expect(ipc.send).toHaveBeenCalledWith("run-package-specs", path.join(projectPaths[1], "spec"))
      ipc.send.reset()
