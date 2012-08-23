"use strict";
/*
 * Copyright (C) 2012 Google Inc. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are
 * met:
 *
 *     * Redistributions of source code must retain the above copyright
 * notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above
 * copyright notice, this list of conditions and the following disclaimer
 * in the documentation and/or other materials provided with the
 * distribution.
 *     * Neither the name of Google Inc. nor the names of its
 * contributors may be used to endorse or promote products derived from
 * this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

// FIXME:
//  - Touch event

/**
 * CSS class names.
 *
 * @enum {string}
 */
var ClassNames = {
    Available: "available",
    CancelButton: "cancel-button",
    ClearButton: "clear-button",
    Day: "day",
    DayLabel: "day-label",
    DayLabelContainer: "day-label-container",
    DaysArea: "days-area",
    DaysAreaContainer: "days-area-container",
    MonthSelector: "month-selector",
    MonthSelectorBox: "month-selector-box",
    MonthSelectorPopup: "month-selector-popup",
    MonthSelectorWall: "month-selector-wall",
    NoFocusRing: "no-focus-ring",
    NotThisMonth: "not-this-month",
    Selected: "day-selected",
    TodayButton: "today-button",
    TodayClearArea: "today-clear-area",
    Unavailable: "unavailable",
    WeekContainer: "week-container",
    YearMonthArea: "year-month-area",
    YearMonthButton: "year-month-button",
    YearMonthButtonLeft: "year-month-button-left",
    YearMonthButtonRight: "year-month-button-right",
    YearMonthUpper: "year-month-upper"
};

/**
 * @type {Object}
 */
var global = {
    argumentsReceived: false,
    hadKeyEvent: false,
    params: null
};

// ----------------------------------------------------------------
// Utility functions

/**
 * @param {!string} id
 */
function $(id) {
    return document.getElementById(id);
}

function bind(func, context) {
    return function() {
        return func.apply(context, arguments);
    };
}

/**
 * @param {!string} tagName
 * @param {string=} opt_class
 * @param {string=} opt_text
 * @return {!Element}
 */
function createElement(tagName, opt_class, opt_text) {
    var element = document.createElement(tagName);
    if (opt_class)
        element.setAttribute("class", opt_class);
    if (opt_text)
        element.appendChild(document.createTextNode(opt_text));
    return element;
}

/**
 * @return {!string} lowercase locale name. e.g. "en-us"
 */
function getLocale() {
    return (global.params.locale || "en-us").toLowerCase();
}

/**
 * @return {!string} lowercase language code. e.g. "en"
 */
function getLanguage() {
    var locale = getLocale();
    var result = locale.match(/^([a-z]+)/);
    if (!result)
        return "en";
    return result[1];
}

/*
 * @const
 * @type {number}
 */
var ImperialEraLimit = 2087;

/**
 * @param {!number} year
 * @param {!number} month
 * @return {!string}
 */
function formatJapaneseImperialEra(year, month) {
    // We don't show an imperial era if it is greater than 99 becase of space
    // limitation.
    if (year > ImperialEraLimit)
        return "";
    if (year > 1989)
        return "(平成" + (year - 1988) + "年)";
    if (year == 1989)
        return "(平成元年)";
    if (year >= 1927)
        return "(昭和" + (year - 1925) + "年)";
    if (year > 1912)
        return "(大正" + (year - 1911) + "年)";
    if (year == 1912 && month >= 7)
        return "(大正元年)";
    if (year > 1868)
        return "(明治" + (year - 1867) + "年)";
    if (year == 1868)
        return "(明治元年)";
    return "";
}

/**
 * @param {!number} year
 * @param {!number} month
 * @return {!string}
 */
function formatYearMonth(year, month) {
    // FIXME: Need localized number?
    var yearString = String(year);
    var monthString = global.params.monthLabels[month];
    switch (getLanguage()) {
    case "eu":
    case "fil":
    case "lt":
    case "ml":
    case "mt":
    case "tl":
    case "ur":
        return yearString + " " + monthString;
    case "hu":
        return yearString + ". " + monthString;
    case "ja":
        return yearString + "年" + formatJapaneseImperialEra(year, month) + " " + monthString;
    case "zh":
        return yearString + "年" + monthString;
    case "ko":
        return yearString + "년 " + monthString;
    case "lv":
        return yearString + ". g. " + monthString;
    case "pt":
        return monthString + " de " + yearString;
    case "sr":
        return monthString + ". " + yearString;
    default:
        return monthString + " " + yearString;
    }
}

/**
 * @param {string=} opt_current
 * @return {!Date}
 */
function parseDateString(opt_current) {
    if (opt_current) {
        var result = opt_current.match(/(\d+)-(\d+)-(\d+)/);
        if (result)
            return new Date(Date.UTC(Number(result[1]), Number(result[2]) - 1, Number(result[3])));
    }
    var now = new Date();
    // Create UTC date with same numbers as local date.
    return new Date(Date.UTC(now.getFullYear(), now.getMonth(), now.getDate()));
}

/**
 * @param {!number} year
 * @param {!number} month
 * @param {!number} day
 * @return {!string}
 */
function serializeDate(year, month, day) {
    var yearString = String(year);
    if (yearString.length < 4)
        yearString = ("000" + yearString).substr(-4, 4);
    return yearString + "-" + ("0" + (month + 1)).substr(-2, 2) + "-" + ("0" + day).substr(-2, 2);
}

// ----------------------------------------------------------------
// Initialization

/**
 * @param {Event} event
 */
function handleMessage(event) {
    if (global.argumentsReceived)
        return;
    global.argumentsReceived = true;
    initialize(JSON.parse(event.data));
}

function handleArgumentsTimeout() {
    if (global.argumentsReceived)
        return;
    var args = {
        monthLabels : ["m1", "m2", "m3", "m4", "m5", "m6",
                       "m7", "m8", "m9", "m10", "m11", "m12"],
        dayLabels : ["d1", "d2", "d3", "d4", "d5", "d6", "d7"],
        todayLabel : "Today",
        clearLabel : "Clear",
        cancelLabel : "Cancel",
        currentValue : "",
        weekStartDay : 0,
        step : 1
    };
    initialize(args);
}

/**
 * @param {!Object} args
 * @return {?string} An error message, or null if the argument has no errors.
 */
function validateArguments(args) {
    if (!args.monthLabels)
        return "No monthLabels.";
    if (args.monthLabels.length != 12)
        return "monthLabels is not an array with 12 elements.";
    if (!args.dayLabels)
        return "No dayLabels.";
    if (args.dayLabels.length != 7)
        return "dayLabels is not an array with 7 elements.";
    if (!args.clearLabel)
        return "No clearLabel.";
    if (!args.todayLabel)
        return "No todayLabel.";
    if (args.weekStartDay) {
        if (args.weekStartDay < 0 || args.weekStartDay > 6)
            return "Invalid weekStartDay: " + args.weekStartDay;
    }
    return null;
}

/**
 * @param {!Object} args
 */
function initialize(args) {
    var main = $("main");
    main.classList.add(ClassNames.NoFocusRing);

    var errorString = validateArguments(args);
    if (errorString)
        main.textContent = "Internal error: " + errorString;
    else {
        global.params = args;
        checkLimits();
        layout();

        var initialDate = parseDateString(args.currentValue);
        if (initialDate < global.minimumDate)
            initialDate = global.minimumDate;
        else if (initialDate > global.maximumDate)
            initialDate = global.maximumDate;
        global.daysTable.selectDate(initialDate);

        setTimeout(fixWindowSize, 0);
    }
}

function fixWindowSize() {
    var yearMonthRightElement = document.getElementsByClassName(ClassNames.YearMonthButtonRight)[0];
    var daysAreaElement = document.getElementsByClassName(ClassNames.DaysArea)[0];
    var headers = daysAreaElement.getElementsByClassName(ClassNames.DayLabel);
    var maxCellWidth = 0;
    for (var i = 0; i < headers.length; ++i) {
        if (maxCellWidth < headers[i].offsetWidth)
            maxCellWidth = headers[i].offsetWidth;
    }
    var DaysAreaContainerBorder = 1;
    var maxRight = Math.max(yearMonthRightElement.offsetLeft + yearMonthRightElement.offsetWidth,
                            daysAreaElement.offsetLeft + maxCellWidth * 7 + DaysAreaContainerBorder);
    var MainPadding = 6;
    var MainBorder = 1;
    var desiredBodyWidth = maxRight + MainPadding + MainBorder;

    var main = $("main");
    var mainHeight = main.offsetHeight;
    main.style.width = "auto";
    daysAreaElement.style.width = "100%";
    daysAreaElement.style.tableLayout = "fixed";
    document.getElementsByClassName(ClassNames.YearMonthUpper)[0].style.display = "-webkit-box";
    document.getElementsByClassName(ClassNames.MonthSelectorBox)[0].style.display = "block";
    main.style.webkitTransition = "opacity 0.1s ease";
    main.style.opacity = "1";
    if (window.frameElement) {
        window.frameElement.style.width = desiredBodyWidth + "px";
        window.frameElement.style.height = mainHeight + "px";
    } else {
        window.resizeTo(desiredBodyWidth, mainHeight);
    }
}

function checkLimits() {
    // Hard limits of type=date. See WebCore/platform/DateComponents.h.
    global.minimumDate = new Date(-62135596800000.0);
    global.maximumDate = new Date(8640000000000000.0);
    // See WebCore/html/DateInputType.cpp.
    global.step = 86400000;

    if (global.params.min) {
        // We assume params.min is a valid date.
        global.minimumDate = parseDateString(global.params.min);
    }
    if (global.params.max) {
        // We assume params.max is a valid date.
        global.maximumDate = parseDateString(global.params.max);
    }
    if (global.params.step)
        global.step *= global.params.step;
}

function layout() {
    if (global.params.isRTL)
        document.body.dir = "rtl";
    var main = $("main");
    var params = global.params;
    main.removeChild(main.firstChild);
    document.body.addEventListener("keydown", handleGlobalKey, false);

    global.yearMonthController = new YearMonthController();
    global.yearMonthController.attachTo(main);
    global.daysTable = new DaysTable();
    global.daysTable.attachTo(main);
    layoutButtons(main);
}

/**
 * @param {Element} main
 */
function layoutButtons(main) {
    var container = createElement("div", ClassNames.TodayClearArea);
    global.today = createElement("input", ClassNames.TodayButton);
    global.today.type = "button";
    global.today.value = global.params.todayLabel;
    global.today.addEventListener("click", handleToday, false);
    container.appendChild(global.today);
    global.clear = null;
    if (!global.params.required) {
        global.clear = createElement("input", ClassNames.ClearButton);
        global.clear.type = "button";
        global.clear.value = global.params.clearLabel;
        global.clear.addEventListener("click", handleClear, false);
        container.appendChild(global.clear);
    }
    main.appendChild(container);

    global.lastFocusableControl = global.clear || global.today;
}

// ----------------------------------------------------------------

/**
 * @constructor
 */
function YearMonthController() {
    /**
     * @type {!number}
     */
    this._currentYear = -1;
    /**
     * @type {!number}
     */
    this._currentMonth = -1;
}

/**
 * @param {!Element} main
 */
YearMonthController.prototype.attachTo = function(main) {
    var outerContainer = createElement("div", ClassNames.YearMonthArea);

    var innerContainer = createElement("div", ClassNames.YearMonthUpper);
    outerContainer.appendChild(innerContainer);

    this._attachLeftButtonsTo(innerContainer);

    var box = createElement("div", ClassNames.MonthSelectorBox);
    innerContainer.appendChild(box);
    // We can't use <select> popup in PagePopup.
    // FIXME: The popup-menu emulation by a listbox is not great.
    this._monthPopup = createElement("select", ClassNames.MonthSelectorPopup);
    this._monthPopup.addEventListener("click", bind(this._handleYearMonthChange, this), false);
    this._monthPopup.addEventListener("keydown", bind(this._handleMonthPopupKey, this), false);
    box.appendChild(this._monthPopup);
    this._month = createElement("div", ClassNames.MonthSelector);
    this._month.addEventListener("click", bind(this._showPopup, this), false);
    box.appendChild(this._month);

    this._attachRightButtonsTo(innerContainer);
    main.appendChild(outerContainer);

    this._wall = createElement("div", ClassNames.MonthSelectorWall);
    this._wall.addEventListener("click", bind(this._closePopup, this), false);
    main.appendChild(this._wall);

    var maximumYear = global.maximumDate.getUTCFullYear();
    var maxWidth = 0;
    for (var m = 0; m < 12; ++m) {
        this._month.textContent = formatYearMonth(maximumYear, m);
        maxWidth = Math.max(maxWidth, this._month.offsetWidth);
    }
    if (getLanguage() == "ja" && ImperialEraLimit < maximumYear) {
        for (var m = 0; m < 12; ++m) {
            this._month.textContent = formatYearMonth(ImperialEraLimit, m);
            maxWidth = Math.max(maxWidth, this._month.offsetWidth);
        }
    }
    this._month.style.minWidth = maxWidth + 'px';

    global.firstFocusableControl = this._left2; // FIXME: Shoud it be this.month?
};

YearMonthController.addTenYearsButtons = false;

/**
 * @param {!Element} parent
 */
YearMonthController.prototype._attachLeftButtonsTo = function(parent) {
    var container = createElement("div", ClassNames.YearMonthButtonLeft);
    parent.appendChild(container);

    if (YearMonthController.addTenYearsButtons) {
        this._left3 = createElement("input", ClassNames.YearMonthButton);
        this._left3.type = "button";
        this._left3.value = "<<<";
        this._left3.addEventListener("click", bind(this._handleButtonClick, this), false);
        container.appendChild(this._left3);
    }

    this._left2 = createElement("input", ClassNames.YearMonthButton);
    this._left2.type = "button";
    this._left2.value = "<<";
    this._left2.addEventListener("click", bind(this._handleButtonClick, this), false);
    container.appendChild(this._left2);

    this._left1 = createElement("input", ClassNames.YearMonthButton);
    this._left1.type = "button";
    this._left1.value = "<";
    this._left1.addEventListener("click", bind(this._handleButtonClick, this), false);
    container.appendChild(this._left1);
};

/**
 * @param {!Element} parent
 */
YearMonthController.prototype._attachRightButtonsTo = function(parent) {
    var container = createElement("div", ClassNames.YearMonthButtonRight);
    parent.appendChild(container);
    this._right1 = createElement("input", ClassNames.YearMonthButton);
    this._right1.type = "button";
    this._right1.value = ">";
    this._right1.addEventListener("click", bind(this._handleButtonClick, this), false);
    container.appendChild(this._right1);

    this._right2 = createElement("input", ClassNames.YearMonthButton);
    this._right2.type = "button";
    this._right2.value = ">>";
    this._right2.addEventListener("click", bind(this._handleButtonClick, this), false);
    container.appendChild(this._right2);

    if (YearMonthController.addTenYearsButtons) {
        this._right3 = createElement("input", ClassNames.YearMonthButton);
        this._right3.type = "button";
        this._right3.value = ">>>";
        this._right3.addEventListener("click", bind(this._handleButtonClick, this), false);
        container.appendChild(this._right3);
    }
};

/**
 * @return {!number}
 */
YearMonthController.prototype.year = function() {
    return this._currentYear;
};

/**
 * @return {!number}
 */
YearMonthController.prototype.month = function() {
    return this._currentMonth;
};

/**
 * @param {!number} year
 * @param {!number} month
 */
YearMonthController.prototype.setYearMonth = function(year, month) {
    this._currentYear = year;
    this._currentMonth = month;
    this._redraw();
};

YearMonthController.prototype._redraw = function() {
    var min = global.minimumDate.getUTCFullYear() * 12 + global.minimumDate.getUTCMonth();
    var max = global.maximumDate.getUTCFullYear() * 12 + global.maximumDate.getUTCMonth();
    var current = this._currentYear * 12 + this._currentMonth;
    if (this._left3)
        this._left3.disabled = current - 13 < min;
    this._left2.disabled = current - 2 < min;
    this._left1.disabled = current - 1 < min;
    this._right1.disabled = current + 1 > max;
    this._right2.disabled = current + 2 > max;
    if (this._right3)
        this._right3.disabled = current + 13 > max;
    this._month.innerText = formatYearMonth(this._currentYear, this._currentMonth);
    while (this._monthPopup.hasChildNodes())
        this._monthPopup.removeChild(this._monthPopup.firstChild);
    for (var m = current - 6; m <= current + 6; m++) {
        if (m < min || m > max)
            continue;
        var option = createElement("option", undefined, formatYearMonth(Math.floor(m / 12), m % 12));
        option.value = String(Math.floor(m / 12)) + "-" + String(m % 12);
        this._monthPopup.appendChild(option);
        if (m == current)
            option.selected = true;
    }
};

YearMonthController.prototype._showPopup = function() {
    this._monthPopup.size = Math.max(4, Math.min(10, this._monthPopup.length));
    this._monthPopup.style.display = "block";
    this._monthPopup.style.position = "absolute";
    this._monthPopup.style.zIndex = "1000"; // Larger than the days area.
    this._monthPopup.style.left = this._month.offsetLeft + (this._month.offsetWidth - this._monthPopup.offsetWidth) / 2 + "px";
    this._monthPopup.style.top = this._month.offsetTop + this._month.offsetHeight + "px";
    this._monthPopup.focus();

    this._wall.style.display = "block";
    this._wall.style.zIndex = "999"; // This should be smaller than the z-index of monthPopup.
};

YearMonthController.prototype._closePopup = function() {
    this._monthPopup.style.display = "none";
    this._wall.style.display = "none";
};

/**
 * @param {Event} event
 */
YearMonthController.prototype._handleMonthPopupKey = function(event)
{
    var key = event.keyIdentifier;
    if (key == "U+001B") {
        this._closePopup();
        event.stopPropagation();
        event.preventDefault();
    } else if (key == "Enter") {
        this._handleYearMonthChange();
        event.stopPropagation();
        event.preventDefault();
    }
}

YearMonthController.prototype._handleYearMonthChange = function() {
    this._closePopup();

    var result = this._monthPopup.value.match(/(\d+)-(\d+)/);
    if (!result)
        return;
    var newYear = Number(result[1]);
    var newMonth = Number(result[2]);
    global.daysTable.navigateToMonthAndKeepSelectionPosition(newYear, newMonth);
};

/*
 * @const
 * @type {number}
 */
YearMonthController.PreviousTenYears = -120;
/*
 * @const
 * @type {number}
 */
YearMonthController.PreviousYear = -12;
/*
 * @const
 * @type {number}
 */
YearMonthController.PreviousMonth = -1;
/*
 * @const
 * @type {number}
 */
YearMonthController.NextMonth = 1;
/*
 * @const
 * @type {number}
 */
YearMonthController.NextYear = 12;
/*
 * @const
 * @type {number}
 */
YearMonthController.NextTenYears = 120;

/**
 * @param {Event} event
 */
YearMonthController.prototype._handleButtonClick = function(event) {
    if (event.target == this._left3)
        this.moveRelatively(YearMonthController.PreviousTenYears);
    else if (event.target == this._left2)
        this.moveRelatively(YearMonthController.PreviousYear);
    else if (event.target == this._left1)
        this.moveRelatively(YearMonthController.PreviousMonth);
    else if (event.target == this._right1)
        this.moveRelatively(YearMonthController.NextMonth)
    else if (event.target == this._right2)
        this.moveRelatively(YearMonthController.NextYear);
    else if (event.target == this._right3)
        this.moveRelatively(YearMonthController.NextTenYears);
    else
        return;
};

/**
 * @param {!number} amount
 */
YearMonthController.prototype.moveRelatively = function(amount) {
    var min = global.minimumDate.getUTCFullYear() * 12 + global.minimumDate.getUTCMonth();
    var max = global.maximumDate.getUTCFullYear() * 12 + global.maximumDate.getUTCMonth();
    var current = this._currentYear * 12 + this._currentMonth;
    var updated = current;
    if (amount < 0)
        updated = current + amount >= min ? current + amount : min;
    else
        updated = current + amount <= max ? current + amount : max;
    if (updated == current)
        return;
    global.daysTable.navigateToMonthAndKeepSelectionPosition(Math.floor(updated / 12), updated % 12);
};

// ----------------------------------------------------------------

/**
 * @constructor
 */
function DaysTable() {
    /**
     * @type {!number}
     */
    this._x = -1;
    /**
     * @type {!number}
     */
    this._y = -1;
    /**
     * @type {!number}
     */
    this._currentYear = -1;
    /**
     * @type {!number}
     */
    this._currentMonth = -1;
}

/**
 * @return {!boolean}
 */
DaysTable.prototype._hasSelection = function() {
    return this._x >= 0 && this._y >= 0;
}

/**
 * The number of week lines in the screen.
 * @const
 * @type {number}
 */
DaysTable._Weeks = 6;

/**
 * @param {!Element} main
 */
DaysTable.prototype.attachTo = function(main) {
    this._daysContainer = createElement("table", ClassNames.DaysArea);
    this._daysContainer.addEventListener("click", bind(this._handleDayClick, this), false);
    this._daysContainer.addEventListener("mouseover", bind(this._handleMouseOver, this), false);
    this._daysContainer.addEventListener("mouseout", bind(this._handleMouseOut, this), false);
    this._daysContainer.addEventListener("webkitTransitionEnd", bind(this._moveInDays, this), false);
    var container = createElement("tr", ClassNames.DayLabelContainer);
    var weekStartDay = global.params.weekStartDay || 0;
    for (var i = 0; i < 7; i++)
        container.appendChild(createElement("th", ClassNames.DayLabel, global.params.dayLabels[(weekStartDay + i) % 7]));
    this._daysContainer.appendChild(container);
    this._days = [];
    for (var w = 0; w < DaysTable._Weeks; w++) {
        container = createElement("tr", ClassNames.WeekContainer);
        var week = [];
        for (var d = 0; d < 7; d++) {
            var day = createElement("td", ClassNames.Day, " ");
            day.setAttribute("data-position-x", String(d));
            day.setAttribute("data-position-y", String(w));
            week.push(day);
            container.appendChild(day);
        }
        this._days.push(week);
        this._daysContainer.appendChild(container);
    }
    container = createElement("div", ClassNames.DaysAreaContainer);
    container.appendChild(this._daysContainer);
    container.tabIndex = 0;
    container.addEventListener("keydown", bind(this._handleKey, this), false);
    main.appendChild(container);

    container.focus();
};

/**
 * @param {!number} time date in millisecond.
 * @return {!boolean}
 */
function stepMismatch(time) {
    return (time - global.minimumDate.getTime()) % global.step != 0;
}

/**
 * @param {!number} time date in millisecond.
 * @return {!boolean}
 */
function outOfRange(time) {
    return time < global.minimumDate.getTime() || time > global.maximumDate.getTime();
}

/**
 * @param {!number} time date in millisecond.
 * @return {!boolean}
 */
function isValidDate(time) {
    return !outOfRange(time) && !stepMismatch(time);
}

/**
 * @param {!number} year
 * @param {!number} month
 */
DaysTable.prototype._renderMonth = function(year, month) {
    this._currentYear = year;
    this._currentMonth = month;
    var dayIterator = new Date(Date.UTC(year, month, 1));
    dayIterator.setUTCFullYear(year);
    var monthStartDay = dayIterator.getUTCDay();
    var weekStartDay = global.params.weekStartDay || 0;
    var startOffset = weekStartDay - monthStartDay;
    if (startOffset >= 0)
        startOffset -= 7;
    dayIterator.setUTCDate(startOffset + 1);
    for (var w = 0; w < DaysTable._Weeks; w++) {
        for (var d = 0; d < 7; d++) {
            var iterYear = dayIterator.getUTCFullYear();
            var iterMonth = dayIterator.getUTCMonth();
            var time = dayIterator.getTime();
            var element = this._days[w][d];
            // FIXME: Need localized number?
            element.innerText = String(dayIterator.getUTCDate());
            element.className = ClassNames.Day;
            element.dataset.submitValue = serializeDate(iterYear, iterMonth, dayIterator.getUTCDate());
            if (outOfRange(time))
                element.classList.add(ClassNames.Unavailable);
            else if (stepMismatch(time))
                element.classList.add(ClassNames.Unavailable);
            else if ((iterYear == year && dayIterator.getUTCMonth() < month) || (month == 0 && iterMonth == 11)) {
                element.classList.add(ClassNames.Available);
                element.classList.add(ClassNames.NotThisMonth);
            } else if ((iterYear == year && dayIterator.getUTCMonth() > month) || (month == 11 && iterMonth == 0)) {
                element.classList.add(ClassNames.Available);
                element.classList.add(ClassNames.NotThisMonth);
            } else if (isNaN(time)) {
                element.innerText = "-";
                element.classList.add(ClassNames.Unavailable);
            } else
                element.classList.add(ClassNames.Available);
            dayIterator.setUTCDate(dayIterator.getUTCDate() + 1);
        }
    }

    global.today.disabled = !isValidDate(parseDateString().getTime());
};

/**
 * @param {!number} year
 * @param {!number} month
 */
DaysTable.prototype._navigateToMonth = function(year, month) {
    global.yearMonthController.setYearMonth(year, month);
    this._renderMonth(year, month);
};

/**
 * @param {!number} year
 * @param {!number} month
 */
DaysTable.prototype._navigateToMonthWithAnimation = function(year, month) {
    if (this._currentYear >= 0 && this._currentMonth >= 0) {
        if (year == this._currentYear && month == this._currentMonth)
            return;
        var decreasing = false;
        if (year < this._currentYear)
            decreasing = true;
        else if (year > this._currentYear)
            decreasing = false;
        else
            decreasing = month < this._currentMonth;
        var daysStyle = this._daysContainer.style;
        daysStyle.position = "relative";
        daysStyle.webkitTransition = "left 0.1s ease";
        daysStyle.left = (decreasing ? "" : "-") + this._daysContainer.offsetWidth + "px";
    }
    this._navigateToMonth(year, month);
};

DaysTable.prototype._moveInDays = function() {
    var daysStyle = this._daysContainer.style;
    if (daysStyle.left == "0px")
        return;
    daysStyle.webkitTransition = "";
    daysStyle.left = (daysStyle.left.charAt(0) == "-" ? "" : "-") + this._daysContainer.offsetWidth + "px";
    this._daysContainer.offsetLeft; // Force to layout.
    daysStyle.webkitTransition = "left 0.1s ease";
    daysStyle.left = "0px";
};

/**
 * @param {!number} year
 * @param {!number} month
 */
DaysTable.prototype.navigateToMonthAndKeepSelectionPosition = function(year, month) {
    if (year == this._currentYear && month == this._currentMonth)
        return;
    this._navigateToMonthWithAnimation(year, month);
    if (this._hasSelection())
        this._days[this._y][this._x].classList.add(ClassNames.Selected);
};

/**
 * @param {!Date} date
 */
DaysTable.prototype.selectDate = function(date) {
    this._navigateToMonthWithAnimation(date.getUTCFullYear(), date.getUTCMonth());
    var dateString = serializeDate(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate());
    for (var w = 0; w < DaysTable._Weeks; w++) {
        for (var d = 0; d < 7; d++) {
            if (this._days[w][d].dataset.submitValue == dateString) {
                this._days[w][d].classList.add(ClassNames.Selected);
                this._x = d;
                this._y = w;
                break;
            }
        }
    }
};

/**
 * @return {!boolean}
 */
DaysTable.prototype._maybeSetPreviousMonth = function() {
    var year = global.yearMonthController.year();
    var month = global.yearMonthController.month();
    var thisMonthStartTime = Date.UTC(year, month, 1);
    if (global.minimumDate.getTime() >= thisMonthStartTime)
        return false;
    if (month == 0) {
        year--;
        month = 11;
    } else
        month--;
    this._navigateToMonthWithAnimation(year, month);
    return true;
};

/**
 * @return {!boolean}
 */
DaysTable.prototype._maybeSetNextMonth = function() {
    var year = global.yearMonthController.year();
    var month = global.yearMonthController.month();
    if (month == 11) {
        year++;
        month = 0;
    } else
        month++;
    var nextMonthStartTime = Date.UTC(year, month, 1);
    if (global.maximumDate.getTime() < nextMonthStartTime)
        return false;
    this._navigateToMonthWithAnimation(year, month);
    return true;
};

/**
 * @param {Event} event
 */
DaysTable.prototype._handleDayClick = function(event) {
    if (event.target.classList.contains(ClassNames.Available))
        submitValue(event.target.dataset.submitValue);
};

/**
 * @param {Event} event
 */
DaysTable.prototype._handleMouseOver = function(event) {
    var node = event.target;
    if (this._hasSelection())
        this._days[this._y][this._x].classList.remove(ClassNames.Selected);
    if (!node.classList.contains(ClassNames.Day)) {
        this._x = -1;
        this._y = -1;
        return;
    }
    node.classList.add(ClassNames.Selected);
    this._x = Number(node.dataset.positionX);
    this._y = Number(node.dataset.positionY);
};

/**
 * @param {Event} event
 */
DaysTable.prototype._handleMouseOut = function(event) {
    if (this._hasSelection())
        this._days[this._y][this._x].classList.remove(ClassNames.Selected);
    this._x = -1;
    this._y = -1;
};

/**
 * @param {Event} event
 */
DaysTable.prototype._handleKey = function(event) {
    maybeUpdateFocusStyle();
    var x = this._x;
    var y = this._y;
    var key = event.keyIdentifier;
    if (!this._hasSelection() && (key == "Left" || key == "Up" || key == "Right" || key == "Down")) {
        // Put the selection on a center cell.
        this.updateSelection(event, 3, Math.floor(DaysTable._Weeks / 2 - 1));
        return;
    }

    if (key == (global.params.isRTL ? "Right" : "Left")) {
        if (x == 0) {
            if (y == 0) {
                if (!this._maybeSetPreviousMonth())
                    return;
                y = DaysTable._Weeks - 1;
            } else
                y--;
            x = 6;
        } else
            x--;
        this.updateSelection(event, x, y);

    } else if (key == "Up") {
        if (y == 0) {
            if (!this._maybeSetPreviousMonth())
                return;
            y = DaysTable._Weeks - 1;
        } else
            y--;
        this.updateSelection(event, x, y);

    } else if (key == (global.params.isRTL ? "Left" : "Right")) {
        if (x == 6) {
            if (y == DaysTable._Weeks - 1) {
                if (!this._maybeSetNextMonth())
                    return;
                y = 0;
            } else
                y++;
            x = 0;
        } else
            x++;
        this.updateSelection(event, x, y);

    } else if (key == "Down") {
        if (y == DaysTable._Weeks - 1) {
            if (!this._maybeSetNextMonth())
                return;
            y = 0;
        } else
            y++;
        this.updateSelection(event, x, y);

    } else if (key == "PageUp") {
        if (!this._maybeSetPreviousMonth())
            return;
        this.updateSelection(event, x, y);

    } else if (key == "PageDown") {
        if (!this._maybeSetNextMonth())
            return;
        this.updateSelection(event, x, y);

    } else if (this._hasSelection() && key == "Enter") {
        var dayNode = this._days[y][x];
        if (dayNode.classList.contains(ClassNames.Available)) {
            submitValue(dayNode.dataset.submitValue);
            event.stopPropagation();
        }

    } else if (key == "U+0054") { // 't'
        this._days[this._y][this._x].classList.remove(ClassNames.Selected);
        this.selectDate(new Date());
        event.stopPropagation();
        event.preventDefault();
    }
};

/**
 * @param {Event} event
 * @param {!number} x
 * @param {!number} y
 */
DaysTable.prototype.updateSelection = function(event, x, y) {
    if (this._hasSelection())
        this._days[this._y][this._x].classList.remove(ClassNames.Selected);
    if (x >= 0 && y >= 0) {
        this._days[y][x].classList.add(ClassNames.Selected);
        this._x = x;
        this._y = y;
    }
    event.stopPropagation();
    event.preventDefault();
};

// ----------------------------------------------------------------

function handleToday() {
    var date = new Date();
    global.daysTable.selectDate(date);
    submitValue(serializeDate(date.getFullYear(), date.getMonth(), date.getDate()));
}

function handleClear() {
    submitValue("");
}

/**
 * @param {string} value
 */
function submitValue(value) {
    window.pagePopupController.setValueAndClosePopup(0, value);
}

function handleCancel() {
    window.pagePopupController.setValueAndClosePopup(-1, "");
}

/**
 * @param {Event} event
 */
function handleGlobalKey(event) {
    maybeUpdateFocusStyle();
    var key = event.keyIdentifier;
    if (key == "U+0009") {
        if (!event.shiftKey && document.activeElement == global.lastFocusableControl) {
            event.stopPropagation();
            event.preventDefault();
            global.firstFocusableControl.focus();
        } else if (event.shiftKey && document.activeElement == global.firstFocusableControl) {
            event.stopPropagation();
            event.preventDefault();
            global.lastFocusableControl.focus();
        }
    } else if (key == "U+004D") { // 'm'
        global.yearMonthController.moveRelatively(event.shiftKey ? YearMonthController.PreviousMonth : YearMonthController.NextMonth);
    } else if (key == "U+0059") { // 'y'
        global.yearMonthController.moveRelatively(event.shiftKey ? YearMonthController.PreviousYear : YearMonthController.NextYear);
    } else if (key == "U+0044") { // 'd'
        global.yearMonthController.moveRelatively(event.shiftKey ? YearMonthController.PreviousTenYears : YearMonthController.NextTenYears);
    } else if (key == "U+001B") // ESC
        handleCancel();
}

function maybeUpdateFocusStyle() {
    if (global.hadKeyEvent)
        return;
    global.hadKeyEvent = true;
    $("main").classList.remove(ClassNames.NoFocusRing);
}

if (window.dialogArguments) {
    initialize(dialogArguments);
} else {
    window.addEventListener("message", handleMessage, false);
    window.setTimeout(handleArgumentsTimeout, 1000);
}
