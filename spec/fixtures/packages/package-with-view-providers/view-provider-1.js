'use strict'

module.exports = function (model) {
  if (model.worksWithViewProvider1) {
    let element = document.createElement('div')
    element.dataset['createdBy'] = 'view-provider-1'
    return element
  }
}
