########################################################################
# (C) ZE CMS, Humboldt-Universitaet zu Berlin
# Written 2016 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
#########################################################################
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#########################################################################

package Requests::PROPPATCH;

use strict;
use warnings;

our $VERSION = '2.0';

use base qw( Requests::WebDAVRequest );

use English qw ( -no_match_vars );

use DefaultConfig qw( $PATH_TRANSLATED );
use HTTPHelper qw( print_header_and_content read_request_body );
use WebDAV::XMLHelper qw( create_xml simple_xml_parser );

sub handle {
    my ($self) = @_;
    $self->debug("_PROPPATCH: $PATH_TRANSLATED");

    my $cgi     = $self->{cgi};
    my $backend = $self->{backend};
    my $fn      = $PATH_TRANSLATED;
    if ( $backend->exists($fn) && !$self->is_allowed($fn) ) {
        return print_header_and_content('423 Locked');
    }
    if ( !$backend->exists($fn) ) {
        return print_header_and_content('404 Not Found');
    }
    my $xml = read_request_body();

    $self->debug("_PROPPATCH: REQUEST: $xml");
    my $dataref;
    if ( !eval { $dataref = simple_xml_parser($xml) } ) {
        carp("PROPPATCH: invalid XML request: ${EVAL_ERROR}");
        return print_header_and_content('400 Bad Request (invalid XML request)');
    }
    $self->{event}->broadcast( 'PROPPATCH', { file => $fn, data => $dataref } );
    my @resps    = ();
    my %resp_200 = ();
    my %resp_403 = ();

    $self->handle_property_request(
        $xml, $dataref,
        \%resp_200, \%resp_403
    );

    if ( defined $resp_200{href} ) { push @resps, \%resp_200; }
    if ( defined $resp_403{href} ) { push @resps, \%resp_403; }
    my $content = create_xml( { multistatus => { response => \@resps } } );
    $self->{event}->broadcast( 'PROPPATCHED', { file => $fn, data => $dataref } );
    $self->debug("_PROPPATCH: RESPONSE: $content");
    return print_header_and_content( '207 Multi-Status', 'text/xml', $content );
}

1;
