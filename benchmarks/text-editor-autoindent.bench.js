const {TextEditor, TextBuffer} = require('atom')
module.exports = async ({test}) => {
  const data = []
  const workspaceElement = atom.workspace.getElement()
  document.body.appendChild(workspaceElement)
  atom.packages.loadPackages()
  await atom.packages.activate()
  console.log(atom.getLoadSettings().resourcePath);
  for (let pane of atom.workspace.getPanes()) {
    pane.destroy()
  }
  const stepSize = 1000
  const minLines = 10
  const maxLines = 10 * stepSize + minLines
  const commentBodyLine = "Lorem ipsum dolor sit amet\n"
  const commentBody = commentBodyLine.repeat(maxLines)
  const commentStart = "/*\n"
  const commentEnd = "*/\n"
  const startContext = "switch (x) { case 0: ".repeat(12) + "\n"
  const endContext = "}\n" + "}".repeat(11)
  for (let numLines = maxLines; numLines >= minLines; numLines -= stepSize) {
    let testCommentBody = commentBody.slice(0, numLines * commentBodyLine.length)
    let comment = commentStart + testCommentBody + commentEnd
    let text = startContext + comment + endContext
    const buffer = new TextBuffer({text})
    const editor = new TextEditor({buffer, autoHeight: false, largeFileMode: true})
    atom.grammars.assignLanguageMode(buffer, "source.js")
    atom.workspace.getActivePane().activateItem(editor)
    let indentRow = editor.getLineCount() - 2
    editor.setSelectedBufferRange([[indentRow, 0], [indentRow, Infinity]])
    let t0 = window.performance.now()
    editor.autoIndentSelectedRows()
    let t1 = window.performance.now()
    data.push({
      name: 'Auto indenting with a lot of commented lines above',
      x: numLines,
      duration: t1 - t0
    })
    editor.destroy()
    buffer.destroy()
    await timeout(2000)
  }
  workspaceElement.remove()
  return data
}
function timeout (duration) {
  return new Promise((resolve) => setTimeout(resolve, duration))
}
