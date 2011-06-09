#!/usr/bin/perl
#########################################################################
# (C) ZE CMS, Humboldt-Universitaet zu Berlin
# Written 2010-2011 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
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

package WebInterface::Common;

use strict;

use POSIX qw( ceil );
sub new {
	my $this = shift;
	my $class = ref($this) || $this;
	my $self = { };
	bless $self, $class;
	$$self{config}=shift;
	$self->initialize();
	return $self;
}

sub initialize() {
	my $self = shift;
	$$self{cgi} = $$self{config}->getProperty('cgi');
	$$self{backend} = $$self{config}->getProperty('backend');
	$$self{utils} = $$self{config}->getProperty('utils');

	$main::LANG = $$self{cgi}->param('lang') || $$self{cgi}->cookie('lang') || $main::LANG || 'default';
	$main::ORDER = $$self{cgi}->param('order') || $$self{cgi}->cookie('order') || $main::ORDER || 'name';
	$main::PAGE_LIMIT = $$self{cgi}->param('pagelimit') || $$self{cgi}->cookie('pagelimit') || $main::PAGE_LIMIT;
	$main::PAGE_LIMIT = ceil($main::PAGE_LIMIT) if defined $main::PAGE_LIMIT;
	@main::PAGE_LIMITS = ( 5, 10, 15, 20, 25, 30, 50, 100, -1 ) unless defined @main::PAGE_LIMITS;
	unshift @main::PAGE_LIMITS, $main::PAGE_LIMIT if defined $main::PAGE_LIMIT && $main::PAGE_LIMIT > 0 && grep(/\Q$main::PAGE_LIMIT\E/, @main::PAGE_LIMITS) <= 0 ;

	$main::VIEW = $$self{cgi}->param('view') || $$self{cgi}->cookie('view') || $main::VIEW || ($main::ENABLE_SIDEBAR ? 'sidebar' : 'classic');
	$main::VIEW = 'classic' unless $main::ENABLE_SIDEBAR ;

}

sub readTL  {
        my ($self,$l) = @_;
        my $fn = -e "${main::INSTALL_BASE}webdav-ui_${l}.msg" ? "${main::INSTALL_BASE}webdav-ui_${l}.msg" : -e "${main::INSTALL_BASE}locale/webdav-ui_${l}.msg" ? "${main::INSTALL_BASE}locale/webdav-ui_${l}.msg" : undef;
        return unless defined $fn;
        if (open(my $i, "<$fn")) {
                while (my $line = <$i>) {
                        chomp($line);
                        next if $line=~/^#/;
                        $main::TRANSLATION{$l}{$1}=$2 if $line=~/^(\S+)\s+"(.*)"\s*$/;
                }
                close($i);
        } else { warn("Cannot read $fn!"); }
        $main::TRANSLATION{$l}{x__READ__x}=1;
}
sub tl {
        my $self = shift;
        my $key = shift;
        $self->readTL('default') if !exists $main::TRANSLATION{default}{x__READ__x};
        $self->readTL($main::LANG) if !exists $main::TRANSLATION{$main::LANG}{x__READ__x};
        my $val = $main::TRANSLATION{$main::LANG}{$key} || $main::TRANSLATION{default}{$key} || $key;
        return $#_>-1 ? sprintf( $val, @_) : $val;
}

1;
