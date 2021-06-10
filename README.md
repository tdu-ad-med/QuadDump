# QuadDump
![demo](docs/demo.gif)  

これはiPhone 12 Pro上で動作する録画アプリです。
このアプリでは以下の4つのセンサーから得られる情報を同時に録画します。

- カメラからの映像
- LiDARからのデプス映像
- IMU (加速度、角加速度の値)
- GPS

また、録画したデータは「ファイル」アプリから閲覧できます。

# ビルドに必要なツール

- xcode
- [xcodegen](https://github.com/yonaskolb/XcodeGen)
- [ios-deploy](https://github.com/ios-control/ios-deploy)

# git cloneからデバッグ実行までの流れ

```sh
git clone https://github.com/wakewakame/QuadDump
cd QuadDump
xcodegen
./debug.sh
```

`xcodegen`でXcodeのプロジェクトファイル`QuadDump.xcodeproj`を生成します。

`./debug.sh`で実機でのデバッグ実行を行います。
どのデバイスで実行するかを問われるので、表示されるデバイスに対応する数字を入力します。

また、`./debug.sh`は前回実行したときの設定を記憶するため、2度目以降の実行では実行先のデバイスを問われません。
再設定を行う場合は`-reconfig`オプションを付けて実行してください。

# 実行に失敗する場合

## 原因1
`DEVELOPMENT_TEAM`と`PRODUCT_BUNDLE_IDENTIFIER`が正しく設定されていないとアプリの署名に失敗します。
`project.yml`を編集し、それぞれの変数に適切な値を設定してください。

`DEVELOPMENT_TEAM`に設定する値が分からない場合は`docs`ディレクトリ内の`get_DEVELOPMENT_TEAM.sh`を実行することで確認できます。

## 原因2
sshでログインしている場合などはアプリの署名に失敗することがあります。
これは署名に用いる証明書へのアクセス権限がないためです。
以下のコマンドを実行することで一時的にアクセス権限を獲得できます。

```sh
security unlock-keychain login.keychain
```

# 構成
| ファイル名 | 説明 |
| :--- | :--- |
| debug.sh | デバッグ実行用のスクリプト |
| project.yml | xcodegenの設定ファイル |
| QuadDump | QuadDumpのプログラムを格納しているディレクトリ |
| scripts | 録画したデータを操作するスクリプトを格納しているディレクトリ |
