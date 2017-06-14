use strict;
use Irssi;
use Irssi::Irc;
use Twitch;
use threads;
use vars qw($VERSION %IRSSI);

$VERSION = "0.1";

%IRSSI = ( 
   authors     => "elevatorsimulator a.k.a. Mr. Man",
   contact     => "mr_man\@imap.cc",
   name        => "twitch",
   description => "simple twitch bot providing basic functionality like setting game or stream title, getting the viewer count or stream url, etc.",
   license     => "GPL v2 and any later",
   url         => "https://github.com/elevatorsimulator/irssi-twitch",
);

my $USAGE =
"irssi-twitch supports the following commands:
   !get <prop>       - retrieves the property <prop> of the current Twitch channel
   !set <prop> <val> - sets the property <prop> of the current Twitch channel to <val>
   !stream_urls      - retrieves the list of available stream urls for the current Twitch channel
Here, <prop> should be one of the following values:
   game              - The name of the \"game\" the current Twitch channel is streaming (can also be a generic term like \"creative\")
   title             - The title of the stream
";

my %_user_authorized = ();

sub init {
   Twitch::init(Irssi::settings_get_str('twitch-user'), Irssi::settings_get_str('twitch-token'));
}

sub print_to_win {
   my ($msg, $level, $log) = @_;
   $level ||= Irssi::MSGLEVEL_CLIENTCRAP;
   $log ||= 1;

   my $win = Irssi::active_win;
   $win->print($msg, $level);
   if ($log) {
      Irssi::print($msg, $level);
   }
}

sub msg_to {
   my ($server, $target, $msg) = @_;

   foreach (split("\n", $msg)) {
      $server->command("/msg $target $_");
   }
}

# args: $server, $nick
# returns: true, iff user $nick is authorized to use commands
sub user_authorized {
   my ($server, $nick) = @_;

   return $nick eq $server->{'nick'} || _user_authorized{$nick};
}

sub process_msg {
   my ($server, $msg, $nick, $target) = @_;

   if ($msg =~ /\s*!\s*set \s*(\w+)\s*(.*)/) {
      if (user_authorized($server, $nick)) {
         my $prop = $1;
         my $val = $2;

         print_to_win("Setting $prop to $val", Irssi::MSGLEVEL_NOTICES);
         my $thread = sub {
            if (my ($code, $msg) = Twitch::set_channel_property($prop, $val)) {
               print_to_win("Command failed with HTTP_CODE = $code, HTTP_MSG = $msg");
            } else {
               print_to_win("Command successful.");
            }
         };

         threads->new($thread);
      } else {
         print_to_win("Command $msg failed because user $nick is not authorized.", Irssi::MSGLEVEL_CLIENTERROR);
      }
   } elsif ($msg =~ /\s*!\s*get \s*(\w+)/) {
      if (user_authorized($server, $nick)) {
         my $prop = $1;

         my $thread = sub {
            my $val = Twitch::get_channel_property($prop);
            $server->command("/msg $target $prop = \"$val\"");
         };

         threads->new($thread);
      }
   } elsif ($msg =~ /\s*!\s*stream_urls(\s*|\s+(?<channel>\w+))\s*$/) {
      if (user_authorized($server, $nick)) {
         my $thread = sub {
            my $playlist = Twitch::get_stream_playlist($+{channel});
            if ($playlist) {
               msg_to($server, $target, "The following stream urls are available:");
               for my $entry (@$playlist) {
                  my ($url, $meta) = @$entry;
                  my $name = $meta->{'MEDIA'}->{'NAME'};
                  my $res = $meta->{'STREAM-INF'}->{'RESOLUTION'};
                  msg_to($server, $target, "name=$name, res=$res, url=$url");
               }
            } elsif (!Twitch::is_live($+{channel})) {
               msg_to($server, $target, "The stream is offline.");
            } else {
               msg_to($server, $target, "The stream seems to be online, but I still couldn't retrieve any stream urls.");
            }
         };

         threads->new($thread);
      }
   } elsif ($msg =~ /\s*!\s*help\s*$/) {
      msg_to($server, $target, $USAGE);
   }
}

# args: $msg, $nick, $address, $target
sub msg_public {
   my ($server, $msg, $nick, $address, $target) = @_;
   
   return process_msg($server, $msg, $nick, $target);
}

sub msg_own_public {
   my ($server, $msg, $target) = @_;

   return process_msg($server, $msg, $server->{'nick'}, $target);
}

##################
# Initialization #
# ################

Irssi::settings_add_str('irssi-bot', 'twitch-user', 'Set this to your Twitch username');
Irssi::settings_add_str('irssi-bot', 'twitch-token', 'Set this to your Twitch access token');
Irssi::signal_add_last('message public', 'msg_public');
Irssi::signal_add_last('message own_public', 'msg_own_public');
Irssi::signal_add_last('setup changed', 'init');
init();
