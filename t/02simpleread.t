# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl 1.t'

use Test::More tests => 3;

use Class::Colon Person => [ qw(first middle last dob) ];

#________ Test file reading _____
my $read_people = Person->READ_FILE('t/sample.dat');

my $real_people = [
bless( {
        'dob' => '05/03/1968',
        'middle' => 'David',
        'first' => 'Crow',
        'last' => 'Phil'
        }, 'Person' ),
bless( {
        'dob' => '04/23/1976',
        'middle' => 'Diane',
        'first' => 'Crow',
        'last' => 'Lisa'
        }, 'Person' )
];

is_deeply($read_people, $real_people, "all scalar READ_FILE");

#_______ Test alternate delimiter _____

open INPUT, "t/sample.dat" or die "couldn't read t/sample.dat";

my $handle_people = Person->READ_HANDLE(*INPUT);

close INPUT;

is_deeply($handle_people, $real_people, "all scalar READ_HANDLE");

#_______ Test alternate delimiter _____
my $new_delim    = Person->DELIM(qr/,/);
my $comma_people = Person->READ_FILE('t/comma.dat');

is_deeply($comma_people, $real_people, "comma delim");
