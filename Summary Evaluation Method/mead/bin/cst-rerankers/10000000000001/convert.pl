#!/usr/local/bin/perl -w

use strict;

while (<>)
{
 s/DID=\"(\d+)\"/DID=\"$1\.10000000000001\"/g;

	print $_;
}
