package App::HokkaidoOkuyami;
use v5.22;
use strict;
use warnings;
use feature qw(signatures);
no warnings qw(experimental::signatures);
use IO::File;
use HTTP::Tiny;
use constant USER_AGENT => "Mozilla/5.0 (iPad; CPU OS 11_0 like Mac OS X) AppleWebKit/604.1.34 (KHTML, like Gecko) Version/11.0 Mobile/15A5341f Safari/604.1";
use constant SITE_URL => "https://www.hokkaidookuyami.com";
use constant ARCHIVE_URL => "https://www.xn--t8jvfoa6156axlf83n4jap08f0w5e.com"; # 北海道お悔やみ情報.com
use constant DAY_SELECT_URL => ARCHIVE_URL . "/p/blog-page_697.html";

our $VERSION = "0.01";

sub new($class) {
    my $self = {};
    bless $self, $class;
    $self->{cache} = 1;
    $self->{cache_dir} = "/tmp";
    return $self;
}

sub run($class, @args) {
    my $self = $class->new(@args);
    $self->ua();
}

sub request($self, $method, $url, @args) {
    if ( $method eq 'GET' && $self->is_cache_exist($url) ) {
        return $self->read_cache($url);
    }
    my $response = $self->ua->request($method, $url, @args);
    if ( $method eq 'GET' && $response->{success} && $self->{cache} ) {
        $self->write_cache($response->{content});
    }
}

sub read_cache($self, $url) {
    my $cache_filename = $self->cache_filename($url);
    if ( !-f $cache_filename ) {
        return;
    }
    my $fh = IO::File->new($cache_filename, "r");
    return join "", $fh->getlines();
}

sub write_cache($self, $url, $content) {
    my $cache_filename = $self->cache_filename($url);
    if ( !-f $cache_filename ) {
        return;
    }
    my $fh = IO::File->new($cache_filename, "w");
    $fh->print($content);
}

sub is_cache_exist($self, $url) {
    return -f $self->cache_filename();
}

sub cache_filename($self, $url) {
    my $base_filename =
        $url =~ s/[^a-zA-Z0-9]/ "%" . unpack "H2", $& /egr;
    return $self->{cache_dir} . "/" . $base_filename;
}

sub ua($self) {
    $self->{ua} ||= HTTP::Tiny->new( agent => USER_AGENT );
    return $self->{ua};
}

sub get_url($type) {
}

1;
__END__

=encoding utf-8

=head1 NAME

App::HokkaidoOkuyami - Hokkaido Okuyami fetcher backend

=head1 SYNOPSIS

    use App::HokkaidoOkuyami;
    App::HokkaidoOkuyami->run();

=head1 DESCRIPTION

App::HokkaidoOkuyami is L<Hokkaido Okuyami|https://www.hokkaidookuyami.com> fetcher backend module.

If you use App::Hokkaido::Okuyami, then call run method at frontend script.

=head1 METHODS

=head2 run



=head1 LICENSE

Copyright (C) OGATA Tetsuji.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

OGATA Tetsuji E<lt>tetsuji.ogata@gmail.comE<gt>

=cut

