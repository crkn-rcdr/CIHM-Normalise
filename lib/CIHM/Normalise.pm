package CIHM::Normalise;

=head1  NAME

CIHM::Normalise - some string normalisation functions

=head1 VERSION

Version 0.02

=cut

our $VERSION = '0.02';

=head1 AUTHOR

William Wueppelmann, C<< <wwueppelmann at crkn.ca> >>
Sascha Adler, C<< <sadler at crkn.ca> >>
Russell McOrmond, C<< <rmcormond at crkn.ca> >>

=head1 BUGS

Please report any bugs or feature requests through the web interface at
L<https://github.com/c7a/CIHM-Normalise>.  We will be notified, and then you'll
automatically be notified of progress on your bug as we make changes.

=head1 FUNCTIONS

=cut

use strict;
use warnings;
no if $] >= 5.018, warnings => "experimental";
use Date::Manip;
use feature qw(switch);
use Exporter qw(import);
our @EXPORT = qw(
    iso8601
);


our $DEBUG  = 0;  # Output extended debugging information to stderr
our $FAILED = 1; # Output notices of failure to find a date to stderr

=head2 iso8601(I<$datestring>,I<$max>)

Evaluate and convert a date to a full ISO-8601 date string. If not possible, return undef.

If $max is true, returns the greatest matching date; otherwise returns the minimum. (E.g.: 1980 will return 1980-12-31T23:59:59.999Z if $max is true and 1980-01-01T00:00:00.000Z otherwise.)

=cut

sub iso8601
{
    my($date, $max) = @_;
    my $template = "0001-01-01T00:00:00.000Z";
    $template = "9999-12-31T23:59:59.999Z" if ($max);
    my $indate = $date;

    # If we already have an unambiguous ISO-8601 date, don't mess around
    # with it. The following formats should be accepted:
    # YYYY
    # YYYY-MM-DD
    # YYYY-MM-DDTHH:MM:SS
    # YYYY-MM-DDTHH:MM:SS.sss
    # YYYY-MM-DDTHH:MM:SS.sssZ
    if ($date =~ /^(\d{4}(-\d{2}-\d{2}(T\d{2}:\d{2}:\d{2})?(\.\d{3}(Z)?)?)?)$/) {
        my $iso_date = $1;

        # Force YYYY-MM-00 and YYYY-00-00 dates to default values for the
        # range. TODO: we are conservatively putting the last day as the
        # 28th; it would be better to determine the right ending day for
        # the month.
        if ($max) {
            $iso_date =~ s/^(\d{4})-00/$1-12/;
            $iso_date =~ s/^(\d{4}-\d{2})-00/$1-28/;
        }
        else {
            $iso_date =~ s/^(\d{4})-00/$1-01/;
            $iso_date =~ s/^(\d{4}-\d{2})-00/$1-01/;
        }

        return $iso_date . substr($template, length($iso_date));
    }

    # Remove some characters that we never want to see
    $date =~ s/[\[\]\.\`_\?]//g;

    # Anything that contains a string of 5 or more digits is likely to
    # return garbage results, so we won't try to parse it.
    if ($date =~ /\d{5}/) {
        warn("Unparseble sequence of digits in date: $date\n") if ($FAILED);
        return "";
    }

    # The pattern ####-## is ambiguous, but we will assume it is a year
    # range, so we intercept it here.
    if($date =~ /^\s*(\d{2})(\d{2})\s*-\s*(\d{2})\s*$/) {
        if ($2 < $3) {
            return sprintf("%02d%02d-12-31T23:59:59.999Z", $1, $3) if ($max);
            return sprintf("%02d%02d-01-01T00:00:00.000Z", $1, $2);
        }
        else {
            return sprintf("%02d%02d-12-31T23:59:59.999Z", $1 + 1, $3) if ($max);
            return sprintf("%02d%02d-01-01T00:00:00.000Z", $1, $2);
        }
    }

    # Translate French month names into English
    $date =~ s/\bjanvier\b/January/i;
    $date =~ s/\bfévrier\b/February/i;
    $date =~ s/\bmars\b/March/i;
    $date =~ s/\bavril\b/April/i;
    $date =~ s/\bmai\b/May/i;
    $date =~ s/\bjuin\b/June/i;
    $date =~ s/\bjuillet\b/July/i;
    $date =~ s/\baoût\b/August/i;
    $date =~ s/\bseptembre\b/September/i;
    $date =~ s/\boctobre\b/October/i;
    $date =~ s/\bnovembre\b/November/i;
    $date =~ s/\bdécembre\b/December/i;

    # And some abbreviations
    $date =~ s/\bjanv/Jan/i;
    $date =~ s/\bfév(r)?/Feb/i;
    $date =~ s/\bjuil/Jul/i;
    $date =~ s/\bdéc/Dec/i;

    # And unbreak abbreviations like '75 (assuming 1900s)
    $date =~ s/\s+'(\d{2})(?:\b|$)/19$1/;

    # If we can parse this date using Date::Manip, create an ISO8601 date.
    # Eliminate any January 1st dates or 1st of the month dates, because
    # these might just be the defaults and not the actual date.
    my $parsed_date = ParseDate($date);
    if ($parsed_date) {
        $date = UnixDate($date, "%Y-%m-%d");
        $date =~ s/-01-01$//;
        $date =~ s/-01$//;
        warn("Parsed date: $date = $parsed_date\n") if ($DEBUG);
    }

    # Otherwise, try to parse out the date based on some common AACR2 date
    # conventions.
    else {
        warn ("iso8601: trying to match $date\n") if ($DEBUG);

        $date =~ s/l/1/g; # Ocassionally, "1" is mistyped as "l" (OCR issue?)

        # Some patterns we want to reuse
        my $ST = '(?:^|\b)';  # start of word or string
        my $CA = '(?:^|\b|c|ca|circa|e)'; # start of word, string, or c/ca/circa/e (F and E abbr's for circa)
        my $HY = '\s*-\s*';   # hyphen/dash with or without spaces
        my $EN = '(?:\b|$)';  # end of word or string

        $date = lc($date);      # and normalize the case

        if (0) {
        }

        # Eg 190?, 19?? 1??? or 190u, 19uu, 1uuu
        elsif ($date =~ /$ST(\d)[?u][?u][?u]$EN/) {
            warn "iso8601: matched $date" if ($DEBUG);
            if ($max) { $date = "${1}999" }
            else {$date = "${1}000" }
        }
        elsif ($date =~ /$ST(\d{2})[?u][?u]$EN/) {
            warn "iso8601: matched $date" if ($DEBUG);
            if ($max) { $date = "${1}99" }
            else { $date = "${1}00" }
        }
        elsif ($date =~ /$ST(\d{3})[?u]$EN/) {
            warn "iso8601: matched $date" if ($DEBUG);
            if ($max) { $date = "${1}9" }
            else { $date = "${1}0" }
        }

        # E.g. 1903-1904
        elsif ($date =~ /$ST(\d{4})$HY(\d{4})$EN/) {
            warn "iso8601: matched $date" if ($DEBUG);
            if ($max) { $date = $2 }
            else { $date = $1 }
        }

        # E.g. 1918-19; 1990-01, c.1923-24 (treat as: 1990-2001)
        elsif ($date =~ /$ST(?:$CA)?(\d{2})(\d{2})$HY(\d{2})$EN/) {
            warn "iso8601: matched $date" if ($DEBUG);
            if ($3 > $2) {
                if ($max) { $date = "$1$3" } else { $date = "$1$2" }
            }
            else {
                if ($max) { $date = "$1$2" } else { $date = sprintf("%2d%2d", $1 + 1, $3) }
            }
        }

        # E.g. 1903-4, c.1910-1
        elsif ($date =~ /$ST(?:$CA)?(\d{3})(\d{1})$HY(\d{1})$EN/) {
            warn "iso8601: matched $date" if ($DEBUG);
            if ($3 > $2) {
                if ($max) { $date = "$1$3" } else { $date = "$1$2" }
            }
            else {
                if ($max) { $date = "$1$2" } else { $date = sprintf("%3d%1d", $1 + 1, $3) }
            }
        }

        # E.g. 192-, 192-?, 19-, 19-?, c185-?, etc.
        elsif ($date =~ /$ST(?:$CA)?(\d{3})$HY/) {
            warn "iso8601: matched $date" if ($DEBUG);
            if ($max) { $date = "${1}9" } else { $date = "${1}0" }
        }
        elsif ($date =~ /$ST(?:$CA)?(\d{2})$HY/) {
            warn "iso8601: matched $date" if ($DEBUG);
            if ($max) { $date = "${1}99" } else { $date = "${1}00" }
        }

        # E.g. c1912- (this is bad form but occasionally appears)
        elsif ($date =~ /$ST(?:$CA)?(\d{4})$HY$/) {
            warn "iso8601: matched $date" if ($DEBUG);
            $date = $1;
        }

        # E.g.: 1900s; 1920s; 1920's; c.1920's
        elsif ($date =~ /$CA(\d{2})00(?:')?s/) {
            warn "iso8601: matched $date" if ($DEBUG);
            if ($max) { $date = "${1}99" } else { $date = "${1}00" }
        }
        elsif ($date =~ /$CA(\d{3})0(?:')?s/) {
            warn "iso8601: matched $date" if ($DEBUG);
            if ($max) { $date = "${1}9" } else { $date = "${1}0" }
        }

        # E.g. c.1920 or ca.1920, e1949
        elsif ($date =~ /$CA?\s*(\d{4})$/) {
            warn "iso8601: matched $date" if ($DEBUG);
            $date = $1;
        }

        # E.g. ca. 192, 192 (instead of ca. 1920s)
        elsif ($date =~ /^(?:$CA)?(\d{3})$/) {
            warn "iso8601: matched $date" if ($DEBUG);
            if ($max) { $date = "${1}9" } else { $date = "${1}0" }
        }

        # E.g. nov-77, jan-81; we assume 20th Century.
        elsif ($date =~ /^([a-zA-Z]{3})[ -](\d{2})$/) {
            my $month = lc($1);
            given ($month) {
                when('jan') { $date = "19$2-01" };
                when('feb') { $date = "19$2-02" };
                when('mar') { $date = "19$2-03" };
                when('apr') { $date = "19$2-04" };
                when('may') { $date = "19$2-05" };
                when('jun') { $date = "19$2-06" };
                when('jul') { $date = "19$2-07" };
                when('aug') { $date = "19$2-08" };
                when('sep') { $date = "19$2-09" };
                when('oct') { $date = "19$2-10" };
                when('nov') { $date = "19$2-11" };
                when('dec') { $date = "19$2-12" };
                default     { $date = "19$2"    };
            }
        }

        # E.g. 2-6-98 or 1-1-1998: we don't know which is the month, but
        # we can get the year.
        # TODO: if one of the numbers is > 12, then we can get the month
        # and year.
        elsif ($date =~ /$ST\d+-\d+-(\d{2})$EN/) {
            warn "iso8601: matched $date" if ($DEBUG);
            $date = "19$1";
        }
        elsif ($date =~ /$ST\d+-\d+-(\d{4})$EN/) {
            warn "iso8601: matched $date" if ($DEBUG);
            $date = $1;
        }

        # E.g.: early 20th century; late 20th century
        elsif ($date =~ /early (\d{2})th century/i) {
            warn "iso8601: matched $date" if ($DEBUG);
            my $yy = ${1} - 1;
            if ($max) { $date = "${yy}30" } else { $date = "${yy}00" }
        }
        elsif ($date =~ /late (\d{2})th century/i) {
            warn "iso8601: matched $date" if ($DEBUG);
            my $yy = ${1} - 1;
            if ($max) { $date = "${yy}70" } else { $date = "${yy}99" }
        }

        # No numerical characters at all
        elsif ($date !~ /\d/) {
            warn("iso8061: failed to match $date") if ($DEBUG);
            return "";
        }
    }

    warn("iso8601: processing $date") if ($DEBUG);

    # YYYY-MM-DDTHH:MM:SSZ
    # TODO: do we still need this?
    if ($date =~ /(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})Z/) {
        return $1 . substr($template, length($1));
    }

    # Date in the form YYYY-MM-DD
    if ($date =~ /^\d{4}-\d{2}-\d{2}$/) {
        return $date . substr($template, length($date));
    }

    # Date in the form YYYY-MM
    if ($date =~ /^\d{4}-(\d{2})$/) {
        # Adjust the template so that we have a legal end date.
        given ($1) {
            when (/01|03|05|07|08|10|12/) { ; }
            when (/04|06|09|11/) { $template =~ s/-31T/-30T/; }
            when ("02")          { $template =~ s/-31T/-28T/; }
        }
        return $date . substr($template, length($date));
    }

    # Date in the form YYYY, possibly with junk preceding or following
    if ($date =~ /\b(\d{4})\b/) {
        return $1 . substr($template, length($1));
    }

    warn("iso8601: null date for \"$indate\" modified to \"$date\"\n") if ($DEBUG || $FAILED);
    return "";
    #return $date;
}

1;
