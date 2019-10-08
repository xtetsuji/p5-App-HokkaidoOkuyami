use strict;
use Test::More 0.98;
use App::HokkaidoOkuyami;

my $okuyami = App::HokkaidoOkuyami->new();

$okuyami->{cache_dir} = "/tmp/02_cache_t";
mkdir $okuyami->{cache_dir};

my $cache_filename = $okuyami->cache_filename("https://www.nifty.com");
is $cache_filename, "/tmp/02_cache_t/https%3a%2f%2fwww%2enifty%2ecom", "cache_filename https://www.nifty.com";

done_testing;

