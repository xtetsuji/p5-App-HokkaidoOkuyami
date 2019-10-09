use strict;
use Test::More 0.98;
use App::HokkaidoOkuyami;

my $okuyami = new_ok "App::HokkaidoOkuyami";

subtest "user agent" => sub {
    my $ua = $okuyami->ua();
    isa_ok $ua, "HTTP::Tiny";
};

subtest "cache" => sub {
    my $filename = $okuyami->cache_filename("http://example.jp/");
    is $filename,
        $okuyami->{cache_dir} . "/" . "http%3a%2f%2fexample%2ejp%2f", "cache_filename convert http://example.jp/";
    
};

done_testing;

