/* ***** BEGIN LICENSE BLOCK *****
 * Version: MPL 1.1/GPL 2.0/LGPL 2.1
 *
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * The Original Code is Mozilla Skywriter.
 *
 * The Initial Developer of the Original Code is
 * Mozilla.
 * Portions created by the Initial Developer are Copyright (C) 2009
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *      Kevin Dangoor (kdangoor@mozilla.com)
 *      Julian Viereck <julian.viereck@gmail.com>
 *
 * Alternatively, the contents of this file may be used under the terms of
 * either the GNU General Public License Version 2 or later (the "GPL"), or
 * the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
 * in which case the provisions of the GPL or the LGPL are applicable instead
 * of those above. If you wish to allow use of your version of this file only
 * under the terms of either the GPL or the LGPL, and not to allow others to
 * use your version of this file under the terms of the MPL, indicate your
 * decision by deleting the provisions above and replace them with the notice
 * and other provisions required by the GPL or the LGPL. If you do not delete
 * the provisions above, a recipient may use your version of this file under
 * the terms of any one of the MPL, the GPL or the LGPL.
 *
 * ***** END LICENSE BLOCK ***** */

define(function(require, exports, module) {
"use strict";

var Event = require("../lib/event");
var UA = require("../lib/useragent");
var net = require("../lib/net");
var ace = require("../ace");

require("ace/theme/textmate");

/**
 * Returns the CSS property of element.
 *   1) If the CSS property is on the style object of the element, use it, OR
 *   2) Compute the CSS property
 *
 * If the property can't get computed, is 'auto' or 'intrinsic', the former
 * calculated property is uesd (this can happen in cases where the textarea
 * is hidden and has no dimension styles).
 */
var getCSSProperty = function(element, container, property) {
    var ret = element.style[property];

    if (!ret) {
        if (window.getComputedStyle) {
            ret = window.getComputedStyle(element, '').getPropertyValue(property);
        } else {
            ret = element.currentStyle[property];
        }
    }

    if (!ret || ret == 'auto' || ret == 'intrinsic') {
        ret = container.style[property];
    }
    return ret;
};

function applyStyles(elm, styles) {
    for (var style in styles) {
        elm.style[style] = styles[style];
    }
}

function setupContainer(element, getValue) {
        if (element.type != 'textarea') {
        throw "Textarea required!";
    }

    var parentNode = element.parentNode;

    // This will hold the editor.
    var container = document.createElement('div');

    // To put Ace in the place of the textarea, we have to copy a few of the
    // textarea's style attributes to the div container.
    //
    // The problem is that the properties have to get computed (they might be
    // defined by a CSS file on the page - you can't access such rules that
    // apply to an element via elm.style). Computed properties are converted to
    // pixels although the dimension might be given as percentage. When the
    // window resizes, the dimensions defined by percentages changes, so the
    // properties have to get recomputed to get the new/true pixels.
    var resizeEvent = function() {
        var style = 'position:relative;';
        [
            'margin-top', 'margin-left', 'margin-right', 'margin-bottom'
        ].forEach(function(item) {
            style += item + ':' +
                        getCSSProperty(element, container, item) + ';';
        });

        // Calculating the width/height of the textarea is somewhat tricky. To
        // do it right, you have to include the paddings to the sides as well
        // (eg. width = width + padding-left, -right).  This works well, as
        // long as the width of the element is not set or given in pixels. In
        // this case and after the textarea is hidden, getCSSProperty(element,
        // container, 'width') will still return pixel value. If the element
        // has realtiv dimensions (e.g. width='95<percent>')
        // getCSSProperty(...) will return pixel values only as long as the
        // textarea is visible. After it is hidden getCSSProperty will return
        // the relative dimensions as they are set on the element (in the case
        // of width, 95<percent>).
        // Making the sum of pixel vaules (e.g. padding) and realtive values
        // (e.g. <percent>) is not possible. As such the padding styles are
        // ignored.

        // The complete width is the width of the textarea + the padding
        // to the left and right.
        var width = getCSSProperty(element, container, 'width') || (element.clientWidth + "px");
        var height = getCSSProperty(element, container, 'height')  || (element.clientHeight + "px");
        style += 'height:' + height + ';width:' + width + ';';

        // Set the display property to 'inline-block'.
        style += 'display:inline-block;';
        container.setAttribute('style', style);
    };
    Event.addListener(window, 'resize', resizeEvent);

    // Call the resizeEvent once, so that the size of the container is
    // calculated.
    resizeEvent();

    // Insert the div container after the element.
    if (element.nextSibling) {
        parentNode.insertBefore(container, element.nextSibling);
    } else {
        parentNode.appendChild(container);
    }

    // Override the forms onsubmit function. Set the innerHTML and value
    // of the textarea before submitting.
    while (parentNode !== document) {
        if (parentNode.tagName.toUpperCase() === 'FORM') {
            var oldSumit = parentNode.onsubmit;
            // Override the onsubmit function of the form.
            parentNode.onsubmit = function(evt) {
                element.innerHTML = getValue();
                element.value = getValue();
                // If there is a onsubmit function already, then call
                // it with the current context and pass the event.
                if (oldSumit) {
                    oldSumit.call(this, evt);
                }
            };
            break;
        }
        parentNode = parentNode.parentNode;
    }
    return container;
}

exports.transformTextarea = function(element, loader) {
    var session;
    var container = setupContainer(element, function() {
        return session.getValue();
    });

    // Hide the element.
    element.style.display = 'none';
    container.style.background = 'white';

    //
    var editorDiv = document.createElement("div");
    applyStyles(editorDiv, {
        top: "0px",
        left: "0px",
        right: "0px",
        bottom: "0px",
        border: "1px solid gray"
    });
    container.appendChild(editorDiv);

    var settingOpener = document.createElement("div");
    applyStyles(settingOpener, {
        position: "absolute",
        width: "15px",
        right: "0px",
        bottom: "0px",
        background: "red",
        cursor: "pointer",
        textAlign: "center",
        fontSize: "12px"
    });
    settingOpener.innerHTML = "I";

    var settingDiv = document.createElement("div");
    var settingDivStyles = {
        top: "0px",
        left: "0px",
        right: "0px",
        bottom: "0px",
        position: "absolute",
        padding: "5px",
        zIndex: 100,
        color: "white",
        display: "none",
        overflow: "auto",
        fontSize: "14px"
    };
    if (!UA.isOldIE) {
        settingDivStyles.backgroundColor = "rgba(0, 0, 0, 0.6)";
    } else {
        settingDivStyles.backgroundColor = "#333";
    }

    applyStyles(settingDiv, settingDivStyles);
    container.appendChild(settingDiv);

    // Power up ace on the textarea:
    var options = {};

    var editor = ace.edit(editorDiv);
    session = editor.getSession();

    session.setValue(element.value || element.innerHTML);
    editor.focus();

    // Add the settingPanel opener to the editor's div.
    editorDiv.appendChild(settingOpener);

    // Create the API.
    var api = setupApi(editor, editorDiv, settingDiv, ace, options, loader);

    // Create the setting's panel.
    setupSettingPanel(settingDiv, settingOpener, api, options);

    return api;
};

function load(url, module, callback) {
    net.loadScript(url, function() {
        require([module], callback);
    });
}

function setupApi(editor, editorDiv, settingDiv, ace, options, loader) {
    var session = editor.getSession();
    var renderer = editor.renderer;
    loader = loader || load;

    function toBool(value) {
        return value == "true";
    }

    var ret = {
        setDisplaySettings: function(display) {
            settingDiv.style.display = display ? "block" : "none";
        },

        setOption: function(key, value) {
            if (options[key] == value) return;

            switch (key) {
                case "gutter":
                    renderer.setShowGutter(toBool(value));
                break;

                case "mode":
                    if (value != "text") {
                        // Load the required mode file. Files get loaded only once.
                        loader("mode-" + value + ".js", "ace/mode/" + value, function() {
                            var aceMode = require("../mode/" + value).Mode;
                            session.setMode(new aceMode());
                        });
                    } else {
                        session.setMode(new (require("../mode/text").Mode));
                    }
                break;

                case "theme":
                    if (value != "textmate") {
                        // Load the required theme file. Files get loaded only once.
                        loader("theme-" + value + ".js", "ace/theme/" + value, function() {
                            editor.setTheme("ace/theme/" + value);
                        });
                    } else {
                        editor.setTheme("ace/theme/textmate");
                    }
                break;

                case "fontSize":
                    editorDiv.style.fontSize = value;
                break;

                case "softWrap":
                    switch (value) {
                        case "off":
                            session.setUseWrapMode(false);
                            renderer.setPrintMarginColumn(80);
                        break;
                        case "40":
                            session.setUseWrapMode(true);
                            session.setWrapLimitRange(40, 40);
                            renderer.setPrintMarginColumn(40);
                        break;
                        case "80":
                            session.setUseWrapMode(true);
                            session.setWrapLimitRange(80, 80);
                            renderer.setPrintMarginColumn(80);
                        break;
                        case "free":
                            session.setUseWrapMode(true);
                            session.setWrapLimitRange(null, null);
                            renderer.setPrintMarginColumn(80);
                        break;
                    }
                break;

                case "useSoftTabs":
                    session.setUseSoftTabs(toBool(value));
                break;

                case "showPrintMargin":
                    renderer.setShowPrintMargin(toBool(value));
                break;

                case "showInvisibles":
                    editor.setShowInvisibles(toBool(value));
                break;
            }

            options[key] = value;
        },

        getOption: function(key) {
            return options[key];
        },

        getOptions: function() {
            return options;
        }
    };

    for (var option in exports.options) {
        ret.setOption(option, exports.options[option]);
    }

    return ret;
}

function setupSettingPanel(settingDiv, settingOpener, api, options) {
    var BOOL = {
        "true":  true,
        "false": false
    };

    var desc = {
        mode:            "Mode:",
        gutter:          "Display Gutter:",
        theme:           "Theme:",
        fontSize:        "Font Size:",
        softWrap:        "Soft Wrap:",
        showPrintMargin: "Show Print Margin:",
        useSoftTabs:     "Use Soft Tabs:",
        showInvisibles:  "Show Invisibles"
    };

    var optionValues = {
        mode: {
            text:       "Plain",
            javascript: "JavaScript",
            xml:        "XML",
            html:       "HTML",
            css:        "CSS",
            scss:       "SCSS",
            python:     "Python",
            php:        "PHP",
            java:       "Java",
            ruby:       "Ruby",
            c_cpp:      "C/C++",
            coffee:     "CoffeeScript",
            json:       "json",
            perl:       "Perl",
            clojure:    "Clojure",
            ocaml:      "OCaml",
            csharp:     "C#",
            haxe:       "haXe",
            svg:        "SVG",
            textile:    "Textile",
            groovy:     "Groovy",
            Scala:      "Scala"
        },
        theme: {
            clouds:           "Clouds",
            clouds_midnight:  "Clouds Midnight",
            cobalt:           "Cobalt",
            crimson_editor:   "Crimson Editor",
            dawn:             "Dawn",
            eclipse:          "Eclipse",
            idle_fingers:     "Idle Fingers",
            kr_theme:         "Kr Theme",
            merbivore:        "Merbivore",
            merbivore_soft:   "Merbivore Soft",
            mono_industrial:  "Mono Industrial",
            monokai:          "Monokai",
            pastel_on_dark:   "Pastel On Dark",
            solarized_dark:   "Solarized Dark",
            solarized_light:  "Solarized Light",
            textmate:         "Textmate",
            twilight:         "Twilight",
            vibrant_ink:      "Vibrant Ink"
        },
        gutter: BOOL,
        fontSize: {
            "10px": "10px",
            "11px": "11px",
            "12px": "12px",
            "14px": "14px",
            "16px": "16px"
        },
        softWrap: {
            off:    "Off",
            40:     "40",
            80:     "80",
            free:   "Free"
        },
        showPrintMargin:    BOOL,
        useSoftTabs:        BOOL,
        showInvisibles:     BOOL
    };

    var table = [];
    table.push("<table><tr><th>Setting</th><th>Value</th></tr>");

    function renderOption(builder, option, obj, cValue) {
        builder.push("<select title='" + option + "'>");
        for (var value in obj) {
            builder.push("<option value='" + value + "' ");

            if (cValue == value) {
                builder.push(" selected ");
            }

            builder.push(">",
                obj[value],
                "</option>");
        }
        builder.push("</select>");
    }

    for (var option in options) {
        table.push("<tr><td>", desc[option], "</td>");
        table.push("<td>");
        renderOption(table, option, optionValues[option], options[option]);
        table.push("</td></tr>");
    }
    table.push("</table>");
    settingDiv.innerHTML = table.join("");

    var selects = settingDiv.getElementsByTagName("select");
    for (var i = 0; i < selects.length; i++) {
        var onChange = (function() {
            var select = selects[i];
            return function() {
                var option = select.title;
                var value  = select.value;
                api.setOption(option, value);
            };
        })();
        selects[i].onchange = onChange;
    }

    var button = document.createElement("input");
    button.type = "button";
    button.value = "Hide";
    button.onclick = function() {
        api.setDisplaySettings(false);
    };
    settingDiv.appendChild(button);

    settingOpener.onclick = function() {
        api.setDisplaySettings(true);
    };
}

// Default startup options.
exports.options = {
    mode:               "text",
    theme:              "textmate",
    gutter:             "false",
    fontSize:           "12px",
    softWrap:           "off",
    showPrintMargin:    "false",
    useSoftTabs:        "true",
    showInvisibles:     "true"
};

});
