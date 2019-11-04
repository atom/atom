function selectElement(el) {
    const range = atom.document.createRange();
    range.selectNodeContents(el);
    const sel = window.getSelection();
    sel.removeAllRanges();
    sel.addRange(range);
}

describe('Spec suite window', () => {
  it('CMD + C should copy selected text', async () => {
      atom.clipboard.write('lorem ipsum');

      const element = atom.document.querySelectorAll('.symbol-header')[2];
      selectElement(element);

      expect(atom.clipboard.read()).toBe('lorem ipsum');

      //  simulate ctrl+c
      atom.document.dispatchEvent(new KeyboardEvent('keydown', { keyCode: 67, ctrlKey: true }));

      let copiedText = atom.clipboard.read().toLowerCase().split(' ');
      //  eliminate the 'Spec' attached to the name
      copiedText.pop();
      copiedText = copiedText.join(' ');

      const projectPath = atom.project.getPaths()[0];

      expect(projectPath).toContain(copiedText);
  });
});
