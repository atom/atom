#
# WebKit IDL parser
#
# Copyright (C) 2005 Nikolas Zimmermann <wildfox@kde.org>
# Copyright (C) 2006 Samuel Weinig <sam.weinig@gmail.com>
# Copyright (C) 2007, 2008, 2009, 2010 Apple Inc. All rights reserved.
# Copyright (C) 2009 Cameron McCormack <cam@mcc.id.au>
# Copyright (C) Research In Motion Limited 2010. All rights reserved.
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

package CodeGenerator;

use strict;

use File::Find;

my $useDocument = "";
my $useGenerator = "";
my $useOutputDir = "";
my $useOutputHeadersDir = "";
my $useDirectories = "";
my $useLayerOnTop = 0;
my $preprocessor;
my $writeDependencies = 0;
my $defines = "";

my $codeGenerator = 0;

my $verbose = 0;

my %numericTypeHash = ("int" => 1, "short" => 1, "long" => 1, "long long" => 1,
                       "unsigned int" => 1, "unsigned short" => 1,
                       "unsigned long" => 1, "unsigned long long" => 1,
                       "float" => 1, "double" => 1);

my %primitiveTypeHash = ( "boolean" => 1, "void" => 1, "Date" => 1);

my %stringTypeHash = ("DOMString" => 1, "AtomicString" => 1);

my %nonPointerTypeHash = ("DOMTimeStamp" => 1, "CompareHow" => 1);

my %svgAnimatedTypeHash = ("SVGAnimatedAngle" => 1, "SVGAnimatedBoolean" => 1,
                           "SVGAnimatedEnumeration" => 1, "SVGAnimatedInteger" => 1,
                           "SVGAnimatedLength" => 1, "SVGAnimatedLengthList" => 1,
                           "SVGAnimatedNumber" => 1, "SVGAnimatedNumberList" => 1,
                           "SVGAnimatedPreserveAspectRatio" => 1,
                           "SVGAnimatedRect" => 1, "SVGAnimatedString" => 1,
                           "SVGAnimatedTransformList" => 1);

my %svgAttributesInHTMLHash = ("class" => 1, "id" => 1, "onabort" => 1, "onclick" => 1,
                               "onerror" => 1, "onload" => 1, "onmousedown" => 1,
                               "onmousemove" => 1, "onmouseout" => 1, "onmouseover" => 1,
                               "onmouseup" => 1, "onresize" => 1, "onscroll" => 1,
                               "onunload" => 1);

my %svgTypeNeedingTearOff = (
    "SVGAngle" => "SVGPropertyTearOff<SVGAngle>",
    "SVGLength" => "SVGPropertyTearOff<SVGLength>",
    "SVGLengthList" => "SVGListPropertyTearOff<SVGLengthList>",
    "SVGMatrix" => "SVGPropertyTearOff<SVGMatrix>",
    "SVGNumber" => "SVGPropertyTearOff<float>",
    "SVGNumberList" => "SVGListPropertyTearOff<SVGNumberList>",
    "SVGPathSegList" => "SVGPathSegListPropertyTearOff",
    "SVGPoint" => "SVGPropertyTearOff<FloatPoint>",
    "SVGPointList" => "SVGListPropertyTearOff<SVGPointList>",
    "SVGPreserveAspectRatio" => "SVGPropertyTearOff<SVGPreserveAspectRatio>",
    "SVGRect" => "SVGPropertyTearOff<FloatRect>",
    "SVGStringList" => "SVGStaticListPropertyTearOff<SVGStringList>",
    "SVGTransform" => "SVGPropertyTearOff<SVGTransform>",
    "SVGTransformList" => "SVGTransformListPropertyTearOff"
);

my %svgTypeWithWritablePropertiesNeedingTearOff = (
    "SVGPoint" => 1,
    "SVGMatrix" => 1
);

# Cache of IDL file pathnames.
my $idlFiles;

# Default constructor
sub new
{
    my $object = shift;
    my $reference = { };

    $useDirectories = shift;
    $useGenerator = shift;
    $useOutputDir = shift;
    $useOutputHeadersDir = shift;
    $useLayerOnTop = shift;
    $preprocessor = shift;
    $writeDependencies = shift;
    $verbose = shift;

    bless($reference, $object);
    return $reference;
}

sub StripModule($)
{
    my $object = shift;
    my $name = shift;
    $name =~ s/[a-zA-Z0-9]*:://;
    return $name;
}

sub ProcessDocument
{
    my $object = shift;
    $useDocument = shift;
    $defines = shift;

    my $ifaceName = "CodeGenerator" . $useGenerator;
    require $ifaceName . ".pm";

    # Dynamically load external code generation perl module
    $codeGenerator = $ifaceName->new($object, $useOutputDir, $useOutputHeadersDir, $useLayerOnTop, $preprocessor, $writeDependencies, $verbose);
    unless (defined($codeGenerator)) {
        my $classes = $useDocument->classes;
        foreach my $class (@$classes) {
            print "Skipping $useGenerator code generation for IDL interface \"" . $class->name . "\".\n" if $verbose;
        }
        return;
    }

    # Start the actual code generation!
    $codeGenerator->GenerateModule($useDocument, $defines);

    my $classes = $useDocument->classes;
    foreach my $class (@$classes) {
        print "Generating $useGenerator bindings code for IDL interface \"" . $class->name . "\"...\n" if $verbose;
        $codeGenerator->GenerateInterface($class, $defines);
    }
}

sub FileNamePrefix
{
    my $object = shift;

    my $ifaceName = "CodeGenerator" . $useGenerator;
    require $ifaceName . ".pm";

    # Dynamically load external code generation perl module
    $codeGenerator = $ifaceName->new($object, $useOutputDir, $useOutputHeadersDir, $useLayerOnTop, $preprocessor, $writeDependencies, $verbose);
    return $codeGenerator->FileNamePrefix();
}

sub UpdateFile
{
    my $object = shift;
    my $fileName = shift;
    my $contents = shift;

    open FH, "> $fileName" or die "Couldn't open $fileName: $!\n";
    print FH $contents;
    close FH;
}

sub ForAllParents
{
    my $object = shift;
    my $dataNode = shift;
    my $beforeRecursion = shift;
    my $afterRecursion = shift;
    my $parentsOnly = shift;

    my $recurse;
    $recurse = sub {
        my $interface = shift;

        for (@{$interface->parents}) {
            my $interfaceName = $object->StripModule($_);
            my $parentInterface = $object->ParseInterface($interfaceName, $parentsOnly);

            if ($beforeRecursion) {
                &$beforeRecursion($parentInterface) eq 'prune' and next;
            }
            &$recurse($parentInterface);
            &$afterRecursion($parentInterface) if $afterRecursion;
        }
    };

    &$recurse($dataNode);
}

sub AddMethodsConstantsAndAttributesFromParentClasses
{
    # Add to $dataNode all of its inherited interface members, except for those
    # inherited through $dataNode's first listed parent.  If an array reference
    # is passed in as $parents, the names of all ancestor interfaces visited
    # will be appended to the array.  If $collectDirectParents is true, then
    # even the names of $dataNode's first listed parent and its ancestors will
    # be appended to $parents.

    my $object = shift;
    my $dataNode = shift;
    my $parents = shift;
    my $collectDirectParents = shift;

    my $first = 1;

    $object->ForAllParents($dataNode, sub {
        my $interface = shift;

        if ($first) {
            # Ignore first parent class, already handled by the generation itself.
            $first = 0;

            if ($collectDirectParents) {
                # Just collect the names of the direct ancestor interfaces,
                # if necessary.
                push(@$parents, $interface->name);
                $object->ForAllParents($interface, sub {
                    my $interface = shift;
                    push(@$parents, $interface->name);
                }, undef, 1);
            }

            # Prune the recursion here.
            return 'prune';
        }

        # Collect the name of this additional parent.
        push(@$parents, $interface->name) if $parents;

        print "  |  |>  -> Inheriting "
            . @{$interface->constants} . " constants, "
            . @{$interface->functions} . " functions, "
            . @{$interface->attributes} . " attributes...\n  |  |>\n" if $verbose;

        # Add this parent's members to $dataNode.
        push(@{$dataNode->constants}, @{$interface->constants});
        push(@{$dataNode->functions}, @{$interface->functions});
        push(@{$dataNode->attributes}, @{$interface->attributes});
    });
}

sub GetMethodsAndAttributesFromParentClasses
{
    # For the passed interface, recursively parse all parent
    # IDLs in order to find out all inherited properties/methods.

    my $object = shift;
    my $dataNode = shift;

    my @parentList = ();

    $object->ForAllParents($dataNode, undef, sub {
        my $interface = shift;

        my $hash = {
            "name" => $interface->name,
            "functions" => $interface->functions,
            "attributes" => $interface->attributes
        };

        unshift(@parentList, $hash);
    });

    return @parentList;
}

sub FindSuperMethod
{
    my ($object, $dataNode, $functionName) = @_;
    my $indexer;
    $object->ForAllParents($dataNode, undef, sub {
        my $interface = shift;
        foreach my $function (@{$interface->functions}) {
            if ($function->signature->name eq $functionName) {
                $indexer = $function->signature;
                return 'prune';
            }
        }
    });
    return $indexer;
}

sub IDLFileForInterface
{
    my $object = shift;
    my $interfaceName = shift;

    unless ($idlFiles) {
        my $sourceRoot = $ENV{SOURCE_ROOT};
        my @directories = map { $_ = "$sourceRoot/$_" if $sourceRoot && -d "$sourceRoot/$_"; $_ } @$useDirectories;

        $idlFiles = { };

        my $wanted = sub {
            $idlFiles->{$1} = $File::Find::name if /^([A-Z].*)\.idl$/;
            $File::Find::prune = 1 if /^\../;
        };
        find($wanted, @directories);
    }

    return $idlFiles->{$interfaceName};
}

sub ParseInterface
{
    my $object = shift;
    my $interfaceName = shift;
    my $parentsOnly = shift;

    return undef if $interfaceName eq 'Object';

    # Step #1: Find the IDL file associated with 'interface'
    my $filename = $object->IDLFileForInterface($interfaceName)
        or die("Could NOT find IDL file for interface \"$interfaceName\"!\n");

    print "  |  |>  Parsing parent IDL \"$filename\" for interface \"$interfaceName\"\n" if $verbose;

    # Step #2: Parse the found IDL file (in quiet mode).
    my $parser = IDLParser->new(1);
    my $document = $parser->Parse($filename, $defines, $preprocessor, $parentsOnly);

    foreach my $interface (@{$document->classes}) {
        return $interface if $interface->name eq $interfaceName;
    }

    die("Could NOT find interface definition for $interfaceName in $filename");
}

# Helpers for all CodeGenerator***.pm modules

sub AvoidInclusionOfType
{
    my $object = shift;
    my $type = shift;

    # Special case: SVGPoint.h / SVGNumber.h do not exist.
    return 1 if $type eq "SVGPoint" or $type eq "SVGNumber";
    return 0;
}

sub IsNumericType
{
    my $object = shift;
    my $type = shift;

    return 1 if $numericTypeHash{$type};
    return 0;
}

sub IsPrimitiveType
{
    my $object = shift;
    my $type = shift;

    return 1 if $primitiveTypeHash{$type};
    return 1 if $numericTypeHash{$type};
    return 0;
}

sub IsStringType
{
    my $object = shift;
    my $type = shift;

    return 1 if $stringTypeHash{$type};
    return 0;
}

sub IsNonPointerType
{
    my $object = shift;
    my $type = shift;

    return 1 if $nonPointerTypeHash{$type} or $primitiveTypeHash{$type} or $numericTypeHash{$type};
    return 0;
}

sub IsSVGTypeNeedingTearOff
{
    my $object = shift;
    my $type = shift;

    return 1 if exists $svgTypeNeedingTearOff{$type};
    return 0;
}

sub IsSVGTypeWithWritablePropertiesNeedingTearOff
{
    my $object = shift;
    my $type = shift;

    return 1 if $svgTypeWithWritablePropertiesNeedingTearOff{$type};
    return 0;
}

sub GetSVGTypeNeedingTearOff
{
    my $object = shift;
    my $type = shift;

    return $svgTypeNeedingTearOff{$type} if exists $svgTypeNeedingTearOff{$type};
    return undef;
}

sub GetSVGWrappedTypeNeedingTearOff
{
    my $object = shift;
    my $type = shift;

    my $svgTypeNeedingTearOff = $object->GetSVGTypeNeedingTearOff($type);
    return $svgTypeNeedingTearOff if not $svgTypeNeedingTearOff;

    if ($svgTypeNeedingTearOff =~ /SVGPropertyTearOff/) {
        $svgTypeNeedingTearOff =~ s/SVGPropertyTearOff<//;
    } elsif ($svgTypeNeedingTearOff =~ /SVGListPropertyTearOff/) {
        $svgTypeNeedingTearOff =~ s/SVGListPropertyTearOff<//;
    } elsif ($svgTypeNeedingTearOff =~ /SVGStaticListPropertyTearOff/) {
        $svgTypeNeedingTearOff =~ s/SVGStaticListPropertyTearOff<//;
    }  elsif ($svgTypeNeedingTearOff =~ /SVGTransformListPropertyTearOff/) {
        $svgTypeNeedingTearOff =~ s/SVGTransformListPropertyTearOff<//;
    } 

    $svgTypeNeedingTearOff =~ s/>//;
    return $svgTypeNeedingTearOff;
}

sub IsSVGAnimatedType
{
    my $object = shift;
    my $type = shift;

    return 1 if $svgAnimatedTypeHash{$type};
    return 0;
}

# Uppercase the first letter while respecting WebKit style guidelines.
# E.g., xmlEncoding becomes XMLEncoding, but xmlllang becomes Xmllang.
sub WK_ucfirst
{
    my ($object, $param) = @_;
    my $ret = ucfirst($param);
    $ret =~ s/Xml/XML/ if $ret =~ /^Xml[^a-z]/;

    return $ret;
}

# Lowercase the first letter while respecting WebKit style guidelines.
# URL becomes url, but SetURL becomes setURL.
sub WK_lcfirst
{
    my ($object, $param) = @_;
    my $ret = lcfirst($param);
    $ret =~ s/hTML/html/ if $ret =~ /^hTML/;
    $ret =~ s/uRL/url/ if $ret =~ /^uRL/;
    $ret =~ s/jS/js/ if $ret =~ /^jS/;
    $ret =~ s/xML/xml/ if $ret =~ /^xML/;
    $ret =~ s/xSLT/xslt/ if $ret =~ /^xSLT/;

    # For HTML5 FileSystem API Flags attributes.
    # (create is widely used to instantiate an object and must be avoided.)
    $ret =~ s/^create/isCreate/ if $ret =~ /^create$/;
    $ret =~ s/^exclusive/isExclusive/ if $ret =~ /^exclusive$/;

    return $ret;
}

# Return the C++ namespace that a given attribute name string is defined in.
sub NamespaceForAttributeName
{
    my ($object, $interfaceName, $attributeName) = @_;
    return "SVGNames" if $interfaceName =~ /^SVG/ && !$svgAttributesInHTMLHash{$attributeName};
    return "HTMLNames";
}

# Identifies overloaded functions and for each function adds an array with
# links to its respective overloads (including itself).
sub LinkOverloadedFunctions
{
    my ($object, $dataNode) = @_;

    my %nameToFunctionsMap = ();
    foreach my $function (@{$dataNode->functions}) {
        my $name = $function->signature->name;
        $nameToFunctionsMap{$name} = [] if !exists $nameToFunctionsMap{$name};
        push(@{$nameToFunctionsMap{$name}}, $function);
        $function->{overloads} = $nameToFunctionsMap{$name};
        $function->{overloadIndex} = @{$nameToFunctionsMap{$name}};
    }
}

sub AttributeNameForGetterAndSetter
{
    my ($generator, $attribute) = @_;

    my $attributeName = $attribute->signature->name;
    my $attributeType = $generator->StripModule($attribute->signature->type);

    # Avoid clash with C++ keyword.
    $attributeName = "_operator" if $attributeName eq "operator";

    # SVGAElement defines a non-virtual "String& target() const" method which clashes with "virtual String target() const" in Element.
    # To solve this issue the SVGAElement method was renamed to "svgTarget", take care of that when calling this method.
    $attributeName = "svgTarget" if $attributeName eq "target" and $attributeType eq "SVGAnimatedString";

    # SVG animated types need to use a special attribute name.
    # The rest of the special casing for SVG animated types is handled in the language-specific code generators.
    $attributeName .= "Animated" if $generator->IsSVGAnimatedType($attributeType);

    return $attributeName;
}

sub ContentAttributeName
{
    my ($generator, $implIncludes, $interfaceName, $attribute) = @_;

    my $contentAttributeName = $attribute->signature->extendedAttributes->{"Reflect"};
    return undef if !$contentAttributeName;

    $contentAttributeName = lc $generator->AttributeNameForGetterAndSetter($attribute) if $contentAttributeName eq "1";

    my $namespace = $generator->NamespaceForAttributeName($interfaceName, $contentAttributeName);

    $implIncludes->{"${namespace}.h"} = 1;
    return "WebCore::${namespace}::${contentAttributeName}Attr";
}

sub GetterExpression
{
    my ($generator, $implIncludes, $interfaceName, $attribute) = @_;

    my $contentAttributeName = $generator->ContentAttributeName($implIncludes, $interfaceName, $attribute);

    if (!$contentAttributeName) {
        return ($generator->WK_lcfirst($generator->AttributeNameForGetterAndSetter($attribute)));
    }

    my $functionName;
    if ($attribute->signature->extendedAttributes->{"URL"}) {
        if ($attribute->signature->extendedAttributes->{"NonEmpty"}) {
            $functionName = "getNonEmptyURLAttribute";
        } else {
            $functionName = "getURLAttribute";
        }
    } elsif ($attribute->signature->type eq "boolean") {
        $functionName = "hasAttribute";
    } elsif ($attribute->signature->type eq "long") {
        $functionName = "getIntegralAttribute";
    } elsif ($attribute->signature->type eq "unsigned long") {
        $functionName = "getUnsignedIntegralAttribute";
    } else {
        $functionName = "getAttribute";
    }

    return ($functionName, $contentAttributeName);
}

sub SetterExpression
{
    my ($generator, $implIncludes, $interfaceName, $attribute) = @_;

    my $contentAttributeName = $generator->ContentAttributeName($implIncludes, $interfaceName, $attribute);

    if (!$contentAttributeName) {
        return ("set" . $generator->WK_ucfirst($generator->AttributeNameForGetterAndSetter($attribute)));
    }

    my $functionName;
    if ($attribute->signature->type eq "boolean") {
        $functionName = "setBooleanAttribute";
    } elsif ($attribute->signature->type eq "long") {
        $functionName = "setIntegralAttribute";
    } elsif ($attribute->signature->type eq "unsigned long") {
        $functionName = "setUnsignedIntegralAttribute";
    } else {
        $functionName = "setAttribute";
    }

    return ($functionName, $contentAttributeName);
}

sub ShouldCheckEnums
{
    my $dataNode = shift;
    return not $dataNode->extendedAttributes->{"DontCheckEnums"};
}

sub GenerateConditionalStringFromAttributeValue
{
    my $generator = shift;
    my $conditional = shift;

    my $operator = ($conditional =~ /&/ ? '&' : ($conditional =~ /\|/ ? '|' : ''));
    if ($operator) {
        # Avoid duplicated conditions.
        my %conditions;
        map { $conditions{$_} = 1 } split('\\' . $operator, $conditional);
        return "ENABLE(" . join(") $operator$operator ENABLE(", sort keys %conditions) . ")";
    } else {
        return "ENABLE(" . $conditional . ")";
    }
}

sub GenerateCompileTimeCheckForEnumsIfNeeded
{
    my ($generator, $dataNode) = @_;
    my $interfaceName = $dataNode->name;
    my @checks = ();
    # If necessary, check that all constants are available as enums with the same value.
    if (ShouldCheckEnums($dataNode) && @{$dataNode->constants}) {
        push(@checks, "\n");
        foreach my $constant (@{$dataNode->constants}) {
            my $reflect = $constant->extendedAttributes->{"Reflect"};
            my $name = $reflect ? $reflect : $constant->name;
            my $value = $constant->value;
            my $conditional = $constant->extendedAttributes->{"Conditional"};

            if ($conditional) {
                my $conditionalString = $generator->GenerateConditionalStringFromAttributeValue($conditional);
                push(@checks, "#if ${conditionalString}\n");
            }

            push(@checks, "COMPILE_ASSERT($value == ${interfaceName}::$name, ${interfaceName}Enum${name}IsWrongUseDontCheckEnums);\n");

            if ($conditional) {
                push(@checks, "#endif\n");
            }
        }
        push(@checks, "\n");
    }
    return @checks;
}

1;
