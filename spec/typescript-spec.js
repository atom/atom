describe('TypeScript transpiler support', function() {
  describe('when there is a .ts file', () =>
    it('transpiles it using typescript', function() {
      const transpiled = require('./fixtures/typescript/valid.ts');
      expect(transpiled(3)).toBe(4);
    }));

  describe('when the .ts file is invalid', () =>
    it('does not transpile', () =>
      expect(() => require('./fixtures/typescript/invalid.ts')).toThrow()));
});
