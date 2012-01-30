#!/usr/bin/perl -w
#
# Copyright (C) 2005 Apple Computer, Inc.
# Copyright (C) 2006 Anders Carlsson <andersca@mac.com>
# 
# This file is part of WebKit
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

# This script is a temporary hack. 
# Files are generated in the source directory, when they really should go
# to the DerivedSources directory.
# This should also eventually be a build rule driven off of .idl files
# however a build rule only solution is blocked by several radars:
# <rdar://problems/4251781&4251785>

use strict;

use File::Path;
use File::Basename;
use Getopt::Long;
use Cwd;

use IDLParser;
use CodeGenerator;

my @idlDirectories;
my $outputDirectory;
my $outputHeadersDirectory;
my $generator;
my $defines;
my $filename;
my $prefix;
my $preprocessor;
my $writeDependencies;
my $verbose;
my $supplementalDependencyFile;
my $additionalIdlFilesList;

GetOptions('include=s@' => \@idlDirectories,
           'outputDir=s' => \$outputDirectory,
           'outputHeadersDir=s' => \$outputHeadersDirectory,
           'generator=s' => \$generator,
           'defines=s' => \$defines,
           'filename=s' => \$filename,
           'prefix=s' => \$prefix,
           'preprocessor=s' => \$preprocessor,
           'verbose' => \$verbose,
           'write-dependencies' => \$writeDependencies,
           'supplementalDependencyFile=s' => \$supplementalDependencyFile,
           'additionalIdlFilesList=s' => \$additionalIdlFilesList);

my $targetIdlFile = $ARGV[0];

die('Must specify input file.') unless defined($targetIdlFile);
die('Must specify generator') unless defined($generator);
die('Must specify output directory.') unless defined($outputDirectory);

if (!$outputHeadersDirectory) {
    $outputHeadersDirectory = $outputDirectory;
}
$targetIdlFile = Cwd::realpath($targetIdlFile);
if ($verbose) {
    print "$generator: $targetIdlFile\n";
}
my $targetInterfaceName = fileparse(basename($targetIdlFile), ".idl");

my $idlFound = 0;
my @supplementedIdlFiles;
if ($supplementalDependencyFile) {
    # The format of a supplemental dependency file:
    #
    # DOMWindow.idl P.idl Q.idl R.idl
    # Document.idl S.idl
    # Event.idl
    # ...
    #
    # The above indicates that DOMWindow.idl is supplemented by P.idl, Q.idl and R.idl,
    # Document.idl is supplemented by S.idl, and Event.idl is supplemented by no IDLs.
    # The IDL that supplements another IDL (e.g. P.idl) never appears in the dependency file.
    open FH, "< $supplementalDependencyFile" or die "Cannot open $supplementalDependencyFile\n";
    while (my $line = <FH>) {
        my ($idlFile, @followingIdlFiles) = split(/\s+/, $line);
        if ($idlFile and basename($idlFile) eq basename($targetIdlFile)) {
            $idlFound = 1;
            @supplementedIdlFiles = @followingIdlFiles;
        }
    }
    close FH;

    # The file $additionalIdlFilesList contains one IDL file per line:
    # P.idl
    # Q.idl
    # ...
    # These IDL files are ones which should not be included in DerivedSources*.cpp
    # (i.e. they are not described in the supplemental dependency file)
    # but should generate .h and .cpp files.
    if (!$idlFound and $additionalIdlFilesList) {
        open FH, "< $additionalIdlFilesList" or die "Cannot open $additionalIdlFilesList\n";
        my @idlFiles = <FH>;
        chomp(@idlFiles);
        $idlFound = grep { $_ and basename($_) eq basename($targetIdlFile) } @idlFiles;
        close FH;
    }

    if (!$idlFound) {
        my $codeGen = CodeGenerator->new(\@idlDirectories, $generator, $outputDirectory, $outputHeadersDirectory, 0, $preprocessor, $writeDependencies, $verbose);

        # We generate empty .h and .cpp files just to tell build scripts that .h and .cpp files are created.
        generateEmptyHeaderAndCpp($codeGen->FileNamePrefix(), $targetInterfaceName, $outputHeadersDirectory, $outputDirectory);
        exit 0;
    }
}

# Parse the target IDL file.
my $targetParser = IDLParser->new(!$verbose);
my $targetDocument = $targetParser->Parse($targetIdlFile, $defines, $preprocessor);

foreach my $idlFile (@supplementedIdlFiles) {
    next if $idlFile eq $targetIdlFile;

    my $interfaceName = fileparse(basename($idlFile), ".idl");
    my $parser = IDLParser->new(!$verbose);
    my $document = $parser->Parse($idlFile, $defines, $preprocessor);

    foreach my $dataNode (@{$document->classes}) {
        if ($dataNode->extendedAttributes->{"Supplemental"} and $dataNode->extendedAttributes->{"Supplemental"} eq $targetInterfaceName) {
            my $targetDataNode;
            foreach my $class (@{$targetDocument->classes}) {
                if ($class->name eq $targetInterfaceName) {
                    $targetDataNode = $class;
                    last;
                }
            }
            die "Not found an interface ${targetInterfaceName} in ${targetInterfaceName}.idl." unless defined $targetDataNode;

            foreach my $attribute (@{$dataNode->attributes}) {
                # Record that this attribute is implemented by $interfaceName.
                $attribute->signature->extendedAttributes->{"ImplementedBy"} = $interfaceName;

                # Add interface-wide extended attributes to each attribute.
                foreach my $extendedAttributeName (keys %{$dataNode->extendedAttributes}) {
                    next if ($extendedAttributeName eq "Supplemental");
                    $attribute->signature->extendedAttributes->{$extendedAttributeName} = $dataNode->extendedAttributes->{$extendedAttributeName};
                }
                push(@{$targetDataNode->attributes}, $attribute);
            }

            foreach my $function (@{$dataNode->functions}) {
                # Record that this attribute is implemented by $interfaceName.
                $function->signature->extendedAttributes->{"ImplementedBy"} = $interfaceName;

                # Add interface-wide extended attributes to each attribute.
                foreach my $extendedAttributeName (keys %{$dataNode->extendedAttributes}) {
                    next if ($extendedAttributeName eq "Supplemental");
                    $function->signature->extendedAttributes->{$extendedAttributeName} = $dataNode->extendedAttributes->{$extendedAttributeName};
                }
                push(@{$targetDataNode->functions}, $function);
            }
        }
    }
}

# Generate desired output for the target IDL file.
my $codeGen = CodeGenerator->new(\@idlDirectories, $generator, $outputDirectory, $outputHeadersDirectory, 0, $preprocessor, $writeDependencies, $verbose);
$codeGen->ProcessDocument($targetDocument, $defines);

sub generateEmptyHeaderAndCpp
{
    my ($prefix, $targetInterfaceName, $outputHeadersDirectory, $outputDirectory) = @_;

    my $headerName = "${prefix}${targetInterfaceName}.h";
    my $cppName = "${prefix}${targetInterfaceName}.cpp";
    my $contents = "/*
    This file is generated just to tell build scripts that $headerName and
    $cppName are created for ${targetInterfaceName}.idl, and thus
    prevent the build scripts from trying to generate $headerName and
    $cppName at every build. This file must not be tried to compile.
*/
";
    open FH, "> ${outputHeadersDirectory}/${headerName}" or die "Cannot open $headerName\n";
    print FH $contents;
    close FH;

    open FH, "> ${outputDirectory}/${cppName}" or die "Cannot open $cppName\n";
    print FH $contents;
    close FH;
}
