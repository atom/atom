import {deleteMarkerIn} from './marker-tools';

export default class Banner {
  constructor(editor, marker, description, originalText) {
    this.editor = editor;
    this.marker = marker;
    this.description = description;
    this.originalText = originalText;
  }

  getMarker() {
    return this.marker;
  }

  getRange() {
    return this.marker.getBufferRange();
  }

  isModified() {
    const chomp = line => line.replace(/\r?\n$/, '');

    const text = this.editor.getTextInBufferRange(this.marker.getBufferRange());
    return chomp(text) !== chomp(this.originalText);
  }

  revert() {
    const range = this.getMarker().getBufferRange();
    this.editor.setTextInBufferRange(range, this.originalText);
    this.getMarker().setBufferRange(range);
  }

  delete() {
    deleteMarkerIn(this.getMarker(), this.editor);
  }
}
