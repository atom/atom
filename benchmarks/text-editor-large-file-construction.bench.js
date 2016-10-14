/** @babel */

import {TextEditor, TextBuffer} from 'atom'

const MAX_SIZE_IN_KB = 10 * 1024
const SIZE_STEP_IN_KB = 1024
const LINE_TEXT = 'Lorem ipsum dolor sit amet\n'
const CLICK_COUNT = 2
const TEXT = LINE_TEXT.repeat(Math.ceil(MAX_SIZE_IN_KB * 1024 / LINE_TEXT.length))

export default async function ({test}) {
  const data = []

  for (let sizeInKB = 0; sizeInKB < MAX_SIZE_IN_KB; sizeInKB += SIZE_STEP_IN_KB) {
    const text = TEXT.slice(0, sizeInKB * 1024)
    console.log(text.length / 1024)

    const t0 = window.performance.now()
    const buffer = new TextBuffer(text)
    const editor = new TextEditor({buffer, largeFileMode: true})
    editor.element.style.height = "600px"
    document.body.appendChild(editor.element)
    const t1 = window.performance.now()

    data.push({
      name: 'Opening and rendering a large file',
      x: sizeInKB,
      duration: t1 - t0
    })

    for (let i = 0; i < CLICK_COUNT; i++) {
      const t2 = window.performance.now()
      editor.setCursorScreenPosition(
        editor.element.screenPositionForPixelPosition({
          top: i * 20,
          left: 0
        })
      )
      const t3 = window.performance.now()

      data.push({
        name: 'Clicking somewhere onscreen after opening a large file',
        x: sizeInKB,
        duration: t3 - t2
      })

      await timeout(100)
    }

    editor.element.remove()
    editor.destroy()
    buffer.destroy()
    await timeout(5000)
  }

  return data
}

function timeout (duration) {
  return new Promise((resolve) => setTimeout(resolve, duration))
}
