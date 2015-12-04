'use strict'

module.exports = function (model) {
  if (model.worksWithViewProvider2) {
    let element = document.createElement('div')
    element.dataset['createdBy'] = 'view-provider-2'
    return element
  }
}
