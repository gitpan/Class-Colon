# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl 1.t'

use Test::More tests => 3;
BEGIN { use_ok('Class::Colon') };

use Class::Colon Person => [ qw(first middle last dob) ];

#________ Test the manufactured class Person ______

my $tp = Person->new();
isa_ok($tp, 'Person', "Person constructor");
$tp->first("Howdy");
$tp->last("Duty");
my $name = $tp->first() . " " . $tp->last();

is($name, "Howdy Duty", "Person first and last accessors");

