# App::HokkaidoOkuyami

App::HokkaidoOkuyami は、
指定年月日の北海道のお悔やみ情報をサイト[「北海道お悔やみ情報」](https://www.hokkaidookuyami.com)から
取得するモジュールです。

lib/App/HokkaidoOkuyami.pm はオブジェクト指向モジュールの書き方となっていますが、
通常はスクリプト script/hokkaido-okuyami を通して使うことを想定しています。

現状は App::HokkaidoOkuyami クラスのインターフェースを公開していません。
つまり、バージョンによって大規模な改変を予定しています。

# script/hokkaido-okuyami について

script/hokkaido-okuyami は以下のように使用します。

```
$ script/hokkaido-okuyami --date=20190131
```

出力は、指定日時のタブ区切りテキストです。

今後、機能追加で指定オプションを自由にしたり、
出力フォーマットが変更されたり可変にしたりするかもしれません。

# LICENSE

Copyright (C) OGATA Tetsuji.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

OGATA Tetsuji <tetsuji.ogata@gmail.com>
