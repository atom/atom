describe('spec-helper', () => {
  describe('jasmine.any', () => {
    it('equals uses jasmine.any', () => {
      const func = () => {};
      expect(func).toEqual(jasmine.any(Function));
    });
  });
});
