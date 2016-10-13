/** @babel */

import fs from 'fs'
import temp from 'temp'
import {TextEditor, TextBuffer} from 'atom'

export default function () {
  const data = []
  const maxLineCount = 10000
  const step = 500
  const lineText = 'Lorem ipsum dolor sit amet\n'
  const sampleText = lineText.repeat(maxLineCount)
  for (let lineCount = 0; lineCount <= maxLineCount; lineCount += step) {
    const text = sampleText.slice(0, lineText.length * lineCount)
    const buffer = new TextBuffer(text)
    const t0 = window.performance.now()
    const editor = new TextEditor({buffer, largeFileMode: true})
    document.body.appendChild(editor.element)
    const t1 = window.performance.now()
    data.push({name: 'Opening and rendering a TextEditor', x: lineCount, duration: t1 - t0})
    editor.element.remove()
    editor.destroy()
  }
  return data
}
