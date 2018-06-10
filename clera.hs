use strict;

# проверяем наличие всех необходимых утилит
{
   my @depends = qw/wget rtmpdump/;
   my $not_found;
   for(@depends) {
     print "ERROR: $_ not found" and ++$not_found
       if(system("which $_ > /dev/null"));
   }
   exit 1 if($not_found);
}

my $url = shift;
my $outfile = shift;

die "Usage: $0 <url> <outfile>\n"
  unless $url and $outfile;

if($url !~ m#^(?:http://)?rutube\.ru/.*?[\?&]{1}v=([a-f\d]{32})#i) {
  die
    "Invalid url, something like\n".
    "  http://rutube.ru/tracks/1234567.html?v=01234abcd\n".
    "was expected.\n";
}

$url = "http://bl.rutube.ru/$1.xml";

print "Downloading $url...\n";
my $data = `wget -q $url -O -`;
die "Error: wget returns $?\n" if($?);

if($data !~ m#<!\[CDATA\[((?:rtmp|http)://[^\]]+)\]\]>#is) {
  die "Failed to parse $url\n";
}

$url = $1;
print "Video url: $url\n";

# предположительно, вариант с использованием http устарел
# TODO - проверить на 10 000 случайных роликах
if($url !~ m#^(rtmp://[^'/]+/)([^']*?/)(mp4:[^']*)$#i) {
  die "Failed to parse video url\n";
}

my ($rtmp, $app, $playpath) = ($1, $2, $3);
print "rtmp = $rtmp\napp = $app\nplaypath = $playpath\n";
$outfile =~ s/'/\'/g;

my $cmd= "rtmpdump --rtmp '$rtmp' --app '$app' --playpath '$playpath'";
$cmd.= " --swfUrl 'http://rutube.ru/player.swf' --flv '$outfile'";
$cmd.= " --live" if($app eq "vod/");

system($cmd);
