const path = require('path');
const fs = require('fs');
const { TextEditor, TextBuffer } = require('atom');

const SIZES_IN_KB = [512, 1024, 2048];
const REPEATED_TEXT = fs
  .readFileSync(
    path.join(__dirname, '..', 'spec', 'fixtures', 'sample.js'),
    'utf8'
  )
  .replace(/\n/g, '');
const TEXT = REPEATED_TEXT.repeat(
  Math.ceil((SIZES_IN_KB[SIZES_IN_KB.length - 1] * 1024) / REPEATED_TEXT.length)
);

module.exports = async ({ test }) => {
  const data = [];

  const workspaceElement = atom.workspace.getElement();
  document.body.appendChild(workspaceElement);

  atom.packages.loadPackages();
  await atom.packages.activate();

  console.log(atom.getLoadSettings().resourcePath);

  for (let pane of atom.workspace.getPanes()) {
    pane.destroy();
  }

  for (const sizeInKB of SIZES_IN_KB) {
    const text = TEXT.slice(0, sizeInKB * 1024);
    console.log(text.length / 1024);

    let t0 = window.performance.now();
    const buffer = new TextBuffer({ text });
    const editor = new TextEditor({
      buffer,
      autoHeight: false,
      largeFileMode: true
    });
    atom.grammars.assignLanguageMode(buffer, 'source.js');
    atom.workspace.getActivePane().activateItem(editor);
    let t1 = window.performance.now();

    data.push({
      name: 'Opening a large single-line file',
      x: sizeInKB,
      duration: t1 - t0
    });

    const tickDurations = [];
    for (let i = 0; i < 20; i++) {
      await timeout(50);
      t0 = window.performance.now();
      await timeout(0);
      t1 = window.performance.now();
      tickDurations[i] = t1 - t0;
    }

    data.push({
      name:
        'Max time event loop was blocked after opening a large single-line file',
      x: sizeInKB,
      duration: Math.max(...tickDurations)
    });

    t0 = window.performance.now();
    editor.setCursorScreenPosition(
      editor.element.screenPositionForPixelPosition({
        top: 100,
        left: 30
      })
    );
    t1 = window.performance.now();

    data.push({
      name: 'Clicking the editor after opening a large single-line file',
      x: sizeInKB,
      duration: t1 - t0
    });

    t0 = window.performance.now();
    editor.element.setScrollTop(editor.element.getScrollTop() + 100);
    t1 = window.performance.now();

    data.push({
      name: 'Scrolling down after opening a large single-line file',
      x: sizeInKB,
      duration: t1 - t0
    });

    editor.destroy();
    buffer.destroy();
    await timeout(10000);
  }

  workspaceElement.remove();

  return data;
};

function timeout(duration) {
  return new Promise(resolve => setTimeout(resolve, duration));
}
