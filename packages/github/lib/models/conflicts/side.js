import {deleteMarkerIn} from './marker-tools';

export default class Side {
  constructor(editor, marker, blockMarker, source, position, banner, originalText) {
    this.editor = editor;
    this.marker = marker;
    this.blockMarker = blockMarker;
    this.source = source;
    this.position = position;
    this.banner = banner;
    this.originalText = originalText;
  }

  getMarker() {
    return this.marker;
  }

  getBannerMarker() {
    return this.banner.getMarker();
  }

  getSource() {
    return this.source;
  }

  getBlockMarker() {
    return this.blockMarker;
  }

  getBlockPosition() {
    return this.position.when({
      top: () => 'before',
      middle: () => 'before',
      bottom: () => 'after',
    });
  }

  getLineCSSClass() {
    if (this.isModified() || this.isBannerModified()) {
      return 'github-ConflictModified';
    } else {
      return this.source.getCSSClass();
    }
  }

  getBannerCSSClass() {
    if (this.isModified() || this.isBannerModified()) {
      return 'github-ConflictModifiedBanner';
    } else {
      return this.source.getBannerCSSClass();
    }
  }

  getBlockCSSClasses() {
    const cxs = ['github-ConflictBlock'];
    cxs.push(this.source.getBlockCSSClass());
    cxs.push(this.position.getBlockCSSClass());
    if (this.isModified() || this.isBannerModified()) {
      cxs.push('github-ConflictModifiedBlock');
    }
    return cxs.join(' ');
  }

  getPosition() {
    return this.position;
  }

  getRange() {
    const bannerRange = this.banner.getRange();
    const bodyRange = this.marker.getBufferRange();
    return bannerRange.union(bodyRange);
  }

  includesPoint(point) {
    return this.getRange().containsPoint(point);
  }

  getText() {
    return this.editor.getTextInBufferRange(this.getMarker().getBufferRange());
  }

  isBannerModified() {
    return this.banner.isModified();
  }

  isModified() {
    return this.getText() !== this.originalText;
  }

  isEmpty() {
    return this.marker.getBufferRange().isEmpty();
  }

  revertBanner() {
    this.banner.revert();
  }

  revert() {
    const range = this.getMarker().getBufferRange();
    this.editor.setTextInBufferRange(range, this.originalText);
    this.getMarker().setBufferRange(range);
  }

  deleteBanner() {
    this.banner.delete();
  }

  delete() {
    deleteMarkerIn(this.getMarker(), this.editor);
  }

  appendText(text) {
    const insertionPoint = this.getMarker().getBufferRange().end;
    return this.editor.setTextInBufferRange([insertionPoint, insertionPoint], text);
  }
}
