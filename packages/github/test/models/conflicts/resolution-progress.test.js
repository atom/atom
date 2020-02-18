import ResolutionProgress from '../../../lib/models/conflicts/resolution-progress';

describe('ResolutionProgress', function() {
  it('reports undefined for any path that has not reported progress yet', function() {
    const progress = new ResolutionProgress();
    assert.isUndefined(progress.getRemaining('path/to/file.txt'));
  });

  it('accepts reports of unresolved conflict counts', function() {
    const progress = new ResolutionProgress();
    progress.reportMarkerCount('path/to/file.txt', 3);

    assert.equal(progress.getRemaining('path/to/file.txt'), 3);
  });

  describe('onDidUpdate', function() {
    let progress, didUpdateSpy;

    beforeEach(function() {
      progress = new ResolutionProgress();
      progress.reportMarkerCount('path/file0.txt', 4);

      didUpdateSpy = sinon.spy();
      progress.onDidUpdate(didUpdateSpy);
    });

    it('triggers an event when the marker count is updated', function() {
      progress.reportMarkerCount('path/file1.txt', 7);
      assert.isTrue(didUpdateSpy.called);
    });

    it('triggers no events when the marker count is unchanged', function() {
      progress.reportMarkerCount('path/file0.txt', 4);
      assert.isFalse(didUpdateSpy.called);
    });
  });
});
