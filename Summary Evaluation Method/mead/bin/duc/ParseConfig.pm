package ParseConfig;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(parse_config);

=head1 NAME

ParseConfig -- parse a config file and return a hash of attribute/value pairs.

=head1 SYNOPSIS

    use ParseConfig;
    my %config = parse_config("nie.cfg");

=head1 DESCRIPTION

The config file we parse is usually nie.cfg.

=head1 METHODS

=over 2

=cut

=item parse_config("config_file")

    my %config = parse_config("configfile.cfg");

=cut

# parse a config file into a bunch of attr/value pairs.
sub parse_config {
    my $config_file = shift or "nie.cfg";
    my $line;
    my %config;

    if (! open (CFG, $config_file) ) {
	die "Can't open file: $config_file";
    } else {

	while ($line = <CFG>) {
	    $line =~ s/^\s+//;
	    $line =~ s/\s+$//;
	    next if ($line =~ /^\#/ || $line =~ /^\s*$/);
	    
	    if ($line =~ /^(\w+)\s+(.+)/) {
		#print "The value of \'$1\' is \'$2\'\n";
		$config{$1} = $2;
	    }   
	}

	close CFG;
    }

    return %config;
}
