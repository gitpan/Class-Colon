package Class::Colon;
use strict; use warnings;

our $VERSION = "0.01";

=head1 NAME

Class::Colon - Makes objects out of colon delimited records

=head1 SYNOPSIS

    use Date;
    use Class::Colon
        Person  => [ qw ( first middle family date_of_birth=Date=new ) ],
        Address => [ qw ( street city province code country          ) ];

    Person->DELIM(qr/,/); # change from colon to comma for delimeter
    my $names = Person->READ_FILE($file_name);
    foreach my $name (@$names) {
        print $name->family, ",", $name->first, $name->middle, "\n";
    }

    open ADDRESS_FILE, "addresses.dat" or die "...\n";
    my $addresses = Address->READ_HANDLE(*ADDRESS_FILE);
    foreach my $address (@$addresses) {
        print $address->street . "\n"
        print $address->city . ", " . $address->province . "\n";
        print $address->country, "\n" if defined $address->country;
    }

=head1 DESCRIPTION

To turn your colon delimited file into a list of objects, use C<Class::Colon>,
giving it the name you want to use for the class and a list of column names
which will become attributes of the objects in the class.  List the names
in the order they appear in the input.  Missing fields will be set to undef.
Extra fields will be ignored.  Use lower case names for the fields.

Most fields will be simple scalars, but if one of the fields should be an
object, its entry should be of the form

    attribute_name=package_name=constructor_name

as shown above for C<date_of_birth> which is of type C<Date> whose constructor
is C<new>.  In above example, I could have omitted the constructor name, since
C<new> is the default.

You may objectify as many different record types as you like in one use
statement.  You may have multiple use statements throughout your program
or module.  If you are using this package from another package, you should
worry a little about namespace collision.  There is only one list of classes
made by this package.  The names must be unique or Bad Things will happen.
Feel free to include your module name in the names of the fabricated classes
as in:

    package YourModule;
    use Class::Colon YourModule::Person => [ qw( field names here ) ];

You wouldn't have to use the double colon, but it makes sense to me.

If your delimiter is not colon, call DELIM on I<your> class I<before> calling
C<READ_FILE>.  Pass it a pattern in the form qr/$your_delim_here/.  It
must be a regular expression, using qr is the easiest way to make that happen.

=head1 ABSTRACT

  This module objectifies colon separated data files into objects.

=head2 EXPORT

None, this is object oriented.

=head1 METHODS

There are currently only a few methods.  There is one class method C<READ_FILE>
(for each key in the hash you passed to use).  There is also a dual
get/set accessor for each field.  Finally, there is a DELIM method which
allows you to set the delimiter.  This can be any valid pattern (regex),
but it applies to all fields in the file.  You may not use DELIM
as the name of one of your fields.  In fact, you should consider every
ALL_CAPS name reserved.  I may use those to support other configurations
in the future.

In addition to retrieving the attributes through accessor methods, you
could peek directly at the data.  It is stored in a hash so the following
are equivalent:

    my $country = $address->country();

and

    my $country = $address->{country};

Using this fact might make some things neater in your code (like print
statements.  It also saves a tiny amount of time.  Yet, our OO teachers
will smack our hands, if they hear about this little arrangement.  I have no
plans to change the implementation, but they tell me never to make such
promises.

At this point there are no output methods.  That may change in the future.

=cut

use Carp;

our %simulated_classes;

sub import {
    my $class = shift;
    my %fakes = @_;

    foreach my $fake (keys %fakes) {
        no strict;
#        *{"$fake\::READ_FILE"} = $class->can("read_file");
        *{"$fake\::new"}         = sub { return bless {}, shift; };
        *{"$fake\::READ_FILE"}   = \&{"$class\::read_file"};
        *{"$fake\::READ_HANDLE"} = \&{"$class\::read_handle"};
        *{"$fake\::DELIM"}       = \&{"$class\::DELIM"};

        my @attributes;
        foreach my $col (@{$fakes{$fake}}) {
            my ($name, $type, $constructor)  = split /=/, $col;
            *{"$fake\::$name"} = _make_accessor($name, $type, $constructor);
            push @attributes, $name;
        }
        $simulated_classes{$fake} = {ATTRS => \@attributes, DELIM => qr/:/};
    }
}

sub _make_accessor {
    my $attribute   = shift;
    my $type        = shift;
    my $constructor = shift || "new";

    if (defined $type) { # we need to call a constructor
        return sub {
            my $self            = shift;
            my $new_val         = shift;
            if (defined $new_val) {
                $self->{$attribute} = $type->$constructor($new_val)
            }
            return $self->{$attribute};
        };
    }
    else { # we can just dump the scalar into the attribute
        return sub {
            my $self            = shift;
            my $new_val         = shift;
            $self->{$attribute} = $new_val if defined $new_val;
            return $self->{$attribute};
        };
    }
}

=head2 DELIM

Call this through one of the names you supplied in your use statement.  Pass
it a pattern in the form qr/$delim/.  For example, you could say

    Person->DELIM(qr/;/);

to change the delimiter from colon to semi-colon for Person.

=cut

sub DELIM {
    my $fake_class = shift;
    my $pattern    = shift;

    if (defined $pattern) {
        $simulated_classes{$fake_class}{DELIM} = $pattern;
    }
    return $simulated_classes{$fake_class}{DELIM};
}

=head2 READ_FILE and READ_HANDLE

Call these mehtods through one of the names you supplied in your use
statement.

Both READ_FILE and READ_HANDLE return an array reference with one element
for each line in your input file.  All lines are represented even if they
are blank or start with #.  The array elements are objects of the same type
as the name you used to call the method.  Think of these as super constructors,
instead of making one object at a time, they make as many as they can from
your input.

READ_FILE takes the name of a file, which it opens and reads.

READ_HANDLE takes a handle open for reading.

=cut

sub read_file {
    my $class    = shift;
    my $file     = shift;

    open FILE,   "$file" or croak "Couldn't read $file: $!";
    my $retval   = $class->READ_HANDLE(*FILE);
    close FILE;

    return $retval;
}

sub read_handle {
    my $class    = shift;
    my $handle   = shift;
    my $config   = $simulated_classes{$class};
    my $col_list = $config->{ATTRS};

    my @rows;
    while (<$handle>) {
        chomp;
        my $new_object = $class->new();
        my @cols       = split $config->{DELIM};
        foreach my $i (0 .. @cols - 1) {
            my $method = $col_list->[$i];
            $new_object->$method($cols[$i]);
        }
        push @rows, $new_object;
    }
    return \@rows;
}

=head2 accessors

For each attribute you name in your use statement, there is a corresponding
dual get/set accessor.  The names of the accessors are the same as the names
you used (how convenient).

=head1 BUGS and OMISSIONS

There are no output methods.

Quotes are not special.  If a colon (or the DELIM of your choice) is
inside quotes, it still counts as a field separator.

=head1 AUTHOR

Phil Crow, E<lt>philcrow2000@yahoo.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2003 by Phil Crow, all rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut

1;
