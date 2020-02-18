import {Emitter} from 'event-kit';

export default class ResolutionProgress {
  constructor() {
    this.emitter = new Emitter();
    this.markerCountByPath = new Map();
  }

  didUpdate() {
    this.emitter.emit('did-update');
  }

  onDidUpdate(cb) {
    return this.emitter.on('did-update', cb);
  }

  reportMarkerCount(path, count) {
    const previous = this.markerCountByPath.get(path);
    this.markerCountByPath.set(path, count);
    if (count !== previous) {
      this.didUpdate();
    }
  }

  getRemaining(path) {
    return this.markerCountByPath.get(path);
  }

  isEmpty() {
    return this.markerCountByPath.size === 0;
  }
}
