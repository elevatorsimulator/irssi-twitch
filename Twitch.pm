package Twitch;

use strict;
use LWP::UserAgent;
use HTTP::Request;
use JSON::Parse 'parse_json';
use URI::Escape;
use M3U;

my $TOKEN = "";
my $USERNAME = "";
my $KRAKEN_API_BASE = "https://api.twitch.tv/kraken";
my $INTERNAL_API_BASE = "https://api.twitch.tv/api";

# sets $USERNAME and $TOKEN to $user and $token
sub init {
   my ($user, $token) = @_;
   $USERNAME = $user;
   $TOKEN = $token;
}

sub http_get {
   my ($url, $accept) = @_;

   my $ua = LWP::UserAgent->new;
   my $req = HTTP::Request->new(GET => $url);
   if (defined($accept)) {
      $req->header('Accept' => 'application/vnd.twitchtv.v3+json');
   }

   return $ua->request($req);
}

sub http_get_authenticated {
   my ($url) = @_;

   my $ua = LWP::UserAgent->new;
   my $req = HTTP::Request->new(GET => $url);
   $req->header('Accept' => 'application/vnd.twitchtv.v3+json');
   $req->header('Authorization' => "OAuth $TOKEN");

   return $ua->request($req);
}

sub http_put_authenticated {
   my ($url, $content) = @_;

   my $ua = LWP::UserAgent->new;
   my $req = HTTP::Request->new(PUT => $url);
   $req->header('Accept' => 'application/vnd.twitchtv.v3+json');
   $req->header('Authorization' => "OAuth $TOKEN");
   $req->header('Content-Type' => 'application/json');
   $req->content($content);

   return $ua->request($req);
}

sub get_stream_status {
   my ($channel) = @_;
   $channel ||= $USERNAME;

   my $resp = http_get("$KRAKEN_API_BASE/streams/$channel");
   my $x = parse_json($resp->decoded_content);

   return $x->{'stream'};
}

sub get_viewer_count {
   my ($channel) = @_;
   $channel ||= $USERNAME;

   return get_stream_status($channel)->{'viewers'};
}

sub is_live {
   my ($channel) = @_;
   $channel ||= $USERNAME;
  
   if (get_stream_status($channel)) {
      return 1;
   } else {
      return 0;
   }
}

sub get_stream_playlist {
   my ($channel) = @_;
   $channel ||= $USERNAME;

   my $json = parse_json(http_get("$INTERNAL_API_BASE/channels/$channel/access_token")->decoded_content);

   my $token = $json->{'token'};
   my $sig = $json->{'sig'};
   my $channelstring = lc $channel;
   my $tokenstring = uri_escape($token);
   my $rand = int(rand(1000000));
   my $url = "http://usher.twitch.tv/api/channel/hls/$channelstring.m3u8?player=twitchweb&token=$token&sig=$sig&allow_audio_only=true&allow_source=true&type=any&p=$rand";
   my $m3u_file = http_get($url)->decoded_content;


   my $m3u_playlist = eval { M3U::parse_m3u_string($m3u_file); };
   if ($@) { #an error occured
      $m3u_playlist = 0;
   }

   return $m3u_playlist;
}

# gets channel object
#
# returns: channel object
sub get_channel_object {
   my $resp = http_get_authenticated("$KRAKEN_API_BASE/channels/$USERNAME");
   
   return parse_json($resp->decoded_content);
}

# sets $prop to value $val
#
# args: $prop, $val
# returns: 0 on success
# (http_err_code, http_err_msg) on error
sub set_channel_property {
   my ($prop, $val) = @_;

   my $resp = http_put_authenticated("$KRAKEN_API_BASE/channels/$USERNAME", '{ "channel": { "'.$prop.'": "'.$val.'" } }');
   print $resp->code;
   print $resp->message;
   if ($resp->is_success) {
      return ();
   } else {
      return ($resp->code, $resp->message);
   }
}

# return property of channel property $prop
#
# args: $prop
sub get_channel_property {
   my ($prop) = @_;

   return get_channel_object()->{$prop};
}

# sets title of stream
#
# args: $title
sub set_title {
   my ($title) = @_;

   return set_channel_property("title", $title);
}

# sets current game to $game 
#
# args: $game
# returns: 0 - on success
#          (code, msg) - on error, where code and msg are HTTP error code and msg resp.
sub set_game {
   my ($game) = @_;

   return set_channel_property("game", $game);
}
