#########################################################################
# (C) ZE CMS, Humboldt-Universitaet zu Berlin
# Written 2014 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
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
# Simple CSS highlighting for file list entries
# SETUP:
# namespace - XML namespace for attributes (default: {https://DanRohde.github.io/webdavcgi/extension/Highlighter/$REMOTE_USER})
# attributes - CSS attributes to change for a file list entry
# maxpresetentries - number of entries in the preset entry menu (default: 5)
# disable_popup - disables Highlighter menu in context menu
# disable_filelistaction - disables Highlighter menu button on toolbar

package WebInterface::Extension::Highlighter;

use strict;
use warnings;

our $VERSION = '2.0';

use base qw( WebInterface::Extension );

use JSON;

use DefaultConfig qw( $PATH_TRANSLATED $REMOTE_USER $DOCUMENT_ROOT );
use HTTPHelper qw( print_compressed_header_and_content );

use vars qw(%_CACHE);

sub init {
    my ( $self, $hookreg ) = @_;
    my @hooks
        = qw(css locales javascript posthandler fileattr appsmenu );

    if (!$self->config('disable_popup', 0)) {
        push @hooks, 'fileactionpopup';
    }
    if (!$self->config('disable_filelistaction', 1)) {
        push @hooks, 'filelistaction';
    }

    $hookreg->register( \@hooks, $self );

    $self->{namespace} = $self->config( 'namespace',
              '{https://DanRohde.github.io/webdavcgi/extension/Highlighter/'
            . $REMOTE_USER
            . '}' );
    $self->{presets}
        = { name => $self->{namespace} . 'presets', root => $DOCUMENT_ROOT };
    $self->{maxpresetentries} = $self->config('maxpresetentries', 5);
    $self->{style}  = { name => $self->{namespace} . 'style' };
    $self->{attributes} = $self->config(
        'attributes',
        {
            'background-color' => {
                values => '#F07E50/#ADFF2F/#ADD8E6/#FFFF00/#EE82EE',
                style  => 'background-color',
                labelcss =>
                    'font-size: 8px; height: 12px; line-height: 10px;',
                colorpicker => 1,
                order       => 1,
                classes     => 'sep',
            },
            'color' => {
                values => '#FF0000/#00FF00/#0000FF/#FFA500/#A020E0',
                style  => 'color',
                labelcss =>
                    'color: white; font-weight: bold; font-size: 8px; line-height: 10px;',
                labelstyle  => 'background-color',
                colorpicker => 1,
                order       => 2,
            },
            'border' => {
                popup => {
                    'border-color' => {
                        values => '#FF0000/#00FF00/#0000FF/#FFA500/#A020E0',
                        style  => 'border-color',
                        labelstyle => 'background-color',
                        labelcss =>
                            'border-style: solid; border-width: 1px;color: white; font-weight: bold;font-size: 8px; line-height: 10px;',
                        colorpicker => 1,
                        order       => 1,
                    },
                    'border-width' => {
                        values => 'thin/medium/thick',
                        style  => 'border-width',
                        labelcss =>
                            'border-style: solid; border-color: black;',
                        order => 2,
                    },
                    'border-style' => {
                        values =>
                            'dotted/dashed/solid/double/groove/ridge/inset/outset',
                        style    => 'border-style',
                        labelcss => 'border-color: gray; border-width: 3px;',
                        order    => 3,
                    }
                },
                order => 3,
            },
            'font' => {
                popup => {
                    'font-size' => {
                        values =>
                            'xx-large/x-large/larger/large/medium/small/smaller/x-small/xx-small',
                        style => 'font-size',
                        order => 1,
                    },
                    'font-style' => {
                        values => 'lighter/bold/bolder/italic/oblique',
                        styles => {
                            italic   => 'font-style',
                            oblique  => 'font-style',
                            _default => 'font-weight'
                        },
                        order => 2,
                    },
                    'font-family' => {
                        values =>
                            'serif/sans-serif/cursive/fantasy/monospace',
                        style => 'font-family',
                        order => 2,
                    },
                },
                order => 10,
            },
            'text' => {
                popup => {
                    'text-transform' => {
                        values => 'lowercase/uppercase/capitalize/small-caps',
                        styles => {
                            _default     => 'text-transform',
                            'small-caps' => 'font-variant'
                        },
                        order  => 1,
                    },
                    'text-shadow' => {
                        values => '1px 1px 1px #888/2px 2px 16px #ffd700/2px -2px 16px rgba(0,0,0,0.7)/-1px -1px 1px #000,1px 1px 1px #fff/-1px -1px 1px #fff,1px 1px 1px #000',
                        style  => 'text-shadow',
                        order  => 2,
                    },
                    'text-align' => {
                        values => 'space-between/center/flex-end',
                        style  => 'justify-content',
                        order  => 3,  
                    },
                    'text-decoration' => {
                        values =>
                            'underline/overline/line-through/underline overline/overline underline line-through/underline line-through/overline line-through',
                        style => 'text-decoration',
                        order => 4,
                    },
                    'text-decoration-color' => {
                        values => '#FF0000/#00FF00/#0000FF/#FFA500/#A020E0',
                        style  => 'text-decoration-color',
                        labelstyle => 'background-color',
                        labelcss =>
                            'color: white; font-weight: bold;font-size: 8px; line-height: 10px;',
                        colorpicker => 1,
                        order       => 5,
                    },
                    'text-decoration-style' => {
                        values   => 'solid/double/dotted/dashed/wavy',
                        style    => 'text-decoration-style',
                        labelcss => 'text-decoration-line: underline;',
                        order    => 6,
                    },
                },
                order => 15,
            },
            'fun' => {
                popup => {
                    'gradient' => {
                        values => 'linear-gradient(black,white,black)/linear-gradient(42deg, transparent, blue)/linear-gradient(to right, red, orange, yellow, green, blue, indigo, violet)'
                                    .'/linear-gradient(red, yellow, green)/radial-gradient(red, yellow, green)'
                                    .'/linear-gradient(black 33.3%, red 33.3%, red 66.6%, gold 66.6%)/linear-gradient(to right, #0055a4 33.3%, white 33.3%, white 66.6%, #ef4531 66.6%)'
                                    .'/linear-gradient(to right, #006221 33.3%, white 33.3%, white 66.6%,  #df0024 66.6%)/linear-gradient(#ce1126 33.3%, white 33.3%, white 66.6%, #008751 66.6%)'
                        ,
                        style  => 'background',
                        order  =>1,
                    },
                    'transform' => {
                        values => 'rotateX(180deg)/rotateY(180deg)/rotateZ(180deg)/skewX(30deg)/skewX(-30deg)/skewY(5deg)',
                        style  => 'transform',
                        order  => 2,
                    },
                    'animation' => {
                        values   => 'fontsize 4s linear infinite/paddingleft 4s linear infinite'
                                    .'/colorcycle 8s linear infinite/bgcolorcycle 8s linear infinite'
                                    .'/borderwidth 4s linear infinite/bordercolorcycle 8s linear infinite'
                                    ,
                        style    => 'animation',
                        labelcss => 'border-color: #666;', 
                        order    => 3,
                    },
                },
                order => 20,
            }
        }
    );
    $self->{json} = JSON->new();
    return $self;
}

sub handle_hook_javascript {
    my ( $self, $config, $params ) = @_;
    if ( my $ret = $self->SUPER::handle_hook_javascript( $config, $params ) )
    {
        $ret .= $self->SUPER::handle_hook_javascript( $config,
            { file => 'htdocs/contrib/iris.min.js' } );
        return $ret;
    }
    return 0;
}

sub _handle_mark_requests {
    my ( $self, $action ) = @_;
    if ( $action eq 'mark' ) {
        return $self->_save_property();
    }
    elsif ( $action eq 'removemarks' ) {
        return $self->_remove_all_properties();
    }
    elsif ( $action eq 'replacemarks' ) {
        return $self->_replace_properties();
    }
}

sub _handle_preset_requests {
    my ( $self, $action ) = @_;
    if ( $action eq 'savemarksaspreset' ) {
        return $self->_save_preset();
    } elsif ( $action eq 'deletepreset' ) {
        return $self->_delete_preset();
    }
    return 0;
}

sub handle_hook_posthandler {
    my ( $self, $config, $params ) = @_;
    my $action = $self->{cgi}->param('action') // q{};
    return $self->_handle_mark_requests($action)
        || $self->_handle_preset_requests($action);
}
sub _delete_preset {
    my ($self) = @_;
    my $presets = $self->_get_presets();
    my $preset = $self->{cgi}->param('preset');
    delete $presets->{$preset};
    $self->{db}->db_updateProperty($self->{presets}{root}, $self->{presets}{name}, $self->{json}->encode($presets));
    my %jsondata = ();
    print_compressed_header_and_content(
        '200 OK', 'application/json',
        $self->{json}->encode( \%jsondata ),
        'Cache-Control: no-cache, no-store'
    );
    return 1;
}
sub _save_preset {
    my ($self)  = @_;
    my $presets = $self->_get_presets();
    my $pc      = keys %{$presets};
    my $name    = $self->{cgi}->param('name');
    my $data    = $self->{cgi}->param('data');
    $name =~ s/^\s+//xmsg;
    $name =~ s/\s+$//xmsg;
    $data =~ s/^\s+//xmsg;
    $data =~ s/\s+$//xmsg;

    if ( $data eq q{} || $name eq q{} ) {
        return 1;
    }
    $presets->{$name} = $data;
    my $ret;
    if ( $pc > 0 ) {
        $ret = $self->{db}->db_updateProperty(
            $self->{presets}{root},
            $self->{presets}{name},
            $self->{json}->encode($presets)
        );
    }
    else {
        $ret = $self->{db}->db_insertProperty(
            $self->{presets}{root},
            $self->{presets}{name},
            $self->{json}->encode($presets)
        );
    }
    my %jsondata = ();
    if ( $ret ) {
        $jsondata{message} = sprintf $self->tl('highlighter.presetsaved'), $name;
    } else {
        $jsondata{error} = sprintf $self->tl(
            'highlighter.savepresetfailed'
        ), $name;
    }
    print_compressed_header_and_content(
        '200 OK', 'application/json',
        $self->{json}->encode( \%jsondata ),
        'Cache-Control: no-cache, no-store'
    );
    return 1;
}

sub _quote {
    my ( $self, $s ) = @_;
    $s =~ s/\s+/_/xmsg;
    return $s;
}

sub _get_style {
    my ( $self, $attribute, $val ) = @_;
    return $attribute->{styles}
        ? $attribute->{styles}{$val} // $attribute->{styles}{_default}
        : $attribute->{style};
}

sub _create_popup {
    my ( $self, $attrname, $attribute ) = @_;
    my @popup = ();
    if ( $attribute->{popup} ) {
        return $self->_create_popups( $attribute->{popup}, 0, $attrname );
    }
    else {
        @popup = map {
            {   action => 'mark',
                attr   => {
                    style => ( $attribute->{labelcss} // q{} )
                        . (
                        $attribute->{labelstyle}
                            // $self->_get_style( $attribute, $_ )
                        )
                        . ": $_;",
                    tabindex => 0,
                },
                data => {
                    value => $_,
                    style => $self->_get_style( $attribute, $_ )
                },
                label => $self->tl(
                    $attribute->{label}
                        // "highlighter.$attrname." . $self->_quote($_),
                    $_
                ),
                title => $self->_get_style($attribute,$_).q{: }.$self->tl(
                    "highlighter.$attrname.title." . $self->_quote($_), $_
                ),
                type    => 'li',
                classes => $attrname,
            }
        } split( /\//xms, $attribute->{values} );
        if ( $attribute->{colorpicker} ) {
            push @popup,
                {
                action  => 'markcolorpicker',
                data    => { value => $_, style => $attrname },
                label   => $self->tl('highlighter.colorpicker'),
                classes => 'sep',
                type    => 'li',
                attr    => { tabindex => 0, },
                };
        }
        push @popup,
            {
            action => 'removemarks',
            data   => {
                styles => $attribute->{styles}
                ? join( q{,}, values %{ $attribute->{styles} } )
                : $attribute->{style} // $attrname
            },
            label   => $self->tl("highlighter.remove.$attrname"),
            type    => 'li',
            classes => 'sep',
            attr    => { tabindex => 0, },
            };
    }
    return \@popup;
}

sub _create_preset_popup {
    my ( $self, $presets ) = @_;
    my @popup      = ();
    my @presetkeys = sort keys %{$presets};
    if ( $#presetkeys < 0 ) {
        push @popup,
            {
            label   => $self->tl('highlighter.nopresets'),
            action  => 'hlnopresets',
            type    => 'li',
            classes => 'disabled',
            attr    => { tabindex => 0, },
            };
    }
    else {
        my $count = 0;
        my $p = \@popup;
        foreach my $preset (@presetkeys) {
            $count++;
            my $styles = $self->{json}->decode( $presets->{$preset} );
            my $style = join q{;}, map {"$_:$styles->{$_}"} keys %{$styles};
            if ($count > $self->{maxpresetentries}) {
                my @sp = ();
                push @{$p}, {
                    popup   => \@sp,
                    title   => $self->tl('highlighter.morepresets'),
                    type    => 'li',
                    classes => 'sep',
                    attr    => { tabindex => 0, },
                };
                $p = \@sp;
                $count = 1;
            }
            push @{$p},
                {
                action => 'markwithpreset',
                data =>
                    { style => $presets->{$preset}, presetname => $preset },
                label => $self->{cgi}->escapeHTML($preset),
                attr  => { style => $style, tabindex => 0, },
                type  => 'li',
                };
        }
    }
    push @popup,
        {
        action  => 'managepresets',
        data    => { presets => $self->{json}->encode($presets), template=>$self->read_template('presetmanager') },
        label   => $self->tl('highlighter.managepresets'),
        type    => 'li',
        classes => 'sep' . ( $#presetkeys < 0 ? ' disabled' : q{} ),
        attr    => { tabindex => 0,},
        };
    return \@popup;
}

sub _get_presets {
    my ( $self, $jsondata ) = @_;
    $jsondata //= $self->{db}
        ->db_getProperty( $self->{presets}{root}, $self->{presets}{name} );
    if ( $jsondata && $jsondata ne q{} ) {
        return $self->{json}->decode($jsondata);
    }
    return {};
}

sub _create_popups {
    my ( $self, $attributes, $top, $attrname ) = @_;
    my @popups = ();
    $attrname //= q{};
    if ($top) {
        push @popups,
            {
            title      => $self->tl('highlighter.preset'),
            popup      => $self->_create_preset_popup( $self->_get_presets() ),
            classes    => 'highlighter preset',
            subclasses => 'highlighter subpreset',
            attr       => { tabindex => 0, },
            };
    }
    foreach my $attribute (
        sort { $attributes->{$a}{order} <=> $attributes->{$b}{order} }
        keys %{$attributes} )
    {
        push @popups,
            {
            title   => $self->tl("highlighter.$attribute"),
            popup   => $self->_create_popup(
                $attribute, $attributes->{$attribute}
            ),
            classes => "highlighter $attribute ". ( $attributes->{$attribute}->{classes} // q{} ),
            attr    => { tabindex => 0, },
            };
    }
    if ($top) {
        my @propnames = @{ $self->_get_all_propnames($attributes) };
        push @popups,
            {
            action  => 'replacemarks',
            data    => { styles => join q{,}, @propnames },
            label   => $self->tl('highlighter.replacemarks'),
            type    => 'li',
            classes => 'sep',
            attr    => { tabindex => 0, },
            },
            {
            action => 'savemarksaspreset',
            classes => 'save-icon',
            data   => {
                styles => join( q{,}, @propnames ),
                name   => $self->tl('highlighter.presetname')
            },
            label => $self->tl('highlighter.savemarksaspreset'),
            type  => 'li',
            attr  => { tabindex => 0,},
            };
    }
    push @popups,
        {
        action => 'removemarks',
        data   => {
            styles => join q{,},
            @{ $self->_get_all_propnames($attributes) }
        },
        label   => $self->tl("highlighter.remove.$attrname", $self->tl('highlighter.removeallmarks')),
        type    => 'li',
        classes => 'sep',
        attr    => { tabindex => 0,},
        };
    return \@popups;
}

sub handle_hook_fileactionpopup {
    my ( $self, $config, $params ) = @_;
    return {
        title   => $self->tl('highlighter'),
        popup   => $self->_create_popups( $self->{attributes}, 1 ),
        classes => 'highlighter-popup'
    };
}
sub handle_hook_filelistaction {
    my ( $self, $config, $params ) = @_;
    return {
        nolabel => 1,
        title   => $self->tl('highlighter'),
        popup   => $self->_create_popups( $self->{attributes}, 1),
        classes => 'highlighter-popup uibutton sel-multi hideit toolbar-button',
    };
}
sub handle_hook_appsmenu {
    my ( $self, $config, $params ) = @_;
    return {
        label   => $self->tl('highlighter'),
        title   => $self->tl('highlighter'),
        popup   => $self->_create_popups( $self->{attributes}, 1),
        classes => 'highlighter-popup sel-multi hideit',
        attr    => { aria_label=> $self->tl('highlighter'), tabindex => 0,},
    };
}

sub _get_all_propnames {
    my ( $self, $attributes ) = @_;
    my @propnames  = ();
    my %propexists = ();
    foreach my $attr ( keys %{$attributes} ) {
        if ( $attributes->{$attr}{popup} ) {
            push @propnames,
                @{
                $self->_get_all_propnames(
                    $attributes->{$attr}{popup}
                )
                };
        }
        else {
            my @allnames
                = $attributes->{$attr}{styles}
                ? values %{ $attributes->{$attr}->{styles} }
                : $attributes->{$attr}{style};
            foreach my $propname (@allnames) {
                if ( !$propexists{$propname} ) {
                    push @propnames, $propname;
                    $propexists{$propname} = 1;
                }
            }
        }
    }
    return \@propnames;
}

sub handle_hook_fileattr {
    my ( $self, $config, $params ) = @_;

    my $path   = $self->{backend}->resolveVirt( ${$params}{path} );
    my $parent = $self->{backend}->getParent($path);
    if ( !exists $_CACHE{$self}{$parent} ) {
        $self->{db}->db_getProperties($parent);    ## fills the cache
        $self->{db}->db_getProperties( $self->{presets}{root} );
    }
    $_CACHE{$self}{$parent} = 1;
    my $data;
    if ( my $style
        = $self->{db}->db_getPropertyFromCache( $path, $self->{style}{name} )
        )
    {
        $data = $style;
    }
    else {
        my %jsondata = ();
        my @props;
        $_CACHE{$self}{propnames}
            //= $self->_get_all_propnames( $self->{attributes} );
        foreach my $prop ( @{ $_CACHE{$self}{propnames} } ) {
            my $propname = $self->{namespace} . $prop;
            if ( my $val
                = $self->{db}->db_getPropertyFromCache( $path, $propname ) )
            {
                $jsondata{$prop} = $val;
                push @props, $propname;
            }
        }
        if ( $#props >= 0 ) {
            $data = $self->{json}->encode( \%jsondata );
            $self->{db}->db_removeProperties( $path, @props );
            $self->{db}
                ->db_insertProperty( $path, $self->{style}{name}, $data );
        }
    }
    return defined $data
        ? {
        'ext_classes'    => 'highlighter-highlighted',
        'ext_attributes' => 'data-highlighter="'
            . $self->{cgi}->escapeHTML($data) . q{"}
        }
        : {};

}

sub _remove_all_properties {
    my ($self)   = @_;
    my %jsondata = ();
    my @files    = $self->get_cgi_multi_param('files');
    my @styles = split /,/xms, $self->{cgi}->param('styles');
    my $parent = $self->{backend}->getParent(
        $self->{backend}->resolveVirt( $PATH_TRANSLATED . $files[0] ) );
    $self->{db}->db_getProperties($parent);    ## fills the cache
    foreach my $file (@files) {
        my $full = $self->{backend}
            ->resolveVirt( $PATH_TRANSLATED . $self->_strip_slash($file) );
        if ( my $style
            = $self->{db}
            ->db_getPropertyFromCache( $full, $self->{style}{name} ) )
        {
            my $s = $self->{json}->decode($style);
            foreach my $ds (@styles) {
                delete $s->{$ds};
            }
            if ( scalar keys %{$s} > 0 ) {
                $self->{db}->db_updateProperty(
                    $full,
                    $self->{style}{name},
                    $self->{json}->encode($s)
                );
            }
            else {
                $self->{db}->db_removeProperty( $full, $self->{style}{name} );
            }
        }
    }
    print_compressed_header_and_content(
        '200 OK', 'application/json',
        $self->{json}->encode( \%jsondata ),
        'Cache-Control: no-cache, no-store'
    );
    return 1;
}

sub _save_property {
    my ($self)   = @_;
    my %jsondata = ();
    my $db       = $self->{db};
    my $cgi      = $self->{cgi};
    my $style = $cgi->param('style') // 'color';
    my $value = $cgi->param('value') // 'black';
    foreach my $file ( $self->get_cgi_multi_param('files') ) {
        my $full = $self->{backend}
            ->resolveVirt( $PATH_TRANSLATED . $self->_strip_slash($file) );
        my $result;
        if ( my $ps = $db->db_getProperty( $full, $self->{style}{name} ) ) {
            my $styles = $self->{json}->decode($ps);
            $styles->{$style} = $value;
            $result = $db->db_updateProperty(
                $full,
                $self->{style}{name},
                $self->{json}->encode($styles)
            );
        }
        else {
            $result = $db->db_insertProperty(
                $full,
                $self->{style}{name},
                $self->{json}->encode( { $style => $value } )
            );
        }
        if ( !$result ) {
            $jsondata{error}
                = sprintf $self->tl('highlighter.highlightingfailed'),
                $file;
            last;
        }
    }

    print_compressed_header_and_content(
        '200 OK', 'application/json',
        $self->{json}->encode( \%jsondata ),
        'Cache-Control: no-cache, no-store'
    );
    return 1;
}

sub _replace_properties {
    my ($self)       = @_;
    my $db           = $self->{db};
    my $style        = $self->{cgi}->param('style');
    my @allpropnames = @{ $self->_get_all_propnames( $self->{attributes} ) };
    my @props        = ();
    foreach my $file ( $self->get_cgi_multi_param('files') ) {
        my $full = $self->{backend}
            ->resolveVirt( $PATH_TRANSLATED . $self->_strip_slash($file) );
        $db->db_removeProperties( $full,
            map { $self->{namespace} . $_ } @allpropnames, 'style' );
        push @props, $full, $self->{style}{name}, $style;
    }
    my %jsondata = ();
    if ( $#props >= 0 ) {
        my $result = $db->db_insertProperties(@props);
        if ( !$result ) {
            $jsondata{error}
                = sprintf $self->tl('highlighter.highlightingfailed'), q{};
        }
    }
    print_compressed_header_and_content(
        '200 OK', 'application/json',
        $self->{json}->encode( \%jsondata ),
        'Cache-Control: no-cache, no-store'
    );
    return 1;
}

sub _strip_slash {
    my ( $self, $file ) = @_;
    $file =~ s/\/$//xms;
    return $file;
}
1;
