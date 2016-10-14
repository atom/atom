/** @babel */

import fs from 'fs'
import temp from 'temp'
import {TextEditor, TextBuffer} from 'atom'

export default function ({test}) {
  const text = 'Lorem ipsum dolor sit amet\n'.repeat(test ? 10 : 500000)
  const t0 = window.performance.now()
  const buffer = new TextBuffer(text)
  const editor = new TextEditor({buffer, largeFileMode: true})
  editor.element.style.height = "600px"
  document.body.appendChild(editor.element)
  const t1 = window.performance.now()
  editor.element.remove()
  editor.destroy()

  return [{name: 'Opening and rendering a large file', duration: t1 - t0}]
}
