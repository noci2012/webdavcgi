#!/usr/bin/perl
#########################################################################
# (C) ZE CMS, Humboldt-Universitaet zu Berlin
# Written 2010-2012 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
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

package Backend::RCS::Driver;

use strict;
use warnings;

our $VERSION = '1.0';

use base qw( Backend::Helper );

use Rcs;
use English qw( -no_match_vars );
use File::Temp qw/ tempfile /;
use List::MoreUtils qw( none );
use CGI::Carp;

use DefaultConfig qw( $READBUFSIZE %BACKEND_CONFIG );
use Backend::Manager;
use HTTPHelper qw( get_parent_uri get_base_uri_frag );

use vars qw( %CACHE );

sub init {
    my ( $self, $config ) = @_;
    $self->SUPER::init($config);
    $self->{BACKEND} =
      Backend::Manager::getinstance()
      ->get_backend( $BACKEND_CONFIG{RCS}{backend} || 'FS', $self->{config} );
    return $self;
}

sub finalize {
    my ($self) = @_;
    %CACHE = ();
    $self->{BACKEND}->finalize();
    return;
}

sub basename {
    my $self = shift @_;
    return get_base_uri_frag( $_[0] )
      if $_[0] =~
/\/\Q$BACKEND_CONFIG{RCS}{rcsdirname}\E\/\Q$BACKEND_CONFIG{RCS}{virtualrcsdir}\E\/?/;
    return $self->{BACKEND}->basename(@_);
}

sub dirname {
    my $self = shift @_;
    return get_parent_uri( $_[0] )
      if defined $_[0]
      && $_[0] =~
/\/\Q$BACKEND_CONFIG{RCS}{rcsdirname}\E\/\Q$BACKEND_CONFIG{RCS}{virtualrcsdir}\E\/?/;
    return $self->{BACKEND}->dirname(@_);
}

sub exists {
    my $self = shift @_;
    return 1 if ( $self->_is_virtual( $_[0] ) );
    return $self->{BACKEND}->exists(@_);
}

sub isDir {
    my $self = shift @_;
    return 1 if ( $self->_is_virtual_dir( $_[0] ) );
    return 0 if ( $self->_is_virtual_file( $_[0] ) );
    return $self->{BACKEND}->isDir(@_);
}

sub isFile {
    my $self = shift @_;
    return 1 if ( $self->_is_virtual_file( $_[0] ) );
    return 0 if ( $self->_is_virtual_dir( $_[0] ) );
    return $self->{BACKEND}->isFile(@_);
}

sub isLink {
    my $self = shift @_;
    return 0 if ( $self->_is_virtual( $_[0] ) );
    return $self->{BACKEND}->isLink(@_);
}

sub isBlockDevice {
    my $self = shift @_;
    return 0 if ( $self->_is_virtual( $_[0] ) );
    return $self->{BACKEND}->isBlockDevice(@_);
}

sub isCharDevice {
    my $self = shift @_;
    return 0 if ( $self->_is_virtual( $_[0] ) );
    return $self->{BACKEND}->isCharDevice(@_);
}

sub isEmpty {
    my $self = shift @_;
    return 0 if ( $self->_is_virtual( $_[0] ) );
    return $self->{BACKEND}->isEmpty(@_);
}

sub isReadable {
    my $self = shift @_;
    return 1 if ( $self->_is_virtual( $_[0] ) );
    return $self->{BACKEND}->isReadable(@_);
}

sub isWriteable {
    my $self = shift @_;
    return 1 if ( $self->_is_virtual( $_[0] ) );
    return $self->{BACKEND}->isWriteable(@_);
}

sub isExecutable {
    my $self = shift @_;
    return 1 if ( $self->_is_virtual( $_[0] ) );
    return $self->{BACKEND}->isExecutable(@_);
}

sub getParent {
    my $self = shift @_;
    return $self->{BACKEND}->getParent(@_);
}

sub mkcol {
    my $self = shift @_;
    return 1 if ( $self->_is_virtual( $_[0] ) );
    return $self->{BACKEND}->mkcol(@_);
}

sub unlinkFile {
    my $self = shift @_;
    return 1 if ( $self->_is_virtual( $_[0] ) );
    return $self->{BACKEND}->unlinkFile(@_);
}

sub unlinkDir {
    my $self = shift @_;
    return 1 if ( $self->_is_virtual( $_[0] ) );
    return $self->{BACKEND}->unlinkDir(@_);
}

sub readDir {
    my ( $self, $dirname, $limit, $filter ) = @_;
    my $ret;
    if ( !( $ret = $self->_read_virtual_dir( $dirname, $limit, $filter ) ) ) {
        $ret = $self->{BACKEND}->readDir( $dirname, $limit, $filter );

        if ( $self->basename($dirname) eq $BACKEND_CONFIG{RCS}{rcsdirname}
            && none { /\Q$BACKEND_CONFIG{RCS}{virtualrcsdir}\E/xms } @{$ret} )
        {
            push @{$ret}, $BACKEND_CONFIG{RCS}{virtualrcsdir};
        }
    }
    return $ret;
}

sub filter {
    my $self = shift @_;
    return $self->{BACKEND}->filter(@_);
}

sub stat {
    my ( $self, $fn ) = @_;
    return ( 0, 0, oct(555), 2, $UID, $GID, 0, 0, time, time, time, 4096, 0 )
      if ( $self->_is_virtual_dir($fn) );
    if ( $self->_is_virtual_file($fn) ) {
        return @{ $CACHE{$self}{$fn}{stat} } if exists $CACHE{$self}{$fn}{stat};
        my $lf = $self->_save_to_local($fn);
        my @stat =
          $CACHE{$self}{$fn}{stat}
          ? @{ $CACHE{$self}{$fn}{stat} }
          : CORE::stat($lf);
        unlink $lf;
        return @stat;
    }
    return $self->{BACKEND}->stat($fn);
}

sub lstat {
    my $self = shift @_;
    return $self->stat(@_) if $self->_is_virtual( $_[0] );
    return $self->{BACKEND}->lstat(@_);
}

sub deltree {
    my $self = shift @_;
    return 1 if ( $self->_is_virtual_dir( $_[0] ) );
    return $self->{BACKEND}->deltree(@_);
}

sub changeFilePermissions {
    my $self = shift @_;
    return 0 if ( $self->_is_virtual_dir( $_[0] ) );
    return $self->{BACKEND}->changeFilePermissions(@_);
}

sub saveData {
    my ( $self, $destination, $data, $append ) = @_;
    return 1 if ( $self->_is_virtual_dir($destination) );
    my $ret = 0;
    my ( $tmpfh, $localfilename ) = tempfile(
        TEMPLATE => '/tmp/webdavcgiXXXXX',
        CLEANUP  => 1,
        SUFFIX   => 'tmp'
    );
    if ($append) {
        $ret = $self->{BACKEND}->printFile( $localfilename, $tmpfh );
    }
    print( {$tmpfh} $data ) || carp('Cannot write to temporary file.');
    close($tmpfh) || carp('Cannot close temporary file.');

    if ( $ret = open $tmpfh, '<', $localfilename ) {
        $ret = $self->saveStream( $destination, $tmpfh );
        close($tmpfh) || carp('Cannot close temporary file.');
    }
    unlink $localfilename;
    return $ret;
}

sub saveStream {
    my ( $self, $destination, $fh ) = @_;

    return 1 if ( $self->_is_virtual_dir($destination) );

    if ( !$self->_is_allowed($destination) ) {
        return $self->{BACKEND}->saveStream( $destination, $fh );
    }

    my $ret = 0;

    my $filename          = $self->basename($destination);
    my $remotercsfilename = $self->dirname($destination)
      . "/$BACKEND_CONFIG{RCS}{rcsdirname}/$filename,v";
    my $suffix;
    if ( $destination =~ /([.][^.]+)$/xms ) {
        $suffix = $1;
    }
    my ( $tmpfh, $localfilename ) = tempfile(
        TEMPLATE => '/tmp/webdavcgiXXXXX',
        CLEANUP  => 1,
        SUFFIX   => $suffix
    );
    my $arcfile = "$localfilename,v";

    my $rcs = $self->_getRcs();
    $rcs->workdir('/tmp');
    $rcs->file( $self->basename($localfilename) );
    $rcs->rcsdir( $self->dirname($arcfile) );
    $rcs->arcfile( $self->basename($arcfile) );
    if ( $self->exists($destination) ) {
        if ( $self->exists($remotercsfilename) ) {
            if ( $ret = open my $arcfilefh, '>', $arcfile ) {
                $self->{BACKEND}->printFile( $remotercsfilename, $arcfilefh );
                close($arcfilefh) || carp("Cannot close $arcfile.");
            }
            else {
                carp("Cannot open $arcfile for writing: $ERRNO");
            }
            unlink $localfilename;
        }
        else {
            if ( $ret = open my $lfh, '>', $localfilename ) {
                $self->{BACKEND}->printFile( $destination, $lfh );
                close($lfh) || carp("Cannot close $localfilename.");
            }
            $rcs->ci();
        }
        $rcs->co('-l');
    }

    if ( $ret = open my $lfh, '>', $localfilename ) {
        binmode $lfh;
        binmode $fh;
        while ( read( $fh, my $buffer, $READBUFSIZE ) > 0 ) {
            print( {$lfh} $buffer ) || carp("Cannot write to $localfilename");
        }
        close($lfh) || carp("Cannot close $localfilename.");

        $rcs->ci();
        my @revisions = $rcs->revisions();
        if ( defined $BACKEND_CONFIG{RCS}{maxrevisions}
            && $#revisions >= $BACKEND_CONFIG{RCS}{maxrevisions} )
        {
            my @removedrevisions = splice @revisions,
              $BACKEND_CONFIG{RCS}{maxrevisions};
            my $range = $removedrevisions[0];
            $range .=
              $#removedrevisions > 0
              ? ":$removedrevisions[$#removedrevisions]"
              : q{};
            $rcs->rcs("-o$range");
        }
        $rcs->co();

        if (   ( $ret = open $lfh, '<', $localfilename )
            && ( $ret = $self->{BACKEND}->saveStream( $destination, $lfh ) ) )
        {
            close($lfh) || carp("Cannot close $localfilename");
            $ret =
               !$self->exists( $self->dirname($remotercsfilename) )
              ? $self->{BACKEND}->mkcol( $self->dirname($remotercsfilename) )
              : 1;
            if ( $ret = open $lfh, '<', $arcfile ) {
                $self->{BACKEND}->saveStream( $remotercsfilename, $lfh );
                close($lfh) || carp("Cannot close $arcfile.");
            }
        }

        unlink $arcfile;
        unlink $localfilename;
    }
    return $ret;
}

sub uncompress_archive {
    my $self = shift @_;
    return 0 if ( $self->_is_virtual( $_[0] ) );
    return $self->SUPER::uncompress_archive(@_);
}

sub changeMod {
    my $self = shift @_;
    return 0 if ( $self->_is_virtual( $_[0] ) );
    return $self->{BACKEND}->changeMod(@_);
}

sub createSymLink {
    my $self = shift @_;
    return 0 if ( $self->_is_virtual( $_[0] ) );
    return $self->{BACKEND}->createSymLink(@_);
}

sub getLinkSrc {
    my $self = shift @_;
    return $_[0] if ( $self->_is_virtual( $_[0] ) );
    return $self->{BACKEND}->getLinkSrc(@_);
}

sub resolve {
    my $self = shift @_;
    return $_[1] if $self->_is_virtual( $_[1] );
    return $self->{BACKEND}->resolve(@_);
}

sub getFileContent {
    my $self = shift @_;
    if ( $self->_is_virtual_file( $_[0] ) ) {
        my $lf = $self->_save_to_local( $_[0] );
        if ( open my $lfh, '<', $lf ) {
            local $RS = undef;
            my $content = <$lfh>;
            close($lfh) || carp("Cannot close $lf.");
            unlink $lf;
            return $content;
        }
        return q{};
    }
    return $self->{BACKEND}->getFileContent(@_);
}

sub hasSetUidBit {
    my $self = shift @_;
    return 0 if ( $self->_is_virtual( $_[0] ) );
    return $self->{BACKEND}->hasSetUidBit(@_);
}

sub hasSetGidBit {
    my $self = shift @_;
    return 0 if ( $self->_is_virtual( $_[0] ) );
    return $self->{BACKEND}->hasSetGidBit(@_);
}

sub hasStickyBit {
    my $self = shift @_;
    return 0 if ( $self->_is_virtual( $_[0] ) );
    return $self->{BACKEND}->hasStickyBit(@_);
}

sub getLocalFilename {
    my $self = shift @_;
    return $self->_save_to_local( $_[0] ) if $self->_is_virtual_file( $_[0] );
    return $self->{BACKEND}->getLocalFilename(@_);
}

sub printFile {
    my ( $self, $fn, $fh, $pos, $count ) = @_;
    if ( $self->_is_virtual_file($fn) ) {
        $fh //= \*STDOUT;

        my $dn = $self->basename( $self->dirname($fn) );
        my ( $file, $rcsfile ) = $self->_get_rcs_file($fn);

        my $rcs = $self->_getRcs();
        $rcs->workdir('/tmp');
        $rcs->rcsdir( $self->dirname($rcsfile) );
        $rcs->file( $self->basename($file) );
        if ( $fn =~ /log.txt$/xms ) {
            my $filebn = $self->basename($file);
            my $rlog = join q{}, $rcs->rlog('-zLT');
            $rlog =~ s/\Q$rcsfile\E/$dn,v/xmsg;
            $rlog =~ s/\Q$filebn\E/$dn/xmsg;
            print( {$fh} (
                defined $pos
                  && defined $count ? substr( $rlog, $pos, $count ) : $rlog
            )) || carp("Cannot write to $fn.");
        }
        elsif ( $fn =~ /diff[.]txt$/xms ) {
            my $buffer = q{};
            my $firstrev;
            foreach my $rev ( $rcs->revisions() ) {
                if ( !defined $firstrev ) {
                    $firstrev = $rev;
                    next;
                }
                eval {
                    my $diff = join q{},
                      $rcs->rcsdiff( '-kkv', '-q', '-u', "-r$rev",
                        "-r$firstrev", '-zLT' );
                    $diff =~ s/^([+]{3}|[-]{3}) \Q$file\E/$1 $dn/xmsg;
                    $buffer .= $diff;
                } || carp("rcsdiff failed: $EVAL_ERROR");
                $firstrev = $rev;
            }
            print(
                {$fh} (
                    defined $pos && defined $count
                    ? substr( $buffer, $pos, $count )
                    : $buffer
                )
              )
              || carp("Cannot write to $fn.");
        }
        else {
            my $rev = $fn =~ m{/(\d+[.]\d+)/[^/]+$}xms ? $1 : 0;
            if ( $rcs->co( "-r$rev", "-M$rev" ) && open my $lfh, '<', $file ) {
                my @stat = CORE::stat($lfh);
                $CACHE{$self}{$fn}{stat} = \@stat;
                binmode $fh;
                binmode $lfh;
                my $bufsize = $READBUFSIZE;
                if ( defined $count && $count < $bufsize ) {
                    $bufsize = $count;
                }
                my $buffer;
                my $bytecount = 0;
                seek( $fh, $pos, 0 ) if $pos;

                while ( my $bytesread = read( $lfh, $buffer, $bufsize ) ) {
                    print( {$fh} $buffer ) || carp("Cannot write to $fn.");
                    $bytecount += $bytesread;
                    last if defined $count && $bytecount >= $count;

                    if ( defined $count && ( $bytecount + $bufsize > $count ) )
                    {
                        $bufsize = $count - $bytecount;
                    }
                }
                close($lfh) || carp("Cannot close $file.");
            }
            else {
                print( {$fh} "NOT IMPLEMENTED\n" )
                  || carp("Cannot write to $fn.");
            }
            unlink $file;
        }
        unlink $rcsfile;
    }
    else {
        $self->{BACKEND}->printFile( $fn, $fh, $pos, $count );
    }
    return;
}

sub getDisplayName {
    my $self = shift @_;
    return get_base_uri_frag( $_[0] ) . q{/} if $self->_is_virtual_dir( $_[0] );
    return get_base_uri_frag( $_[0] ) if $self->_is_virtual_file( $_[0] );
    return $self->{BACKEND}->getDisplayName(@_);
}

sub rename {
    my $self = shift @_;
    return 1 if ( $self->_is_virtual( $_[0] ) || $self->_is_virtual( $_[1] ) );
    return $self->{BACKEND}->rename(@_);
}

sub getQuota {
    my $self = shift @_;
    if ( $self->_is_virtual( $_[0] ) ) {
        my $realpath = $_[0];
        $realpath =~
s{/$BACKEND_CONFIG{RCS}{rcsdirname}(/$BACKEND_CONFIG{RCS}{virtualrcsdir}.*)?$}{}xms;
        return $self->{BACKEND}->getQuota($realpath);
    }
    return $self->{BACKEND}->getQuota(@_);
}

sub copy {
    my $self = shift @_;
    return 1 if ( $self->_is_virtual( $_[0] ) || $self->_is_virtual( $_[1] ) );
    return $self->{BACKEND}->copy(@_);
}

sub _read_virtual_dir {
    my ( $self, $dirname, $limit, $filter ) = @_;
    my $ret;
    return $ret if !$self->_is_virtual_dir($dirname);

    my $basename       = $self->basename($dirname);
    my $parent         = $self->dirname($dirname);
    my $parentbasename = $self->basename($parent);

    if ( $self->_is_revision_dir($dirname) ) {
        push @{$ret}, $parentbasename;

    }
    elsif ( $self->_is_revisions_dir($dirname) ) {
        my $rcsfilename = $self->dirname($parent) . "/$basename,v";
        my ( $tmpfh, $localfilename ) = tempfile(
            TEMPLATE => '/tmp/webdavcgiXXXXX',
            CLEANUP  => 1,
            SUFFIX   => ',v'
        );
        $self->{BACKEND}->printFile( $rcsfilename, $tmpfh );
        close($tmpfh) || carp("Cannot close $localfilename.");

        my $rcs = $self->_getRcs();
        $rcs->workdir( $self->dirname($localfilename) );
        $rcs->rcsdir( $self->dirname($localfilename) );
        my $fn = $self->basename($localfilename);
        $fn =~ s/,v$//xms;
        $rcs->file($fn);
        push @{$ret}, $rcs->revisions(), 'diff.txt', 'log.txt';
        unlink $localfilename;

    }
    elsif ( $self->_is_virtual_rcs_dir($dirname) ) {
        my $fl = $self->{BACKEND}->readDir( $parent, $limit, $filter );
        foreach my $f ( @{$fl} ) {
            $f =~ s/,v$//xms;
            push @{$ret}, $f;
        }
    }
    return $ret;

}

sub _save_to_local {
    my ( $self, $fn, $suffix ) = @_;
    if ( !$suffix && $fn =~ /([.][^.]+)$/xms ) { $suffix = $1; }
    my ( $tmpfh, $vfile ) = tempfile(
        TEMPLATE => '/tmp/webdavcgiXXXXX',
        CLEANUP  => 1,
        SUFFIX   => $suffix || '.tmp'
    );
    $self->printFile( $fn, $tmpfh );
    close($tmpfh) || carp("Cannot close $vfile.");
    return $vfile;
}

sub _get_rcs_file {
    my ( $self, $vpath ) = @_;

    $vpath =~
m{^(.*?/\Q$BACKEND_CONFIG{RCS}{rcsdirname}\E/)\Q$BACKEND_CONFIG{RCS}{virtualrcsdir}\E/([^/]+)}xms;
    my ($fn) = ("$1$2,v");

    my $rcsfile = $self->_save_to_local( $fn, ',v' );
    my $file = $rcsfile;
    $file =~ s/,v$//xms;

    return ( $file, $rcsfile );
}

sub _is_virtual {
    my ( $self, $fn ) = @_;
    return $self->_is_virtual_file($fn) || $self->_is_virtual_dir($fn);
}

sub _is_virtual_file {
    my ( $self, $fn ) = @_;
    return ( $self->_is_revisions_dir( $self->dirname($fn) )
          && $self->basename($fn) =~ /^(?:log|diff)[.]txt$/xms )
      || $self->_is_revision_dir( $self->dirname($fn) );
}

sub _is_virtual_dir {
    my ( $self, $fn ) = @_;
    return !$self->{BACKEND}->exists($fn)
      && ( $self->_is_virtual_rcs_dir($fn)
        || $self->_is_revisions_dir($fn)
        || $self->_is_revision_dir($fn) );
}

#sub _is_rcs_dir {
#    my ( $self, $fn ) = @_;
#    return $fn =~ m{/\Q$BACKEND_CONFIG{RCS}{rcsdirname}\E/?$}xms;
#}

sub _is_virtual_rcs_dir {
    my ( $self, $fn ) = @_;
    return defined $fn
      && $fn =~
m{/\Q$BACKEND_CONFIG{RCS}{rcsdirname}\E/\Q$BACKEND_CONFIG{RCS}{virtualrcsdir}\E/?$}xms;
}

sub _is_revisions_dir {
    my ( $self, $fn ) = @_;
    return defined $fn
      && $fn =~
m{/\Q$BACKEND_CONFIG{RCS}{rcsdirname}\E/\Q$BACKEND_CONFIG{RCS}{virtualrcsdir}\E/[^/]+/?$}xms;
}

sub _is_revision_dir {
    my ( $self, $fn ) = @_;
    return defined $fn
      && $fn =~
m{/\Q$BACKEND_CONFIG{RCS}{rcsdirname}\E/\Q$BACKEND_CONFIG{RCS}{virtualrcsdir}\E/[^/]+/\d+[.]\d+/?$}xms;
}

sub _getRcs {
    my ($self) = @_;
    my $rcs = Rcs->new;
    $rcs->bindir( $BACKEND_CONFIG{RCS}{bindir} || '/usr/bin' );
    return $rcs;
}

sub _is_allowed {
    my ( $self, $filename ) = @_;
    my $ret = 1;
    if ( $filename =~ /[.]([^.]+)$/xms ) {
        my $suffix = $1;
        if ( defined $BACKEND_CONFIG{RCS}{allowedsuffixes} ) {
            my $regex = '^('
              . join( q{|}, @{ $BACKEND_CONFIG{RCS}{allowedsuffixes} } ) . ')$';
            $ret = $suffix =~ /$regex/xmsi;
        }
        if ( $ret && defined $BACKEND_CONFIG{RCS}{ignoresuffixes} ) {
            my $regex = '^('
              . join( q{|}, @{ $BACKEND_CONFIG{RCS}{ignoresuffixes} } ) . ')$';
            $ret = $suffix !~ /$regex/xmsi;
        }
    }
    if ( $ret && defined $BACKEND_CONFIG{RCS}{ignorefilenames} ) {
        my $regex = '^('
          . join( q{|}, @{ $BACKEND_CONFIG{RCS}{ignorefilenames} } ) . ')$';
        $ret = $self->{BACKEND}->basename($filename) !~ /$regex/xmsi;
    }
    return $ret;
}
1;

