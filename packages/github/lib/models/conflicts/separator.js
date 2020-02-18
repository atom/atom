import {deleteMarkerIn} from './marker-tools';

export default class Separator {
  constructor(editor, marker) {
    this.editor = editor;
    this.marker = marker;
  }

  getMarker() {
    return this.marker;
  }

  delete() {
    deleteMarkerIn(this.getMarker(), this.editor);
  }

  isModified() {
    const currentText = this.editor.getTextInBufferRange(this.getMarker().getBufferRange());
    return !/^=======\r?\n?$/.test(currentText);
  }
}
