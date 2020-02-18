/*
 * Public: utility function for Conflict components to delete a DisplayMarker.
 */
export function deleteMarkerIn(marker, editor) {
  editor.setTextInBufferRange(marker.getBufferRange(), '');
  marker.destroy();
}
