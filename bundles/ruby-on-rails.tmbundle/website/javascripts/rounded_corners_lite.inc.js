
 /****************************************************************
  *                                                              *
  *  curvyCorners                                                *
  *  ------------                                                *
  *                                                              *
  *  This script generates rounded corners for your divs.        *
  *                                                              *
  *  Version 1.2.9                                               *
  *  Copyright (c) 2006 Cameron Cooke                            *
  *  By: Cameron Cooke and Tim Hutchison.                        *
  *                                                              *
  *                                                              *
  *  Website: http://www.curvycorners.net                        *
  *  Email:   info@totalinfinity.com                             *
  *  Forum:   http://www.curvycorners.net/forum/                 *
  *                                                              *
  *                                                              *
  *  This library is free software; you can redistribute         *
  *  it and/or modify it under the terms of the GNU              *
  *  Lesser General Public License as published by the           *
  *  Free Software Foundation; either version 2.1 of the         *
  *  License, or (at your option) any later version.             *
  *                                                              *
  *  This library is distributed in the hope that it will        *
  *  be useful, but WITHOUT ANY WARRANTY; without even the       *
  *  implied warranty of MERCHANTABILITY or FITNESS FOR A        *
  *  PARTICULAR PURPOSE. See the GNU Lesser General Public       *
  *  License for more details.                                   *
  *                                                              *
  *  You should have received a copy of the GNU Lesser           *
  *  General Public License along with this library;             *
  *  Inc., 59 Temple Place, Suite 330, Boston,                   *
  *  MA 02111-1307 USA                                           *
  *                                                              *
  ****************************************************************/
  
var isIE = navigator.userAgent.toLowerCase().indexOf("msie") > -1; var isMoz = document.implementation && document.implementation.createDocument; var isSafari = ((navigator.userAgent.toLowerCase().indexOf('safari')!=-1)&&(navigator.userAgent.toLowerCase().indexOf('mac')!=-1))?true:false; function curvyCorners()
{ if(typeof(arguments[0]) != "object") throw newCurvyError("First parameter of curvyCorners() must be an object."); if(typeof(arguments[1]) != "object" && typeof(arguments[1]) != "string") throw newCurvyError("Second parameter of curvyCorners() must be an object or a class name."); if(typeof(arguments[1]) == "string")
{ var startIndex = 0; var boxCol = getElementsByClass(arguments[1]);}
else
{ var startIndex = 1; var boxCol = arguments;}
var curvyCornersCol = new Array(); if(arguments[0].validTags)
var validElements = arguments[0].validTags; else
var validElements = ["div"]; for(var i = startIndex, j = boxCol.length; i < j; i++)
{ var currentTag = boxCol[i].tagName.toLowerCase(); if(inArray(validElements, currentTag) !== false)
{ curvyCornersCol[curvyCornersCol.length] = new curvyObject(arguments[0], boxCol[i]);}
}
this.objects = curvyCornersCol; this.applyCornersToAll = function()
{ for(var x = 0, k = this.objects.length; x < k; x++)
{ this.objects[x].applyCorners();}
}
}
function curvyObject()
{ this.box = arguments[1]; this.settings = arguments[0]; this.topContainer = null; this.bottomContainer = null; this.masterCorners = new Array(); this.contentDIV = null; var boxHeight = get_style(this.box, "height", "height"); var boxWidth = get_style(this.box, "width", "width"); var borderWidth = get_style(this.box, "borderTopWidth", "border-top-width"); var borderColour = get_style(this.box, "borderTopColor", "border-top-color"); var boxColour = get_style(this.box, "backgroundColor", "background-color"); var backgroundImage = get_style(this.box, "backgroundImage", "background-image"); var boxPosition = get_style(this.box, "position", "position"); var boxPadding = get_style(this.box, "paddingTop", "padding-top"); this.boxHeight = parseInt(((boxHeight != "" && boxHeight != "auto" && boxHeight.indexOf("%") == -1)? boxHeight.substring(0, boxHeight.indexOf("px")) : this.box.scrollHeight)); this.boxWidth = parseInt(((boxWidth != "" && boxWidth != "auto" && boxWidth.indexOf("%") == -1)? boxWidth.substring(0, boxWidth.indexOf("px")) : this.box.scrollWidth)); this.borderWidth = parseInt(((borderWidth != "" && borderWidth.indexOf("px") !== -1)? borderWidth.slice(0, borderWidth.indexOf("px")) : 0)); this.boxColour = format_colour(boxColour); this.boxPadding = parseInt(((boxPadding != "" && boxPadding.indexOf("px") !== -1)? boxPadding.slice(0, boxPadding.indexOf("px")) : 0)); this.borderColour = format_colour(borderColour); this.borderString = this.borderWidth + "px" + " solid " + this.borderColour; this.backgroundImage = ((backgroundImage != "none")? backgroundImage : ""); this.boxContent = this.box.innerHTML; if(boxPosition != "absolute") this.box.style.position = "relative"; this.box.style.padding = "0px"; if(isIE && boxWidth == "auto" && boxHeight == "auto") this.box.style.width = "100%"; if(this.settings.autoPad == true && this.boxPadding > 0)
this.box.innerHTML = ""; this.applyCorners = function()
{ for(var t = 0; t < 2; t++)
{ switch(t)
{ case 0:
if(this.settings.tl || this.settings.tr)
{ var newMainContainer = document.createElement("DIV"); newMainContainer.style.width = "100%"; newMainContainer.style.fontSize = "1px"; newMainContainer.style.overflow = "hidden"; newMainContainer.style.position = "absolute"; newMainContainer.style.paddingLeft = this.borderWidth + "px"; newMainContainer.style.paddingRight = this.borderWidth + "px"; var topMaxRadius = Math.max(this.settings.tl ? this.settings.tl.radius : 0, this.settings.tr ? this.settings.tr.radius : 0); newMainContainer.style.height = topMaxRadius + "px"; newMainContainer.style.top = 0 - topMaxRadius + "px"; newMainContainer.style.left = 0 - this.borderWidth + "px"; this.topContainer = this.box.appendChild(newMainContainer);}
break; case 1:
if(this.settings.bl || this.settings.br)
{ var newMainContainer = document.createElement("DIV"); newMainContainer.style.width = "100%"; newMainContainer.style.fontSize = "1px"; newMainContainer.style.overflow = "hidden"; newMainContainer.style.position = "absolute"; newMainContainer.style.paddingLeft = this.borderWidth + "px"; newMainContainer.style.paddingRight = this.borderWidth + "px"; var botMaxRadius = Math.max(this.settings.bl ? this.settings.bl.radius : 0, this.settings.br ? this.settings.br.radius : 0); newMainContainer.style.height = botMaxRadius + "px"; newMainContainer.style.bottom = 0 - botMaxRadius + "px"; newMainContainer.style.left = 0 - this.borderWidth + "px"; this.bottomContainer = this.box.appendChild(newMainContainer);}
break;}
}
if(this.topContainer) this.box.style.borderTopWidth = "0px"; if(this.bottomContainer) this.box.style.borderBottomWidth = "0px"; var corners = ["tr", "tl", "br", "bl"]; for(var i in corners)
{ if(i > -1 < 4)
{ var cc = corners[i]; if(!this.settings[cc])
{ if(((cc == "tr" || cc == "tl") && this.topContainer != null) || ((cc == "br" || cc == "bl") && this.bottomContainer != null))
{ var newCorner = document.createElement("DIV"); newCorner.style.position = "relative"; newCorner.style.fontSize = "1px"; newCorner.style.overflow = "hidden"; if(this.backgroundImage == "")
newCorner.style.backgroundColor = this.boxColour; else
newCorner.style.backgroundImage = this.backgroundImage; switch(cc)
{ case "tl":
newCorner.style.height = topMaxRadius - this.borderWidth + "px"; newCorner.style.marginRight = this.settings.tr.radius - (this.borderWidth*2) + "px"; newCorner.style.borderLeft = this.borderString; newCorner.style.borderTop = this.borderString; newCorner.style.left = -this.borderWidth + "px"; break; case "tr":
newCorner.style.height = topMaxRadius - this.borderWidth + "px"; newCorner.style.marginLeft = this.settings.tl.radius - (this.borderWidth*2) + "px"; newCorner.style.borderRight = this.borderString; newCorner.style.borderTop = this.borderString; newCorner.style.backgroundPosition = "-" + (topMaxRadius + this.borderWidth) + "px 0px"; newCorner.style.left = this.borderWidth + "px"; break; case "bl":
newCorner.style.height = botMaxRadius - this.borderWidth + "px"; newCorner.style.marginRight = this.settings.br.radius - (this.borderWidth*2) + "px"; newCorner.style.borderLeft = this.borderString; newCorner.style.borderBottom = this.borderString; newCorner.style.left = -this.borderWidth + "px"; newCorner.style.backgroundPosition = "-" + (this.borderWidth) + "px -" + (this.boxHeight + (botMaxRadius + this.borderWidth)) + "px"; break; case "br":
newCorner.style.height = botMaxRadius - this.borderWidth + "px"; newCorner.style.marginLeft = this.settings.bl.radius - (this.borderWidth*2) + "px"; newCorner.style.borderRight = this.borderString; newCorner.style.borderBottom = this.borderString; newCorner.style.left = this.borderWidth + "px"
newCorner.style.backgroundPosition = "-" + (botMaxRadius + this.borderWidth) + "px -" + (this.boxHeight + (botMaxRadius + this.borderWidth)) + "px"; break;}
}
}
else
{ if(this.masterCorners[this.settings[cc].radius])
{ var newCorner = this.masterCorners[this.settings[cc].radius].cloneNode(true);}
else
{ var newCorner = document.createElement("DIV"); newCorner.style.height = this.settings[cc].radius + "px"; newCorner.style.width = this.settings[cc].radius + "px"; newCorner.style.position = "absolute"; newCorner.style.fontSize = "1px"; newCorner.style.overflow = "hidden"; var borderRadius = parseInt(this.settings[cc].radius - this.borderWidth); for(var intx = 0, j = this.settings[cc].radius; intx < j; intx++)
{ if((intx +1) >= borderRadius)
var y1 = -1; else
var y1 = (Math.floor(Math.sqrt(Math.pow(borderRadius, 2) - Math.pow((intx+1), 2))) - 1); if(borderRadius != j)
{ if((intx) >= borderRadius)
var y2 = -1; else
var y2 = Math.ceil(Math.sqrt(Math.pow(borderRadius,2) - Math.pow(intx, 2))); if((intx+1) >= j)
var y3 = -1; else
var y3 = (Math.floor(Math.sqrt(Math.pow(j ,2) - Math.pow((intx+1), 2))) - 1);}
if((intx) >= j)
var y4 = -1; else
var y4 = Math.ceil(Math.sqrt(Math.pow(j ,2) - Math.pow(intx, 2))); if(y1 > -1) this.drawPixel(intx, 0, this.boxColour, 100, (y1+1), newCorner, -1, this.settings[cc].radius); if(borderRadius != j)
{ for(var inty = (y1 + 1); inty < y2; inty++)
{ if(this.settings.antiAlias)
{ if(this.backgroundImage != "")
{ var borderFract = (pixelFraction(intx, inty, borderRadius) * 100); if(borderFract < 30)
{ this.drawPixel(intx, inty, this.borderColour, 100, 1, newCorner, 0, this.settings[cc].radius);}
else
{ this.drawPixel(intx, inty, this.borderColour, 100, 1, newCorner, -1, this.settings[cc].radius);}
}
else
{ var pixelcolour = BlendColour(this.boxColour, this.borderColour, pixelFraction(intx, inty, borderRadius)); this.drawPixel(intx, inty, pixelcolour, 100, 1, newCorner, 0, this.settings[cc].radius, cc);}
}
}
if(this.settings.antiAlias)
{ if(y3 >= y2)
{ if (y2 == -1) y2 = 0; this.drawPixel(intx, y2, this.borderColour, 100, (y3 - y2 + 1), newCorner, 0, 0);}
}
else
{ if(y3 >= y1)
{ this.drawPixel(intx, (y1 + 1), this.borderColour, 100, (y3 - y1), newCorner, 0, 0);}
}
var outsideColour = this.borderColour;}
else
{ var outsideColour = this.boxColour; var y3 = y1;}
if(this.settings.antiAlias)
{ for(var inty = (y3 + 1); inty < y4; inty++)
{ this.drawPixel(intx, inty, outsideColour, (pixelFraction(intx, inty , j) * 100), 1, newCorner, ((this.borderWidth > 0)? 0 : -1), this.settings[cc].radius);}
}
}
this.masterCorners[this.settings[cc].radius] = newCorner.cloneNode(true);}
if(cc != "br")
{ for(var t = 0, k = newCorner.childNodes.length; t < k; t++)
{ var pixelBar = newCorner.childNodes[t]; var pixelBarTop = parseInt(pixelBar.style.top.substring(0, pixelBar.style.top.indexOf("px"))); var pixelBarLeft = parseInt(pixelBar.style.left.substring(0, pixelBar.style.left.indexOf("px"))); var pixelBarHeight = parseInt(pixelBar.style.height.substring(0, pixelBar.style.height.indexOf("px"))); if(cc == "tl" || cc == "bl"){ pixelBar.style.left = this.settings[cc].radius -pixelBarLeft -1 + "px";}
if(cc == "tr" || cc == "tl"){ pixelBar.style.top = this.settings[cc].radius -pixelBarHeight -pixelBarTop + "px";}
switch(cc)
{ case "tr":
pixelBar.style.backgroundPosition = "-" + Math.abs((this.boxWidth - this.settings[cc].radius + this.borderWidth) + pixelBarLeft) + "px -" + Math.abs(this.settings[cc].radius -pixelBarHeight -pixelBarTop - this.borderWidth) + "px"; break; case "tl":
pixelBar.style.backgroundPosition = "-" + Math.abs((this.settings[cc].radius -pixelBarLeft -1) - this.borderWidth) + "px -" + Math.abs(this.settings[cc].radius -pixelBarHeight -pixelBarTop - this.borderWidth) + "px"; break; case "bl":
pixelBar.style.backgroundPosition = "-" + Math.abs((this.settings[cc].radius -pixelBarLeft -1) - this.borderWidth) + "px -" + Math.abs((this.boxHeight + this.settings[cc].radius + pixelBarTop) -this.borderWidth) + "px"; break;}
}
}
}
if(newCorner)
{ switch(cc)
{ case "tl":
if(newCorner.style.position == "absolute") newCorner.style.top = "0px"; if(newCorner.style.position == "absolute") newCorner.style.left = "0px"; if(this.topContainer) this.topContainer.appendChild(newCorner); break; case "tr":
if(newCorner.style.position == "absolute") newCorner.style.top = "0px"; if(newCorner.style.position == "absolute") newCorner.style.right = "0px"; if(this.topContainer) this.topContainer.appendChild(newCorner); break; case "bl":
if(newCorner.style.position == "absolute") newCorner.style.bottom = "0px"; if(newCorner.style.position == "absolute") newCorner.style.left = "0px"; if(this.bottomContainer) this.bottomContainer.appendChild(newCorner); break; case "br":
if(newCorner.style.position == "absolute") newCorner.style.bottom = "0px"; if(newCorner.style.position == "absolute") newCorner.style.right = "0px"; if(this.bottomContainer) this.bottomContainer.appendChild(newCorner); break;}
}
}
}
var radiusDiff = new Array(); radiusDiff["t"] = Math.abs(this.settings.tl.radius - this.settings.tr.radius)
radiusDiff["b"] = Math.abs(this.settings.bl.radius - this.settings.br.radius); for(z in radiusDiff)
{ if(z == "t" || z == "b")
{ if(radiusDiff[z])
{ var smallerCornerType = ((this.settings[z + "l"].radius < this.settings[z + "r"].radius)? z +"l" : z +"r"); var newFiller = document.createElement("DIV"); newFiller.style.height = radiusDiff[z] + "px"; newFiller.style.width = this.settings[smallerCornerType].radius+ "px"
newFiller.style.position = "absolute"; newFiller.style.fontSize = "1px"; newFiller.style.overflow = "hidden"; newFiller.style.backgroundColor = this.boxColour; switch(smallerCornerType)
{ case "tl":
newFiller.style.bottom = "0px"; newFiller.style.left = "0px"; newFiller.style.borderLeft = this.borderString; this.topContainer.appendChild(newFiller); break; case "tr":
newFiller.style.bottom = "0px"; newFiller.style.right = "0px"; newFiller.style.borderRight = this.borderString; this.topContainer.appendChild(newFiller); break; case "bl":
newFiller.style.top = "0px"; newFiller.style.left = "0px"; newFiller.style.borderLeft = this.borderString; this.bottomContainer.appendChild(newFiller); break; case "br":
newFiller.style.top = "0px"; newFiller.style.right = "0px"; newFiller.style.borderRight = this.borderString; this.bottomContainer.appendChild(newFiller); break;}
}
var newFillerBar = document.createElement("DIV"); newFillerBar.style.position = "relative"; newFillerBar.style.fontSize = "1px"; newFillerBar.style.overflow = "hidden"; newFillerBar.style.backgroundColor = this.boxColour; newFillerBar.style.backgroundImage = this.backgroundImage; switch(z)
{ case "t":
if(this.topContainer)
{ if(this.settings.tl.radius && this.settings.tr.radius)
{ newFillerBar.style.height = topMaxRadius - this.borderWidth + "px"; newFillerBar.style.marginLeft = this.settings.tl.radius - this.borderWidth + "px"; newFillerBar.style.marginRight = this.settings.tr.radius - this.borderWidth + "px"; newFillerBar.style.borderTop = this.borderString; if(this.backgroundImage != "")
newFillerBar.style.backgroundPosition = "-" + (topMaxRadius + this.borderWidth) + "px 0px"; this.topContainer.appendChild(newFillerBar);}
this.box.style.backgroundPosition = "0px -" + (topMaxRadius - this.borderWidth) + "px";}
break; case "b":
if(this.bottomContainer)
{ if(this.settings.bl.radius && this.settings.br.radius)
{ newFillerBar.style.height = botMaxRadius - this.borderWidth + "px"; newFillerBar.style.marginLeft = this.settings.bl.radius - this.borderWidth + "px"; newFillerBar.style.marginRight = this.settings.br.radius - this.borderWidth + "px"; newFillerBar.style.borderBottom = this.borderString; if(this.backgroundImage != "")
newFillerBar.style.backgroundPosition = "-" + (botMaxRadius + this.borderWidth) + "px -" + (this.boxHeight + (topMaxRadius + this.borderWidth)) + "px"; this.bottomContainer.appendChild(newFillerBar);}
}
break;}
}
}
if(this.settings.autoPad == true && this.boxPadding > 0)
{ var contentContainer = document.createElement("DIV"); contentContainer.style.position = "relative"; contentContainer.innerHTML = this.boxContent; contentContainer.className = "autoPadDiv"; var topPadding = Math.abs(topMaxRadius - this.boxPadding); var botPadding = Math.abs(botMaxRadius - this.boxPadding); if(topMaxRadius < this.boxPadding)
contentContainer.style.paddingTop = topPadding + "px"; if(botMaxRadius < this.boxPadding)
contentContainer.style.paddingBottom = botMaxRadius + "px"; contentContainer.style.paddingLeft = this.boxPadding + "px"; contentContainer.style.paddingRight = this.boxPadding + "px"; this.contentDIV = this.box.appendChild(contentContainer);}
}
this.drawPixel = function(intx, inty, colour, transAmount, height, newCorner, image, cornerRadius)
{ var pixel = document.createElement("DIV"); pixel.style.height = height + "px"; pixel.style.width = "1px"; pixel.style.position = "absolute"; pixel.style.fontSize = "1px"; pixel.style.overflow = "hidden"; var topMaxRadius = Math.max(this.settings["tr"].radius, this.settings["tl"].radius); if(image == -1 && this.backgroundImage != "")
{ pixel.style.backgroundImage = this.backgroundImage; pixel.style.backgroundPosition = "-" + (this.boxWidth - (cornerRadius - intx) + this.borderWidth) + "px -" + ((this.boxHeight + topMaxRadius + inty) -this.borderWidth) + "px";}
else
{ pixel.style.backgroundColor = colour;}
if (transAmount != 100)
setOpacity(pixel, transAmount); pixel.style.top = inty + "px"; pixel.style.left = intx + "px"; newCorner.appendChild(pixel);}
}
function insertAfter(parent, node, referenceNode)
{ parent.insertBefore(node, referenceNode.nextSibling);}
function BlendColour(Col1, Col2, Col1Fraction)
{ var red1 = parseInt(Col1.substr(1,2),16); var green1 = parseInt(Col1.substr(3,2),16); var blue1 = parseInt(Col1.substr(5,2),16); var red2 = parseInt(Col2.substr(1,2),16); var green2 = parseInt(Col2.substr(3,2),16); var blue2 = parseInt(Col2.substr(5,2),16); if(Col1Fraction > 1 || Col1Fraction < 0) Col1Fraction = 1; var endRed = Math.round((red1 * Col1Fraction) + (red2 * (1 - Col1Fraction))); if(endRed > 255) endRed = 255; if(endRed < 0) endRed = 0; var endGreen = Math.round((green1 * Col1Fraction) + (green2 * (1 - Col1Fraction))); if(endGreen > 255) endGreen = 255; if(endGreen < 0) endGreen = 0; var endBlue = Math.round((blue1 * Col1Fraction) + (blue2 * (1 - Col1Fraction))); if(endBlue > 255) endBlue = 255; if(endBlue < 0) endBlue = 0; return "#" + IntToHex(endRed)+ IntToHex(endGreen)+ IntToHex(endBlue);}
function IntToHex(strNum)
{ base = strNum / 16; rem = strNum % 16; base = base - (rem / 16); baseS = MakeHex(base); remS = MakeHex(rem); return baseS + '' + remS;}
function MakeHex(x)
{ if((x >= 0) && (x <= 9))
{ return x;}
else
{ switch(x)
{ case 10: return "A"; case 11: return "B"; case 12: return "C"; case 13: return "D"; case 14: return "E"; case 15: return "F";}
}
}
function pixelFraction(x, y, r)
{ var pixelfraction = 0; var xvalues = new Array(1); var yvalues = new Array(1); var point = 0; var whatsides = ""; var intersect = Math.sqrt((Math.pow(r,2) - Math.pow(x,2))); if ((intersect >= y) && (intersect < (y+1)))
{ whatsides = "Left"; xvalues[point] = 0; yvalues[point] = intersect - y; point = point + 1;}
var intersect = Math.sqrt((Math.pow(r,2) - Math.pow(y+1,2))); if ((intersect >= x) && (intersect < (x+1)))
{ whatsides = whatsides + "Top"; xvalues[point] = intersect - x; yvalues[point] = 1; point = point + 1;}
var intersect = Math.sqrt((Math.pow(r,2) - Math.pow(x+1,2))); if ((intersect >= y) && (intersect < (y+1)))
{ whatsides = whatsides + "Right"; xvalues[point] = 1; yvalues[point] = intersect - y; point = point + 1;}
var intersect = Math.sqrt((Math.pow(r,2) - Math.pow(y,2))); if ((intersect >= x) && (intersect < (x+1)))
{ whatsides = whatsides + "Bottom"; xvalues[point] = intersect - x; yvalues[point] = 0;}
switch (whatsides)
{ case "LeftRight":
pixelfraction = Math.min(yvalues[0],yvalues[1]) + ((Math.max(yvalues[0],yvalues[1]) - Math.min(yvalues[0],yvalues[1]))/2); break; case "TopRight":
pixelfraction = 1-(((1-xvalues[0])*(1-yvalues[1]))/2); break; case "TopBottom":
pixelfraction = Math.min(xvalues[0],xvalues[1]) + ((Math.max(xvalues[0],xvalues[1]) - Math.min(xvalues[0],xvalues[1]))/2); break; case "LeftBottom":
pixelfraction = (yvalues[0]*xvalues[1])/2; break; default:
pixelfraction = 1;}
return pixelfraction;}
function rgb2Hex(rgbColour)
{ try{ var rgbArray = rgb2Array(rgbColour); var red = parseInt(rgbArray[0]); var green = parseInt(rgbArray[1]); var blue = parseInt(rgbArray[2]); var hexColour = "#" + IntToHex(red) + IntToHex(green) + IntToHex(blue);}
catch(e){ alert("There was an error converting the RGB value to Hexadecimal in function rgb2Hex");}
return hexColour;}
function rgb2Array(rgbColour)
{ var rgbValues = rgbColour.substring(4, rgbColour.indexOf(")")); var rgbArray = rgbValues.split(", "); return rgbArray;}
function setOpacity(obj, opacity)
{ opacity = (opacity == 100)?99.999:opacity; if(isSafari && obj.tagName != "IFRAME")
{ var rgbArray = rgb2Array(obj.style.backgroundColor); var red = parseInt(rgbArray[0]); var green = parseInt(rgbArray[1]); var blue = parseInt(rgbArray[2]); obj.style.backgroundColor = "rgba(" + red + ", " + green + ", " + blue + ", " + opacity/100 + ")";}
else if(typeof(obj.style.opacity) != "undefined")
{ obj.style.opacity = opacity/100;}
else if(typeof(obj.style.MozOpacity) != "undefined")
{ obj.style.MozOpacity = opacity/100;}
else if(typeof(obj.style.filter) != "undefined")
{ obj.style.filter = "alpha(opacity:" + opacity + ")";}
else if(typeof(obj.style.KHTMLOpacity) != "undefined")
{ obj.style.KHTMLOpacity = opacity/100;}
}
function inArray(array, value)
{ for(var i = 0; i < array.length; i++){ if (array[i] === value) return i;}
return false;}
function inArrayKey(array, value)
{ for(key in array){ if(key === value) return true;}
return false;}
function addEvent(elm, evType, fn, useCapture) { if (elm.addEventListener) { elm.addEventListener(evType, fn, useCapture); return true;}
else if (elm.attachEvent) { var r = elm.attachEvent('on' + evType, fn); return r;}
else { elm['on' + evType] = fn;}
}
function removeEvent(obj, evType, fn, useCapture){ if (obj.removeEventListener){ obj.removeEventListener(evType, fn, useCapture); return true;} else if (obj.detachEvent){ var r = obj.detachEvent("on"+evType, fn); return r;} else { alert("Handler could not be removed");}
}
function format_colour(colour)
{ var returnColour = "#ffffff"; if(colour != "" && colour != "transparent")
{ if(colour.substr(0, 3) == "rgb")
{ returnColour = rgb2Hex(colour);}
else if(colour.length == 4)
{ returnColour = "#" + colour.substring(1, 2) + colour.substring(1, 2) + colour.substring(2, 3) + colour.substring(2, 3) + colour.substring(3, 4) + colour.substring(3, 4);}
else
{ returnColour = colour;}
}
return returnColour;}
function get_style(obj, property, propertyNS)
{ try
{ if(obj.currentStyle)
{ var returnVal = eval("obj.currentStyle." + property);}
else
{ if(isSafari && obj.style.display == "none")
{ obj.style.display = ""; var wasHidden = true;}
var returnVal = document.defaultView.getComputedStyle(obj, '').getPropertyValue(propertyNS); if(isSafari && wasHidden)
{ obj.style.display = "none";}
}
}
catch(e)
{ }
return returnVal;}
function getElementsByClass(searchClass, node, tag)
{ var classElements = new Array(); if(node == null)
node = document; if(tag == null)
tag = '*'; var els = node.getElementsByTagName(tag); var elsLen = els.length; var pattern = new RegExp("(^|\s)"+searchClass+"(\s|$)"); for (i = 0, j = 0; i < elsLen; i++)
{ if(pattern.test(els[i].className))
{ classElements[j] = els[i]; j++;}
}
return classElements;}
function newCurvyError(errorMessage)
{ return new Error("curvyCorners Error:\n" + errorMessage)
}
