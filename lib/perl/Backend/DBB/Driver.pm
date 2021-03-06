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

package Backend::DBB::Driver;

use strict;
use warnings;

our $VERSION = '2.0';

use base qw( Backend::Helper );

use English qw( -no_match_vars );
use CGI::Carp;
use DBI qw( :sql_types );

use DefaultConfig qw( $BUFSIZE $DOCUMENT_ROOT $UMASK $BACKEND %BACKEND_CONFIG $PATH_TRANSLATED );
use File::Temp qw( tempfile tempdir );

use constant {
    TYPE_DIR  => 1,
    TYPE_FILE => 2,
    TYPE_LINK => 4,
};

use constant TYPES => qw ( TYPE_DIR TYPE_FILE TYPE_LINK );

use vars qw( $DB );

sub finalize {
    if ($DB) { $DB->disconnect(); }
    $DB = undef;
    return;
}

sub _initialize {
    my ($self) = @_;
    if ( !defined $DB ) {
        my $dsn = $BACKEND_CONFIG{$BACKEND}{dsn}
          // 'dbi:SQLite:dbname=/tmp/webdavcgi-dbdbackend-'
          . $ENV{REMOTE_USER} . '.db';
        my @parm = split /:/xms, $dsn;
        if ( scalar(@parm) == 3
            && ( ( uc( $parm[0] ) eq 'DBI' ) && ( $parm[1] eq 'SQLite' ) ) )
        {
            foreach my $tag ( split /[;]/xms, $parm[2] ) {
                if ( $tag =~ /^dbname=(.*)/xms ) {
                    $tag = $1;
                    if ( $tag ne q{} && ( !-e $tag ) ) {
                        open( my $FH, '>', $tag )
                          || croak "Can't create $tag: $ERRNO";
                        close($FH) || carp "Cannot close $tag.";
                    }
                }
            }
        }
        $DB = DBI->connect(
            $dsn,
            $BACKEND_CONFIG{$BACKEND}{user}     // q{},
            $BACKEND_CONFIG{$BACKEND}{password} // q{},
            { RaiseError => 0, AutoCommit => 1 }
        );
        if ( defined $DB ) {
            my $sth = $DB->prepare('SELECT name FROM objects');
            if ( !defined $sth ) {
                #$DB->rollback();
                $sth = $DB->prepare(
'CREATE TABLE objects (name varchar(255) NOT NULL, parent varchar(255) NOT NULL, type int NOT NULL, owner VARCHAR(255) NOT NULL, created timestamp NOT NULL, modified timestamp NOT NULL, size int NOT NULL, permissions int NOT NULL, data blob)'
                );
                $sth->execute();
                ##$DB->commit();
            }
        }
    }
    return $self;
}

sub readDir {
    my ( $self, $fn, $limit, $filter ) = @_;
    $self->_initialize();
    my @list;
    my $sth = $DB->prepare('SELECT name FROM objects WHERE parent = ?');
    print STDERR "readDir($fn) resolve($fn)".$self->resolve($fn)."\n";
    if ( $sth && $sth->execute( $self->resolve($fn) ) ) {
        my $data = $sth->fetchall_arrayref();
        foreach my $e ( @{$data} ) {
            last if defined $limit && $#list >= $limit;
            next if $self->filter( $filter, $fn, $e->[0] );
            push @list, $e->[0];
        }
    }
    else {
        #$DB->rollback();
    }
    return \@list;
}

sub unlinkFile {
    my ( $self, $fn ) = @_;
    $self->_initialize();
    $fn = $self->resolve($fn);
    my $sth = $DB->prepare('DELETE FROM objects WHERE name = ? AND parent = ?');
    if ( $sth && $sth->execute( $self->basename($fn), $self->getParent($fn) ) )
    {
        #$DB->commit();
        return 1;
    }
    else {
        #$DB->rollback();
    }
    return 0;
}

sub deltree {
    my ( $self, $fn ) = @_;
    $self->_initialize();
    $fn = $self->resolve($fn);
    my $sth =
      $DB->prepare('DELETE FROM objects WHERE parent = ? OR parent like ?');
    if ( $sth && $sth->execute( $fn, $fn . q{/%} ) ) {
        $sth =
          $DB->prepare('DELETE FROM objects WHERE name = ? AND parent = ?');
        if ($sth) {
            $sth->execute( $self->basename($fn), $self->getParent($fn) );
        }
        if ( $sth && !$sth->err ) {
            #$DB->commit();
            return 1;
        }
        else {
            #$DB->rollback();
        }
    }
    #$DB->rollback();
    return 0;
}

sub isLink {
    return $_[0]->_get_db_value( $_[1], 'type', -1 ) == TYPE_LINK;
}

sub isDir {
    return $_[0]->_is_root( $_[1] )
      || $_[0]->_get_db_value( $_[1], 'type', -1 ) == TYPE_DIR;
}

sub isFile {
    return !$_[0]->_is_root( $_[1] )
      && $_[0]->_get_db_value( $_[1], 'type', -1 ) == TYPE_FILE;
}

sub rename {
    my ( $self, $on, $nn ) = @_;
    $on = $self->resolve($on);
    $nn = $self->resolve($nn);
    return 0 if $self->isDir($on) && scalar( $self->readDir($on) ) > 0;
    my $sth = $DB->prepare(
        'UPDATE objects SET name = ?, parent = ? WHERE name = ? AND parent = ?'
    );
    $self->unlinkFile($nn);
    if (
        $sth
        && $sth->execute(
            $self->basename($nn), $self->getParent($nn),
            $self->basename($on), $self->getParent($on)
        )
      )
    {
        #$DB->commit();
        return 1;
    }
    else {
        #$DB->rollback();
    }
    return 0;
}

sub copy {
    my ( $self, $src, $dst ) = @_;
    $src = $self->resolve($src);
    $dst = $self->resolve($dst);
    my $v = $self->_get_db_entry( $src, 1 );
    return $self->exists($dst)
      ? $self->_change_db_entry( $dst, $v->{ $self->basename($src) }{data} )
      : $self->_add_db_entry( $dst, TYPE_FILE,
        $v->{ $self->basename($src) }{data} );
}

sub mkcol {
    return $_[0]->exists( $_[1] ) ? 0 : $_[0]->_add_db_entry( $_[1], TYPE_DIR );
}

sub isReadable   { return 1; }
sub isWriteable  { return 1; }
sub isExecutable { return $_[0]->isDir( $_[1] ); }

sub hasSetUidBit  { return 0; }
sub hasSetGidBit  { return 0; }
sub changeMod     { return 0; }
sub isBlockDevice { return 0; }
sub isCharDevice  { return 0; }
sub getLinkSrc    { return; }
sub createSymLink { return 0; }
sub hasStickyBit  { return 0; }

sub exists {
    my ( $self, $fn ) = @_;
    return 1 if $self->_is_root($fn);
    $fn = $self->resolve($fn);
    my $h = $self->_get_db_entry($fn);
    return defined $h && exists $h->{ $self->basename($fn) };
}

sub stat {
    my ( $self, $fn ) = @_;
    return ( 0, 0, $UMASK, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 )
      if $self->_is_root($fn);
    $fn = $self->resolve($fn);
    my $val = $self->_get_db_entry($fn);
    if ( !defined $val ) { return CORE::stat($fn); }
    $fn = $self->basename($fn);
    return (
        0, 0, $val->{$fn}{permissions},
        0, 0, 0, 0, $val->{$fn}{size},
        0,
        $val->{$fn}{modified},
        $val->{$fn}{created},
        0, 0
    );
}

sub _get_db_value {
    my ( $self, $fn, $attr, $default ) = @_;
    $fn = $self->resolve($fn);
    my $dbv = $self->_get_db_entry( $fn, $attr eq 'data' );
    return defined $dbv
      ? ( $dbv->{ $self->basename($fn) }{$attr} // $default )
      : $default;
}

sub _add_db_entry {
    my ( $self, $name, $type ) = @_;
    $self->_initialize();
    my $parent  = $self->getParent($name);
    my $created = time;
    $name = $self->basename($name);

    my $sth = $DB->prepare(
'INSERT INTO objects (name, parent, type, owner, size, created, modified, permissions,data) VALUES ( ?, ?, ?, ?, ?, ?, ?, ?, ?)'
    );
    $sth->bind_param( 1, $name );
    $sth->bind_param( 2, $parent );
    $sth->bind_param( 3, $type );
    $sth->bind_param( 4, $ENV{REMOTE_USER} );
    $sth->bind_param( 5, defined $_[3] ? length $_[3] : 0 );
    $sth->bind_param( 6, $created );
    $sth->bind_param( 7, $created );
    $sth->bind_param( 8, oct(7777) ^ $UMASK );
    if ( defined $_[3] ) { $sth->bind_param( 9, $_[3], SQL_BLOB ); }
    my $ret = $sth->execute();

    if ( !$self->_is_root($parent) && $ret ) {
        $ret &= $self->_change_db_entry($parent);
    }
    if ($ret) {
        #$DB->commit();
        return $ret;
    }
    #$DB->rollback();
    return $ret;
}

sub _change_db_entry {
    my ( $self, $name ) = @_;
    $self->_initialize();
    $name = $self->resolve($name);
    my $sel = 'UPDATE objects SET modified = ?';
    $sel .= defined $_[2] ? ', data = ?' : q{};
    $sel .= defined $_[2] ? ', size = ?' : q{};
    $sel .= ' WHERE name = ? AND parent = ?';
    my $sth = $DB->prepare($sel);
    my $i   = 0;
    $sth->bind_param( ++$i, time );

    if ( defined $_[2] ) {
        $sth->bind_param( ++$i, $_[2], SQL_BLOB );
        $sth->bind_param( ++$i, length $_[2] );
    }
    $sth->bind_param( ++$i, $self->basename($name) );
    $sth->bind_param( ++$i, $self->getParent($name) );

    if ( $sth->execute() ) {
        #$DB->commit();
        return 1;
    }
    #$DB->rollback();
    return 0;
}

sub _get_db_entry {
    my ( $self, $fn, $withdata ) = @_;
    $self->_initialize();
    my $sel =
      'SELECT name, parent, type, created, modified, size, permissions, owner';
    $sel .= $withdata ? ',data' : q{};
    $sel .= ' FROM objects WHERE name = ? AND parent = ?';
    my $sth = $DB->prepare($sel);
    $sth->execute(
        $self->basename( $self->resolve($fn) ),
        $self->getParent( $self->resolve($fn) )
    );
    return !$sth->err ? $sth->fetchall_hashref('name') : undef;
}

sub _is_root {
    return $_[1] ? $_[1] eq $DOCUMENT_ROOT : $PATH_TRANSLATED eq $DOCUMENT_ROOT;
}

sub resolve {
    my ( $self, $fn ) = @_;
    $fn //= $PATH_TRANSLATED;
    $fn =~ s{([^/]*)/[.]{2}(?:/?.*)}{$1}xms;
    $fn =~ s{/$}{}xms;
    $fn =~ s{//}{/}xmsg;
    return $fn eq q{} ? q{/} : $fn;
}

sub isEmpty {
    my @stat = $_[0]->stat( $_[1] );
    return $stat[7] == 0;
}

sub saveData {

    #my ($self, $path, $data, $append) = @_;
    my $fn = $_[0]->resolve( $_[1] );
    my $data;
    $_[0]->_initialize();
    if ( $_[0]->exists( $_[1] ) ) {
        if ( $_[3] ) {
            my $v = _get_db_entry( $fn, 1 );
            $data = $v->{ $_[0]->basename($fn) }{data} . $_[2];
            return $_[0]->_change_db_entry( $fn,
                $v->{ $_[0]->basename($fn) }{data} . $_[2] );
        }
        return $_[0]->_change_db_entry( $fn, $_[2] );
    }
    return $_[0]->_add_db_entry( $_[1], TYPE_FILE, $_[2] );
}

sub saveStream {
    my ( $self, $fn, $fh ) = @_;
    $fn = $self->resolve($fn);
    my $blob;
    while ( read $fh, my $buffer, $BUFSIZE ) {
        $blob .= $buffer;
    }
    return $self->exists($fn)
      ? $self->_change_db_entry( $fn, $blob )
      : $self->_add_db_entry( $fn, TYPE_FILE, $blob );
}

sub printFile {
    my ( $self, $fn, $fh, $pos, $count ) = @_;
    $fn = $self->resolve($fn);
    my $v = $self->_get_db_entry( $fn, 1 );
    print {$fh} (
        defined $pos && defined $count
        ? substr( $v->{ $self->basename($fn) }{data}, $pos, $count )
        : $v->{ $self->basename($fn) }{data}
    );
    return;
}

sub getLocalFilename {
    my ( $self, $fn ) = @_;
    my $suffix;
    if ( $fn =~ m{([.][^.]+)$}xms ) { $suffix = $1; }
    my ( $fh, $filename ) = tempfile(
        TEMPLATE => '/tmp/webdavcgiXXXXX',
        CLEANUP  => 1,
        SUFFIX   => $suffix
    );
    $self->printFile( $fn, $fh );
    return $filename;
}

sub getFileContent {
    my ( $self, $fn ) = @_;
    $fn = $self->resolve($fn);
    my $v = $self->_get_db_entry( $fn, 1 );
    return $v->{ $self->basename($fn) }{data};
}
1;
