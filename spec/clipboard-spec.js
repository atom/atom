describe('Clipboard', () => {
  describe('write(text, metadata) and read()', () => {
    it('writes and reads text to/from the native clipboard', () => {
      expect(atom.clipboard.read()).toBe('initial clipboard content');
      atom.clipboard.write('next');
      expect(atom.clipboard.read()).toBe('next');
    });

    it('returns metadata if the item on the native clipboard matches the last written item', () => {
      atom.clipboard.write('next', { meta: 'data' });
      expect(atom.clipboard.read()).toBe('next');
      expect(atom.clipboard.readWithMetadata().text).toBe('next');
      expect(atom.clipboard.readWithMetadata().metadata).toEqual({
        meta: 'data'
      });
    });
  });

  describe('line endings', () => {
    let originalPlatform = process.platform;

    const eols = new Map([
      ['win32', '\r\n'],
      ['darwin', '\n'],
      ['linux', '\n']
    ]);
    for (let [platform, eol] of eols) {
      it(`converts line endings to the OS's native line endings on ${platform}`, () => {
        Object.defineProperty(process, 'platform', { value: platform });

        atom.clipboard.write('next\ndone\r\n\n', { meta: 'data' });
        expect(atom.clipboard.readWithMetadata()).toEqual({
          text: `next${eol}done${eol}${eol}`,
          metadata: { meta: 'data' }
        });

        Object.defineProperty(process, 'platform', { value: originalPlatform });
      });
    }
  });
});
