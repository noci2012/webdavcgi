/*********************************************************************
(C) ZE CMS, Humboldt-Universitaet zu Berlin
Written by Daniel Rohde <d.rohde@cms.hu-berlin.de>
**********************************************************************
This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
**********************************************************************/
(function ( $ ) {
	$.fn.MyPopup = function(options) {
		var popup = this;

		if (options === "close") return hidePopup();

		var settings = $.extend( {
			namespace: "popupnavigation",
			timername: "popupnavigationtimer",
			contextmenu: undefined,
			contextmenuTarget: undefined,
			contextmenuAnchor: undefined,
			contextmenuAnchorElement: false,
			alloworigcontextmenu : true,
			showEvent: undefined,
			autohide : true,
		}, options);

		function adjustContextMenuPosition(event, el) {
			var offset, left, top;
			if (settings.contextmenuAnchorElement) {
				el = $(settings.contextmenuAnchor);
				offset = el.offset() ;
				left = event.pageX - offset.left + el.scrollLeft();
				top  = event.pageY - offset.top + el.scrollTop();
			} else {
				offset = $(settings.contextmenuAnchor).position();
				left = (event.pageX-offset.left);
				top = (event.pageY-offset.top);
				//var win = $(window);
				//var popupHeight = popup.height();
				//var popupWidth = popup.width();
				//if (popupHeight + top - win.scrollTop() + offset.top > win.height() && top-popupHeight>= $("#top").height()) top-=popupHeight;
				//if (popupWidth + left - win.scrollLeft() + offset.left > win.width() && left-popupWidth>= 0) left-=popupWidth;	
			}
			settings.contextmenu.css({"top":top+"px","left":left+"px"});
		}
		if (settings.contextmenu) {
			var contextmenu = settings.contextmenu;
			popup.data("MyPopup.contextmenu", contextmenu);
			settings.contextmenuTarget.off("contextmenu."+settings.namespace)
				.on("contextmenu."+settings.namespace, function(event) {
					if (event.which==3) {
						if (event.originalEvent.detail === 2 && settings.alloworigcontextmenu) {
							hidePopup();
							return;
						}
						if (!settings.alloworigcontextmenu) preventDefault(event);
						if (contextmenu.is(":visible") && contextmenu.parent()[0] == $(this)[0]) {
							hidePopup();
						} else {
							preventDefault(event);
							$(".MyPopup-autohide ul.popup:visible").hide();
							$("ul.popup:visible", popup).hide();
							contextmenu.appendTo($(this)).css({position: "absolute", opacity: 1}).show();
							adjustContextMenuPosition(event, $(this));
							if (settings.showEvent) settings.showEvent.call(this);
						}
					}
				});
		}
		
		/* IDEA: don't close a popup if a popup was leaved or lost focus -> look at siblings */
		function preventDefault(event) {
			if (event.preventDefault) event.preventDefault(); else event.returnValue = false;
			if (event.stopPropagation) event.stopPropagation();
		}
		function hidePopup() {
			$("ul.popup:visible",popup).hide();
			if (popup.data("MyPopup.contextmenu")) popup.data("MyPopup.contextmenu").hide().appendTo("body");
			return popup;
		}
		function toggle_popup(obj, toggle) {
			if (obj.hasClass("disabled")) return obj;
			$("ul.popup:first", obj).toggle(toggle);
			if (!$("ul.popup:first", obj).is(":visible")) {
				$("ul.popup", obj).hide(); /* hide all sub popups */
			}
			return obj;
		}
		function clear_timeout(obj) {
			window.clearTimeout($("body").data(settings.timername));
			return obj;
		}
		function hide_siblings(obj) {
			clear_timeout(obj);
			$("ul.popup:visible", obj.siblings("li.popup")).hide();
			//obj.siblings("li.popup").find("ul.popup:visible").hide();
			return obj;
		}

		popup.filter(":not(.popup-click)").off("."+settings.namespace).on("mouseenter."+settings.namespace, function() { /* show popup if mouse entered it and after a little timeout */
			var self = $(this);
			clear_timeout(self);
			$("body").data(settings.timername,
					window.setTimeout(function() {
						toggle_popup(hide_siblings(self), true);
					}, 350)
			);
		}).on("click."+settings.namespace, function(ev) {
			preventDefault(ev);
			$("ul.popup:first:visible", $(".MyPopup-autohide").not(popup)).hide();
			var self = $(this);
			toggle_popup(hide_siblings(clear_timeout(self)));
			$(":focusable:first",self).focus();
		}).on("dblclick."+settings.namespace, function(ev) {
			preventDefault(ev);
		}).MyKeyboardEventHandler();

		/* clean up all events for .popup-click popups and handle click separately:*/
		popup.filter(".popup-click").off("."+settings.namespace).on("click."+settings.namespace, function(ev) {
			preventDefault(ev);
			$("ul.popup:first:visible", $(".MyPopup-autohide").not(popup)).hide();
			toggle_popup(hide_siblings($(this)));
		}).on("dblclick."+settings.namespace, function(ev) {
			preventDefault(ev);
		}).MyKeyboardEventHandler();

		/* close siblings on focus change: */
		popup.on("focus."+settings.namespace, function() {
			hide_siblings($(this));
		});

		/* close popups if siblings in navigation are entered or clicked:*/
		popup.siblings(":not(.popup)").off("."+settings.namespace).on("focus."+settings.namespace+" click."+settings.namespace+" mouseenter."+settings.namespace, function() {
			hide_siblings($(this));
		});
		/* don't close siblings on mouseenter if a popup menu is a .popup-click popup: */
		popup.filter(".popup-click").siblings("li:not(.popup)").off("mouseenter."+settings.namespace);

		
		if (settings.autohide) {
			popup.addClass("MyPopup-autohide");
			if (settings.contextmenu) settings.contextmenu.addClass("MyPopup-autohide");
			$("body").on("click."+settings.namespace+" contextmenu."+settings.namespace, function(event) {
				if ($(event.target).closest(popup).length != 1 ) hidePopup();
			}).on("keydown."+settings.namespace, function(event) {
				if (event.keyCode == 27) {
					hidePopup();
				}
			});
		}
		return popup;
	};
}( jQuery ));
