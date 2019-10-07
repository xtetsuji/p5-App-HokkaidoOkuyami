package App::HokkaidoOkuyami;
use v5.22;
use strict;
use warnings;
use feature qw(signatures);
no warnings qw(experimental::signatures);
use Getopt::Long qw(:config posix_default no_ignore_case bundling auto_help);
use IO::File;
use HTTP::Tiny;
use Time::HiRes qw(time sleep);
use constant USER_AGENT => "Mozilla/5.0 (iPad; CPU OS 11_0 like Mac OS X) AppleWebKit/604.1.34 (KHTML, like Gecko) Version/11.0 Mobile/15A5341f Safari/604.1";
use constant SITE_URL => "https://www.hokkaidookuyami.com";
use constant ARCHIVE_URL => "https://www.xn--t8jvfoa6156axlf83n4jap08f0w5e.com"; # 北海道お悔やみ情報.com
use constant MONTH_SELECT_URL => ARCHIVE_URL . "/p/blog-page_697.html";
use constant DEBUG => $ENV{DEBUG};

use Data::Dumper;

our $VERSION = "0.01";

sub new($class) {
    my $self = {};
    bless $self, $class;
    $self->{cache} = 1;
    $self->{cache_dir} = "/tmp";
    return $self;
}

sub run($class, @args) {
    local @ARGV = @args;
    GetOptions(
        \my %opt,
        "date=s"
    );
    my $date = $opt{date}
        or die "specify --date paramter\n";
    my @date_parts = $date =~ /^(\d\d\d\d)(\d\d)(\d\d)$/
        or die "--date option format error\n";
    my ($year, $month, $day) = map { $_+0 } @date_parts;

    my $self = $class->new();
    my @persons = $self->okuyami_persons( $year, $month, $day);

    for my $person (@persons) {
        say join "\t", map { defined $_ ? $_ : "-" } @$person{
            qw/name age region address died_at funeral_info/
        }; # TODO: ここにおくやみ日を入れる？
    }
}

sub month_links($self) {
    my $response = $self->request( GET => MONTH_SELECT_URL );
    die if !$response->{success};
    my %url;
    for my $line (split /\n/, $response->{content}) {
        $line =~ m{
            <a \s+ href="
                (?<url>https://www\.xn--t8jvfoa6156axlf83n4jap08f0w5e\.com/.*)
            ">
            .*?
            (?<year>20\d\d)年(?<month>\d\d?)月
            .*?
            </a>
        }x or next;
        $url{ sprintf "%04d%02d", $+{year}, $+{month} } = $+{url};
        # print "$+{url} / $+{year} $+{month}\n";
    }
    return wantarray ? %url : \%url;
}

sub day_links($self, $year, $month) {
    my %day_link_url_of = $self->month_links();
    my $day_link_url = $day_link_url_of{ sprintf "%04d%02d", $year, $month };

    # $self->{cache} = 0;
    my $response = $self->request( GET => $day_link_url );
    # print $response->{content} =~ s/^/> /gmr;

    my %url;
    for my $line (split /\n/, $response->{content}) {
        $line =~ m{
            <a \s+ href="
                (?<url>
                    https://www\.xn--t8jvfoa6156axlf83n4jap08f0w5e\.com/.*?
                    |
                    https://www\.hokkaidookuyami\.com/.*?
                )
            ">
            .*?
            (?<day>\d\d?)日
            .*?
            </a>
        }x or next;
        $url{ sprintf "%02d", $+{day} } = $+{url};
    }
    return wantarray ? %url : \%url;
}

sub date_page_url($self, $year, $month, $day) {
    my %day_links = $self->day_links($year, $month);
    return $day_links{ sprintf "%02d", $day };
}

sub okuyami_persons($self, $year, $month, $day) {
    my $url = $self->date_page_url($year, $month, $day);
    if ( !$url ) {
        die "okuyami_persons: date_page_url is not found";
    }
    warn "date_page_url = $url" if DEBUG;
    my $response = $self->request( GET => $url );

    my $content = $response->{content};

    # 全体用
    $content =~ s{\A.*(?=<body)}{}is;
    $content =~ s{<script .*?>.*?</script\s*>}{}gs;
    # 本文と同じような「〜〜様」を伴った行が、script 要素中に JSON として表れて
    # 意図せず引っ掛けてしまうので予め除外しておく
    $content =~ s{<br\s*/?>}{}g;
    # div の内容の末尾に <br> が混入しているケースあり
    # そのまま除去で良い

    # www.北海道お悔やみ情報.com 用
    $content =~ s{</?span.*?>}{}gs;
    $content =~ s{\bstyle=".*?"}{}gs;

    # www.hokkaidookuyami.com 用
    $content =~ s{</?p\b.*?>}{}gs;

    # HTML上では長大な1行になっている用
    $content =~ s{(?=<div\b)}{\n}g;

    # 連結されるべきでない行の分割（葬儀終了で終わらない場合のみ）
    $content =~ s{(?<=葬儀終了)(?!\n)}{\n}g;

    my $current_region;
    my @persons;
    my $line_number = 0;
    for my $line (split /\n/, $content) {
        $line_number++;
        if ( $line =~ m{ (?:&\#9679;|●) (?<region>.*?) (?:&\#9679;|●) }x ) {
            $current_region = $+{region};
            next;
        }
        if ( $line !~ m{ (?:[ ]|&nbsp;) [ ]* 様 / }x ) {
            next;
        }

        chomp $line;
        $line =~ s{</div>.*$}{};
        $line =~ s{<div\b.*?>}{};

        my %row;
        my @row_data = split m{/}, $line;
        if ( @row_data == 5 ) { # 通常のケース
            @row{qw/name age address died_at funeral_info/} = @row_data;
        } elsif ( @row_data == 4 ) { # 死去日が欠けているケース
            @row{qw/name age address funeral_info/} = @row_data;
        } else { # 想定外のケース
            warn "okuyami_persons: unexpected line ($line_number)\n>>> $line\n";
            next;
        }

        # \s* だと名前の3バイト文字の最後の 0xA0 も削ってしまう
        $row{name} =~ s/(?:&nbsp;|[ ])*様//;
        s/&nbsp;/ /g, s/^ +//, s/ +$// for values %row;
        for (values %row) {
            warn "undefined $line\n" if !defined;
        }
        $row{region} = $current_region;

        push @persons, \%row;
    }
    return wantarray ? @persons : \@persons;
}

sub request($self, $method, $url, @args) {
    if ( $method eq 'GET' && $self->is_cache_exist($url) ) {
        if ( DEBUG ) {
            warn "use cache";
            sleep 1;
        }
        return $self->read_cache($url);
    }
    $self->wait_between_request();
    my $response = $self->ua->request($method, $url, @args);
    if ( $method eq 'GET' && $response->{success} && $self->{cache} ) {
        if ( DEBUG ) {
            warn "write_cache to " . $self->cache_filename($url);
            sleep 1;
        }
        $self->write_cache($url, $response->{content});
    }
    return $response;
}

sub wait_between_request($self) {
    my $prev = $self->{previous_request_time};
    my $now  = time;
    if ( $prev && $now - $prev < 2 ) {
        sleep $now - $prev;
    }
    $self->{previous_request_time} = time;
}

sub read_cache($self, $url) {
    my $cache_filename = $self->cache_filename($url);
    if ( DEBUG ) {
        warn "cache_filename = $cache_filename\n";
        sleep 3;
    }
    if ( !-f $cache_filename ) {
        return;
    }
    my $fh = IO::File->new($cache_filename, "r");
    warn "make fake response" if DEBUG;
    return +{
        content => join( "", $fh->getlines() ),
        success => 1,
        cache   => 1,
    };
}

sub write_cache($self, $url, $content) {
    my $cache_filename = $self->cache_filename($url);
    # TODO: 上書き判定
    my $fh = IO::File->new($cache_filename, "w");
    $fh->print($content);
}

sub is_cache_exist($self, $url) {
    return -f $self->cache_filename($url);
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

If you use App::HokkaidoOkuyami, then call run method at frontend script.

App::HokkaidoOkuyami is not opened its interfaces.
In short, big change is planned.

=head1 METHODS

Following methods are partial.

=head2 new

Constructor, almost internal.

It is expected that this is called in run method.

=head2 run

Front end script method.

  App::HokkaidoOkuyami->run(@ARGV);

It is not return any values.

=head1 LICENSE

Copyright (C) OGATA Tetsuji.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

OGATA Tetsuji E<lt>tetsuji.ogata@gmail.comE<gt>

=cut

