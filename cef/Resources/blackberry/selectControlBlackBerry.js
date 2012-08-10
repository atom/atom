/*
 * Copyright (C) Research In Motion Limited, 2012. All rights reserved.
 */

// Upon the user making a selection, I will call window.setValueAndClosePopup with a binary string where
// the character at index i being '1' means that the option at index i is selected.
(function (){

    var selectOption = function (event) {
        for (var option = document.getElementById('select-area').firstChild; option; option = option.nextSibling) {
            if (option === event.target) {
                if (option.className.indexOf('selected') === -1) {
                    option.className += ' selected';
                }
            } else {
                option.className = option.className.replace('selected', '');
            }
        }
        done();
    };

    var toggleOption = function (event) {
        if (event.target.className.indexOf('selected') === -1) {
            event.target.className += ' selected';
        } else {
            event.target.className = event.target.className.replace('selected', '');
        }
    };

    var done = function () {
        var result = '';
        for (var option = document.getElementById('select-area').firstChild; option; option = option.nextSibling) {
            if (option.className.indexOf('selected') === -1) {
                result += '0';
            } else {
                result += '1';
            }
        }
        window.setValueAndClosePopup(result, window.popUp);
    };

    /* multiple - a boolean
     * labels - an array of strings
     * enableds - an array of booleans.
     *   -I will assume that the HTML "disabled optgroups disable all options in the optgroup" hasn't been applied,
     *    so if the index corresponds to an optgroup, I will render all of its options as disabled
     * itemTypes - an array of integers, 0 === option, 1 === optgroup, 2 === option in optgroup
     * selecteds - an array of booleans
     * buttonText - a string to use for the button presented when multiple is true. Like "OK" or "Done" or something.
     */
    var show = function (multiple, labels, enableds, itemTypes, selecteds, buttonText) {
        var i,
            size = labels.length,
            popup = document.createElement('div'),
            select = document.createElement('div');

        popup.className = 'popup-area';
        select.className = 'select-area';
        select.id = 'select-area';
        popup.appendChild(select);

        for (i = 0; i < size; i++) {
            // TODO: handle itemTypes
            var option = document.createElement('div');
            option.className = 'option' + (enableds[i] ? '' : ' disabled') + (selecteds[i] ? ' selected' : '');
            option.appendChild(document.createTextNode(labels[i]));
            if (!multiple) {
                option.addEventListener('click', selectOption);
            } else if (enableds[i]) {
                option.addEventListener('click', toggleOption);
            }

            select.appendChild(option);
        }

        if (multiple) {
            var okButton = document.createElement('button'),
                buttons = document.createElement('div');
            buttons.className = 'popup-buttons';
            okButton.className = 'popup-button';
            okButton.addEventListener('click', done);
            okButton.appendChild(document.createTextNode(buttonText));
            buttons.appendChild(okButton);
            popup.appendChild(buttons);
        }

        document.body.appendChild(popup);
    };

    window.select = window.select || {};
    window.select.show = show;
}());
