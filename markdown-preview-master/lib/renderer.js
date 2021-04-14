const { TextEditor } = require('atom')
const path = require('path')
const createDOMPurify = require('dompurify')
const emoji = require('emoji-images')
const fs = require('fs-plus')
let marked = null // Defer until used
let renderer = null
let cheerio = null
let yamlFrontMatter = null

const { scopeForFenceName } = require('./extension-helper')
const { resourcePath } = atom.getLoadSettings()
const packagePath = path.dirname(__dirname)

const emojiFolder = path.join(
  path.dirname(require.resolve('emoji-images')),
  'pngs'
)

exports.toDOMFragment = async function (text, filePath, grammar, callback) {
  if (text == null) {
    text = ''
  }

  const domFragment = render(text, filePath)

  await highlightCodeBlocks(domFragment, grammar, makeAtomEditorNonInteractive)

  return domFragment
}

exports.toHTML = async function (text, filePath, grammar) {
  if (text == null) {
    text = ''
  }

  const domFragment = render(text, filePath)
  const div = document.createElement('div')

  div.appendChild(domFragment)
  document.body.appendChild(div)

  await highlightCodeBlocks(div, grammar, convertAtomEditorToStandardElement)

  const result = div.innerHTML
  div.remove()

  return result
}

var render = function (text, filePath) {
  if (marked == null || yamlFrontMatter == null || cheerio == null) {
    marked = require('marked')
    yamlFrontMatter = require('yaml-front-matter')
    cheerio = require('cheerio')

    renderer = new marked.Renderer()
    renderer.listitem = function (text, isTask) {
      const listAttributes = isTask ? ' class="task-list-item"' : ''

      return `<li ${listAttributes}>${text}</li>\n`
    }
  }

  marked.setOptions({
    sanitize: false,
    breaks: atom.config.get('markdown-preview.breakOnSingleNewline'),
    renderer
  })

  const { __content, ...vars } = yamlFrontMatter.loadFront(text)

  let html = marked(renderYamlTable(vars) + __content)

  // emoji-images is too aggressive, so replace images in monospace tags with the actual emoji text.
  const $ = cheerio.load(emoji(html, emojiFolder, 20))
  $('pre img').each((index, element) =>
    $(element).replaceWith($(element).attr('title'))
  )
  $('code img').each((index, element) =>
    $(element).replaceWith($(element).attr('title'))
  )

  html = $.html()

  html = createDOMPurify().sanitize(html, {
    ALLOW_UNKNOWN_PROTOCOLS: atom.config.get(
      'markdown-preview.allowUnsafeProtocols'
    )
  })

  const template = document.createElement('template')
  template.innerHTML = html.trim()
  const fragment = template.content.cloneNode(true)

  resolveImagePaths(fragment, filePath)

  return fragment
}

function renderYamlTable (variables) {
  const entries = Object.entries(variables)

  if (!entries.length) {
    return ''
  }

  const markdownRows = [
    entries.map(entry => entry[0]),
    entries.map(entry => '--'),
    entries.map(entry => entry[1])
  ]

  return (
    markdownRows.map(row => '| ' + row.join(' | ') + ' |').join('\n') + '\n'
  )
}

var resolveImagePaths = function (element, filePath) {
  const [rootDirectory] = atom.project.relativizePath(filePath)

  const result = []
  for (const img of element.querySelectorAll('img')) {
    // We use the raw attribute instead of the .src property because the value
    // of the property seems to be transformed in some cases.
    let src

    if ((src = img.getAttribute('src'))) {
      if (src.match(/^(https?|atom):\/\//)) {
        continue
      }
      if (src.startsWith(process.resourcesPath)) {
        continue
      }
      if (src.startsWith(resourcePath)) {
        continue
      }
      if (src.startsWith(packagePath)) {
        continue
      }

      if (src[0] === '/') {
        if (!fs.isFileSync(src)) {
          if (rootDirectory) {
            result.push((img.src = path.join(rootDirectory, src.substring(1))))
          } else {
            result.push(undefined)
          }
        } else {
          result.push(undefined)
        }
      } else {
        result.push((img.src = path.resolve(path.dirname(filePath), src)))
      }
    } else {
      result.push(undefined)
    }
  }

  return result
}

var highlightCodeBlocks = function (domFragment, grammar, editorCallback) {
  let defaultLanguage, fontFamily
  if (
    (grammar != null ? grammar.scopeName : undefined) === 'source.litcoffee'
  ) {
    defaultLanguage = 'coffee'
  } else {
    defaultLanguage = 'text'
  }

  if ((fontFamily = atom.config.get('editor.fontFamily'))) {
    for (const codeElement of domFragment.querySelectorAll('code')) {
      codeElement.style.fontFamily = fontFamily
    }
  }

  const promises = []
  for (const preElement of domFragment.querySelectorAll('pre')) {
    const codeBlock =
      preElement.firstElementChild != null
        ? preElement.firstElementChild
        : preElement
    const className = codeBlock.getAttribute('class')
    const fenceName =
      className != null ? className.replace(/^language-/, '') : defaultLanguage

    const editor = new TextEditor({
      readonly: true,
      keyboardInputEnabled: false
    })
    const editorElement = editor.getElement()

    preElement.classList.add('editor-colors', `lang-${fenceName}`)
    editorElement.setUpdatedSynchronously(true)
    preElement.innerHTML = ''
    preElement.parentNode.insertBefore(editorElement, preElement)
    editor.setText(codeBlock.textContent.replace(/\r?\n$/, ''))
    atom.grammars.assignLanguageMode(editor, scopeForFenceName(fenceName))
    editor.setVisible(true)

    promises.push(editorCallback(editorElement, preElement))
  }
  return Promise.all(promises)
}

var makeAtomEditorNonInteractive = function (editorElement, preElement) {
  preElement.remove()
  editorElement.setAttributeNode(document.createAttribute('gutter-hidden')) // Hide gutter
  editorElement.removeAttribute('tabindex') // Make read-only

  // Remove line decorations from code blocks.
  for (const cursorLineDecoration of editorElement.getModel()
    .cursorLineDecorations) {
    cursorLineDecoration.destroy()
  }
}

var convertAtomEditorToStandardElement = (editorElement, preElement) => {
  return new Promise(function (resolve) {
    const editor = editorElement.getModel()
    const done = () =>
      editor.component.getNextUpdatePromise().then(function () {
        for (const line of editorElement.querySelectorAll(
          '.line:not(.dummy)'
        )) {
          const line2 = document.createElement('div')
          line2.className = 'line'
          line2.innerHTML = line.firstChild.innerHTML
          preElement.appendChild(line2)
        }
        editorElement.remove()
        resolve()
      })
    const languageMode = editor.getBuffer().getLanguageMode()
    if (languageMode.fullyTokenized || languageMode.tree) {
      done()
    } else {
      editor.onDidTokenize(done)
    }
  })
}
