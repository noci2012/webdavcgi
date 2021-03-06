/*********************************************************************
(C) ZE CMS, Humboldt-Universitaet zu Berlin
Written 2014 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
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
$(document).ready(function() {
	$("body").on("fileActionEvent", function(event,data) {
		if (data.obj.hasClass("odfconvert")) {
			ToolBox.hidePopupMenu();
			var p = window.location.pathname;
			var xhr = $.MyPost(p,{ action:"odfconvert", file:data.file, ct:data.obj.data("ct")}, function(response) {
				ToolBox.handleJSONResponse(response);
				if (p==window.location.pathname) {
					ToolBox.updateFileList();
					
				}
			});
			ToolBox.renderAbortDialog(xhr);
		}
	});
});