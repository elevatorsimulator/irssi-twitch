package M3U;

use strict;

#parses a line containing a comma separated list of attributes
#e.g. $line = "VAL1=2, VAL2=\"2\""
#would return {VAL1 => "2", VAL2 => "2"}
sub parse_attribute_list {
   my ($line) = @_;
   my $attributes = {};

   my $var_name=qr/[a-zA-Z0-9\-_]+/;
   my $unquoted_str = qr/(?<val>[^",]*)/;
   my $quoted_str = qr/"(?<val>(?:[^"\\]|\\.)*)"/;
   my $pattern = qr/^\s*(?<var>$var_name)\s*=\s*($unquoted_str|$quoted_str)\s*(,(?<rest>.*$)|$)/;

   while ($line =~ /$pattern/) {
      $attributes->{$+{var}} = $+{val};
      $line = $+{rest};
   }

   return $attributes;
}

# parses m3u(8) file $file
#
# returns: list ($item1, $item2, ...) of entries
#          each one of them of the form
#          $item = [$url, $meta]
#          where $url is the url of the media item
#          and $meta is a hash; if NAME is a key in $meta, then
#          #EXT-X-NAME:<something> is a tag appearing before $url
#          and $meta->{NAME} = <something>
sub parse_m3u_file {
   my ($file) = @_;

   my @items = ();
   open(my $fh, "<", $file) or die "Could not open file '$file' $!";
   # first line of file must be "#EXTM3U"
   my $first_line = <$fh>;
   $first_line =~ /^\#EXTM3U$/ or die "Invalid format: '$file' is not a M3U file $!";
   my $meta = {};
   while (my $row = <$fh>) {
      if ($row =~ /^\#EXT-X-([-|A-Z]+):(.*)$/) { #this line contains meta-data
         $meta->{$1} = parse_attribute_list($2);
      } else { #this must be a url then
         push(@items, [$row, $meta]);
         $meta = {};
      }
   }
   close($fh);

   return \@items;
}

sub parse_m3u_string {
   my ($str) = @_;

   my @items = ();
   my @lines = split(/^/m, $str);
   # first line of file must be "#EXTM3U"
   my $first_line = shift @lines;
   $first_line =~ /^\#EXTM3U$/ or die "Invalid format: given string is not a M3U file";
   my $meta = {};
   while (my $row = shift @lines) {
      if ($row =~ /^\#EXT-X-([-|A-Z]+):(.*)$/) { #this line contains meta-data
         $meta->{$1} = parse_attribute_list($2);
      } else { #this must be a url then
         push(@items, [$row, $meta]);
         $meta = {};
      }
   }

   return \@items;
}

1; # perl's module behaviour is weird
