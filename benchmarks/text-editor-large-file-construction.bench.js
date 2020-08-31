const { TextEditor, TextBuffer } = require('atom');

const MIN_SIZE_IN_KB = 0 * 1024;
const MAX_SIZE_IN_KB = 10 * 1024;
const SIZE_STEP_IN_KB = 1024;
const LINE_TEXT = 'Lorem ipsum dolor sit amet\n';
const TEXT = LINE_TEXT.repeat(
  Math.ceil((MAX_SIZE_IN_KB * 1024) / LINE_TEXT.length)
);

module.exports = async ({ test }) => {
  const data = [];

  document.body.appendChild(atom.workspace.getElement());

  atom.packages.loadPackages();
  await atom.packages.activate();

  for (let pane of atom.workspace.getPanes()) {
    pane.destroy();
  }

  for (
    let sizeInKB = MIN_SIZE_IN_KB;
    sizeInKB < MAX_SIZE_IN_KB;
    sizeInKB += SIZE_STEP_IN_KB
  ) {
    const text = TEXT.slice(0, sizeInKB * 1024);
    console.log(text.length / 1024);

    let t0 = window.performance.now();
    const buffer = new TextBuffer({ text });
    const editor = new TextEditor({
      buffer,
      autoHeight: false,
      largeFileMode: true
    });
    atom.grammars.autoAssignLanguageMode(buffer);
    atom.workspace.getActivePane().activateItem(editor);
    let t1 = window.performance.now();

    data.push({
      name: 'Opening a large file',
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
      name: 'Max time event loop was blocked after opening a large file',
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
      name: 'Clicking the editor after opening a large file',
      x: sizeInKB,
      duration: t1 - t0
    });

    t0 = window.performance.now();
    editor.element.setScrollTop(editor.element.getScrollTop() + 100);
    t1 = window.performance.now();

    data.push({
      name: 'Scrolling down after opening a large file',
      x: sizeInKB,
      duration: t1 - t0
    });

    editor.destroy();
    buffer.destroy();
    await timeout(10000);
  }

  atom.workspace.getElement().remove();

  return data;
};

function timeout(duration) {
  return new Promise(resolve => setTimeout(resolve, duration));
}
