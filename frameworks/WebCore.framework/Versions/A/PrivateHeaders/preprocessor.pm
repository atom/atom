#
# Copyright (C) 2005 Nikolas Zimmermann <wildfox@kde.org>
# Copyright (C) 2011 Google Inc.
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Library General Public
# License as published by the Free Software Foundation; either
# version 2 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Library General Public License for more details.
#
# You should have received a copy of the GNU Library General Public License
# along with this library; see the file COPYING.LIB.  If not, write to
# the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
# Boston, MA 02110-1301, USA.
#

use strict;
use warnings;

use IPC::Open2;

BEGIN {
   use Exporter   ();
   our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);
   $VERSION     = 1.00;
   @ISA         = qw(Exporter);
   @EXPORT      = qw(&applyPreprocessor);
   %EXPORT_TAGS = ( );
   @EXPORT_OK   = ();
}

# Returns an array of lines.
sub applyPreprocessor
{
    my $fileName = shift;
    my $defines = shift;
    my $preprocessor = shift;

    if (!$preprocessor) {
        require Config;
        my $gccLocation = "";
        if ($ENV{CC}) {
            $gccLocation = $ENV{CC};
        } elsif (($Config::Config{'osname'}) =~ /solaris/i) {
            $gccLocation = "/usr/sfw/bin/gcc";
        } else {
            $gccLocation = "/usr/bin/gcc";
        }
        $preprocessor = $gccLocation . " -E -P -x c++";
    }

    # Remove double quotations from $defines and extract macros.
    # For example, if $defines is ' "A=1" "B=1" C=1 ""    D  ',
    # then it is converted into four macros -DA=1, -DB=1, -DC=1 and -DD.
    $defines =~ s/\"//g;
    my @macros = grep { $_ } split(/\s+/, $defines); # grep skips empty macros.
    @macros = map { "-D$_" } @macros;

    my $pid = open2(\*PP_OUT, \*PP_IN, split(' ', $preprocessor), @macros, $fileName);
    close PP_IN;
    my @documentContent = <PP_OUT>;
    close PP_OUT;
    waitpid($pid, 0);
    return @documentContent;
}

1;
