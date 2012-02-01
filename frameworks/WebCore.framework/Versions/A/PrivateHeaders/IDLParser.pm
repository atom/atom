# 
# KDOM IDL parser
#
# Copyright (C) 2005 Nikolas Zimmermann <wildfox@kde.org>
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

package IDLParser;

use strict;
use re 'eval';

use IPC::Open2;
use IDLStructure;
use preprocessor;

use constant MODE_UNDEF    => 0; # Default mode.

use constant MODE_MODULE  => 10; # 'module' section
use constant MODE_INTERFACE  => 11; # 'interface' section

# Helper variables
my @temporaryContent;

my $parseMode;
my $preservedParseMode;

my $beQuiet; # Should not display anything on STDOUT?
my $document; # Will hold the resulting 'idlDocument'
my $parentsOnly; # If 1, parse only enough to populate parents list

sub InitializeGlobalData
{
    @temporaryContent = "";

    $parseMode = MODE_UNDEF;
    $preservedParseMode = MODE_UNDEF;

    $document = 0;
    $parentsOnly = 0;
}

# Default Constructor
sub new
{
    my $object = shift;
    my $reference = { };

    InitializeGlobalData();

    $beQuiet = shift;

    bless($reference, $object);
    return $reference;
}

# Returns the parsed 'idlDocument'
sub Parse
{
    my $object = shift;
    my $fileName = shift;
    my $defines = shift;
    my $preprocessor = shift;
    $parentsOnly = shift;

    print " | *** Starting to parse $fileName...\n |\n" unless $beQuiet;
    my @documentContent = applyPreprocessor($fileName, $defines, $preprocessor);

    my $dataAvailable = 0;

    # Simple IDL Parser (tm)
    foreach (@documentContent) {
        my $newParseMode = $object->DetermineParseMode($_);

        if ($newParseMode ne MODE_UNDEF) {
            if ($dataAvailable eq 0) {
                $dataAvailable = 1; # Start node building...
            } else {
                $object->ProcessSection();
            }
        }

        # Update detected data stream mode...
        if ($newParseMode ne MODE_UNDEF) {
            $parseMode = $newParseMode;
        }

        push(@temporaryContent, $_);
    }

    # Check if there is anything remaining to parse...
    if (($parseMode ne MODE_UNDEF) and ($#temporaryContent > 0)) {
        $object->ProcessSection();
    }

    print " | *** Finished parsing!\n" unless $beQuiet;
 
    $document->fileName($fileName);

    return $document;
}

sub ParseModule
{
    my $object = shift;
    my $dataNode = shift;

    print " |- Trying to parse module...\n" unless $beQuiet;

    my $data = join("", @temporaryContent);
    $data =~ /$IDLStructure::moduleSelector/;

    my $moduleName = (defined($1) ? $1 : die("Parsing error!\nSource:\n$data\n)"));
    $dataNode->module($moduleName);

    print "  |----> Module; NAME \"$moduleName\"\n |-\n |\n" unless $beQuiet;
}

sub dumpExtendedAttributes
{
    my $padStr = shift;
    my $attrs = shift;

    if (!%{$attrs}) {
        return "";
    }

    my @temp;
    while ((my $name, my $value) = each(%{$attrs})) {
        push(@temp, "$name=$value");
    }

    return $padStr . "[" . join(", ", @temp) . "]";
}

sub parseExtendedAttributes
{
    my $str = shift;
    $str =~ s/\[\s*(.*)\s*\]/$1/g;

    my %attrs = ();

    while ($str !~ /^\s*$/) {
        # Parse name
        if ($str !~ /^\s*([\w\d]+)/) {
            die("Invalid extended attribute: '$str'\n");
        }
        my $name = $1;
        $str =~ s/^\s*([\w\d]+)//;

        if ($str =~ /^\s*=/) {
            $str =~ s/^\s*=//;
            if ($name eq "NamedConstructor") {
                # Parse '=' name '(' arguments ')' ','?
                my $constructorName;
                if ($str =~ /^\s*([\w\d]+)/) {
                    $constructorName = $1;
                    $str =~ s/^\s*([\w\d]+)//;
                } else {
                    die("Invalid extended attribute: '$str'\n");
                }
                if ($str =~ /^\s*\(/) {
                    # Parse '(' arguments ')' ','?
                    $str =~ s/^\s*\(//;
                    if ($str =~ /^([^)]*)\),?/) {
                        my $signature = $1;
                        $signature =~ s/^(.*?)\s*$/$1/;
                        $attrs{$name} = {"ConstructorName" => $constructorName, "Signature" => $signature};
                        $str =~ s/^([^)]*)\),?//;
                    } else {
                        die("Invalid extended attribute: '$str'\n");
                    }
                } elsif ($str =~ /^\s*,?/) {
                    $attrs{$name} = {"ConstructorName" => $constructorName, "Signature" => ""};
                    $str =~ s/^\s*,?//;
                } else {
                    die("Invalid extended attribute: '$str'\n");
                }
            } else {
                # Parse '=' value ','?
                if ($str =~ /^\s*([^,]*),?/) {
                    $attrs{$name} = $1;
                    $attrs{$name} =~ s/^(.*?)\s*$/$1/;
                    $str =~ s/^\s*([^,]*),?//;
                } else {
                    die("Invalid extended attribute: '$str'\n");
                }
            }
        } elsif ($str =~ /^\s*\(/) {
            # Parse '(' arguments ')' ','?
            $str =~ s/^\s*\(//;
            if ($str =~ /^([^)]*)\),?/) {
                $attrs{$name} = $1;
                $attrs{$name} =~ s/^(.*?)\s*$/$1/;
                $str =~ s/^([^)]*)\),?//;
            } else {
                die("Invalid extended attribute: '$str'\n");
            }
        } elsif ($str =~ /^\s*,?/) {
            # Parse '' | ','
            if ($name eq "Constructor") {
                $attrs{$name} = "";
            } else {
                $attrs{$name} = 1;
            }
            $str =~ s/^\s*,?//;
        } else {
            die("Invalid extended attribute: '$str'\n");
        }
    }

    return \%attrs;
}

sub parseParameters
{
    my $newDataNode = shift;
    my $methodSignature = shift;

    # Split arguments at commas but only if the comma
    # is not within attribute brackets, expressed here
    # as being followed by a ']' without a preceding '['.
    # Note that this assumes that attributes don't nest.
    my @params = split(/,(?![^[]*\])/, $methodSignature);
    foreach (@params) {
        my $line = $_;

        $line =~ /$IDLStructure::interfaceParameterSelector/;
        my $paramDirection = $1;
        my $paramExtendedAttributes = (defined($2) ? $2 : " "); chop($paramExtendedAttributes);
        my $paramType = (defined($3) ? $3 : die("Parsing error!\nSource:\n$line\n)"));
        my $paramName = (defined($4) ? $4 : die("Parsing error!\nSource:\n$line\n)"));

        my $paramDataNode = new domSignature();
        $paramDataNode->direction($paramDirection);
        $paramDataNode->name($paramName);
        $paramDataNode->type($paramType);
        $paramDataNode->extendedAttributes(parseExtendedAttributes($paramExtendedAttributes));

        my $arrayRef = $newDataNode->parameters;
        push(@$arrayRef, $paramDataNode);

        print "  |   |>  Param; TYPE \"$paramType\" NAME \"$paramName\"" . 
            dumpExtendedAttributes("\n  |              ", $paramDataNode->extendedAttributes) . "\n" unless $beQuiet;          
    }
}

sub ParseInterface
{
    my $object = shift;
    my $dataNode = shift;
    my $sectionName = shift;

    my $data = join("", @temporaryContent);

    # Look for end-of-interface mark
    $data =~ /};/g;
    $data = substr($data, index($data, $sectionName), pos($data) - length($data));

    $data =~ s/[\n\r]/ /g;

    # Beginning of the regexp parsing magic
    if ($sectionName eq "interface") {
        print " |- Trying to parse interface...\n" unless $beQuiet;

        my $interfaceName = "";
        my $interfaceData = "";

        # Match identifier of the interface, and enclosed data...
        $data =~ /$IDLStructure::interfaceSelector/;

        my $interfaceExtendedAttributes = (defined($1) ? $1 : " "); chop($interfaceExtendedAttributes);
        $interfaceName = (defined($2) ? $2 : die("Parsing error!\nSource:\n$data\n)"));
        my $interfaceBase = (defined($3) ? $3 : "");
        $interfaceData = (defined($4) ? $4 : die("Parsing error!\nSource:\n$data\n)"));

        # Fill in known parts of the domClass datastructure now...
        $dataNode->name($interfaceName);
        my $extendedAttributes = parseExtendedAttributes($interfaceExtendedAttributes);
        if (defined $extendedAttributes->{"Constructor"}) {
            my $newDataNode = new domFunction();
            $newDataNode->signature(new domSignature());
            $newDataNode->signature->name("Constructor");
            $newDataNode->signature->extendedAttributes($extendedAttributes);
            parseParameters($newDataNode, $extendedAttributes->{"Constructor"});
            $extendedAttributes->{"Constructor"} = 1;
            $dataNode->constructor($newDataNode);
        } elsif (defined $extendedAttributes->{"NamedConstructor"}) {
            my $newDataNode = new domFunction();
            $newDataNode->signature(new domSignature());
            $newDataNode->signature->name("NamedConstructor");
            $newDataNode->signature->extendedAttributes($extendedAttributes);
            parseParameters($newDataNode, $extendedAttributes->{"NamedConstructor"}->{"Signature"});
            $extendedAttributes->{"NamedConstructor"} = $extendedAttributes->{"NamedConstructor"}{"ConstructorName"};
            $dataNode->constructor($newDataNode);
        }
        $dataNode->extendedAttributes($extendedAttributes);

        # Inheritance detection
        my @interfaceParents = split(/,/, $interfaceBase);
        foreach(@interfaceParents) {
            my $line = $_;
            $line =~ s/\s*//g;

            my $arrayRef = $dataNode->parents;
            push(@$arrayRef, $line);
        }

        return if $parentsOnly;

        $interfaceData =~ s/[\n\r]/ /g;
        my @interfaceMethods = split(/;/, $interfaceData);

        foreach my $line (@interfaceMethods) {
            if ($line =~ /\Wattribute\W/) {
                $line =~ /$IDLStructure::interfaceAttributeSelector/;

                my $attributeType = (defined($1) ? $1 : die("Parsing error!\nSource:\n$line\n)"));
                my $attributeExtendedAttributes = (defined($2) ? $2 : " "); chop($attributeExtendedAttributes);

                my $attributeDataType = (defined($3) ? $3 : die("Parsing error!\nSource:\n$line\n)"));
                my $attributeDataName = (defined($4) ? $4 : die("Parsing error!\nSource:\n$line\n)"));
  
                ('' =~ /^/); # Reset variables needed for regexp matching

                $line =~ /$IDLStructure::getterRaisesSelector/;
                my $getterException = (defined($1) ? $1 : "");

                $line =~ /$IDLStructure::setterRaisesSelector/;
                my $setterException = (defined($1) ? $1 : "");

                my $newDataNode = new domAttribute();
                $newDataNode->type($attributeType);
                $newDataNode->signature(new domSignature());

                $newDataNode->signature->name($attributeDataName);
                $newDataNode->signature->type($attributeDataType);
                $newDataNode->signature->extendedAttributes(parseExtendedAttributes($attributeExtendedAttributes));

                my $arrayRef = $dataNode->attributes;
                push(@$arrayRef, $newDataNode);

                print "  |  |>  Attribute; TYPE \"$attributeType\" DATA NAME \"$attributeDataName\" DATA TYPE \"$attributeDataType\" GET EXCEPTION? \"$getterException\" SET EXCEPTION? \"$setterException\"" .
                    dumpExtendedAttributes("\n  |                 ", $newDataNode->signature->extendedAttributes) . "\n" unless $beQuiet;

                $getterException =~ s/\s+//g;
                $setterException =~ s/\s+//g;
                @{$newDataNode->getterExceptions} = split(/,/, $getterException);
                @{$newDataNode->setterExceptions} = split(/,/, $setterException);
            } elsif (($line !~ s/^\s*$//g) and ($line !~ /^\s*const/)) {
                $line =~ /$IDLStructure::interfaceMethodSelector/ or die "Parsing error!\nSource:\n$line\n)";

                my $isStatic = defined($1);
                my $methodExtendedAttributes = (defined($2) ? $2 : " "); chop($methodExtendedAttributes);
                my $methodType = (defined($3) ? $3 : die("Parsing error!\nSource:\n$line\n)"));
                my $methodName = (defined($4) ? $4 : die("Parsing error!\nSource:\n$line\n)"));
                my $methodSignature = (defined($5) ? $5 : die("Parsing error!\nSource:\n$line\n)"));

                ('' =~ /^/); # Reset variables needed for regexp matching

                $line =~ /$IDLStructure::raisesSelector/;
                my $methodException = (defined($1) ? $1 : "");

                my $newDataNode = new domFunction();

                $newDataNode->isStatic($isStatic);
                $newDataNode->signature(new domSignature());
                $newDataNode->signature->name($methodName);
                $newDataNode->signature->type($methodType);
                $newDataNode->signature->extendedAttributes(parseExtendedAttributes($methodExtendedAttributes));

                print "  |  |-  Method; TYPE \"$methodType\" NAME \"$methodName\" EXCEPTION? \"$methodException\"" .
                    dumpExtendedAttributes("\n  |              ", $newDataNode->signature->extendedAttributes) . "\n" unless $beQuiet;

                $methodException =~ s/\s+//g;
                @{$newDataNode->raisesExceptions} = split(/,/, $methodException);

                parseParameters($newDataNode, $methodSignature);

                my $arrayRef = $dataNode->functions;
                push(@$arrayRef, $newDataNode);
            } elsif ($line =~ /^\s*const/) {
                $line =~ /$IDLStructure::constantSelector/;
                my $constExtendedAttributes = (defined($1) ? $1 : " "); chop($constExtendedAttributes);
                my $constType = (defined($2) ? $2 : die("Parsing error!\nSource:\n$line\n)"));
                my $constName = (defined($3) ? $3 : die("Parsing error!\nSource:\n$line\n)"));
                my $constValue = (defined($4) ? $4 : die("Parsing error!\nSource:\n$line\n)"));

                my $newDataNode = new domConstant();
                $newDataNode->name($constName);
                $newDataNode->type($constType);
                $newDataNode->value($constValue);
                $newDataNode->extendedAttributes(parseExtendedAttributes($constExtendedAttributes));

                my $arrayRef = $dataNode->constants;
                push(@$arrayRef, $newDataNode);

                print "  |   |>  Constant; TYPE \"$constType\" NAME \"$constName\" VALUE \"$constValue\"\n" unless $beQuiet;
            }
        }

        print "  |----> Interface; NAME \"$interfaceName\"" .
            dumpExtendedAttributes("\n  |                 ", $dataNode->extendedAttributes) . "\n |-\n |\n" unless $beQuiet;
    }
}

# Internal helper
sub DetermineParseMode
{
    my $object = shift;  
    my $line = shift;

    my $mode = MODE_UNDEF;
    if ($_ =~ /module/) {
        $mode = MODE_MODULE;
    } elsif ($_ =~ /interface/) {
        $mode = MODE_INTERFACE;
    }

    return $mode;
}

# Internal helper
sub ProcessSection
{
    my $object = shift;
  
    if ($parseMode eq MODE_MODULE) {
        die ("Two modules in one file! Fatal error!\n") if ($document ne 0);
        $document = new idlDocument();
        $object->ParseModule($document);
    } elsif ($parseMode eq MODE_INTERFACE) {
        my $node = new domClass();
        $object->ParseInterface($node, "interface");
    
        die ("No module specified! Fatal Error!\n") if ($document eq 0);
        my $arrayRef = $document->classes;
        push(@$arrayRef, $node);
    }

    @temporaryContent = "";
}

1;
