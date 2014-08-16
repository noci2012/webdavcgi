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
	function initRedirect() {
		$("#fileList tr.redirect")
			.off('click').off('click.initFileList').off('dblclick').off('dblclick.initFileList')
			.off('keydown').off('keydown.flctr')
			.on('dblclick', function(e) {
				ToolBox.preventDefault(e);
				window.location.href = $('.filename a',$(this)).attr("href");
			})
			.on('keydown', function(e) {
				if (e.which == 13) window.location.href = $('.filename a',$(this)).attr("href");
			});
	
		$("#fileList tr.redirect .action.changeuri").removeClass('changeuri').off('click').click(function(e) {
			ToolBox.preventDefault(e);
			window.location.href = $(this).attr("href");
		});
	
	}
	$("#flt").on("fileListChanged", initRedirect);
	initRedirect();
});