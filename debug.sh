#!/bin/sh

# オプションは基本的に、xcodebuild にそのまま渡される
# 例外
# -reconfig 対話的にデバッグ対象を選択する。

# 失敗メモ
# ssh越しに実行するとアプリの署名に失敗する。
# これはssh越しでは秘密鍵にアクセスできないためらしい。
# この問題は以下のコマンドを実行してアクセス権限を得ることで、一時的に解決できる。
#
#   security unlock-keychain login.keychain
#
# 参考URL : https://stackoverflow.com/questions/24023639/xcode-command-usr-bin-codesign-failed-with-exit-code-1-errsecinternalcomponen/51679663

# コマンドが失敗した場合には、直ちに処理を終了する
set -eu

# パスの設定
PATH=/bin:/usr/bin:/usr/local/bin
export PATH

# コマンドの存在チェック
# 存在チェックは、which を使いその出力は不要なので、/dev/null に捨てます
# コマンドが見つからない場合にはwhich は 非0を返し if はその返り値を見ます
if ! which xcodebuild >/dev/null ; then
    echo "xcodebuild がありません"
    exit 1 # xcodebuild が入って居ない場合には、即座に終了します。
fi

# オプションの処理
# 基本的に引数は、xcodebuild にそのまま渡される
# xcodebuild はロングオプションを採用していて、macOS の場合getopt/getoptsはロングオプションを処理できないので、自前で処理を行うことにした。

# 対話的設定を行うフラグ
declare OPTFLAG_RECONFIG 
# XCodeのプロジェクト
declare PROJECT 
# configuration 通常は debug
declare CONFIGURATION 
# デバッグを行う先のデバイス or シミュレータの設定
declare DESTINATION 

declare buildarg=()

while [ $# -ne 0 ] && [ "$1" != "" ] ; do
    case $1 in
	"-reconfig" )
	    # 再設定を行う
	    OPTFLAG_RECONFIG="true"
	    ;;
	"-project")
	    shift
	    PROJECT="$1"
	    ;;
	"-configuration" )
	    shift
	    CONFIGURATION="$1"
	    ;;
	"-destination" )
	    shift
	    DESTINATION="$1"
	    ;;
	"-alltarget" )
	    buildarg+=('-alltarget')
	    ;;
	"-target" )
	    shift
	    buildarg+=("-target" "$1")
	    ;;
	"-sdk" )
	    shift
	    buildarg+=("-sdk" "$1")
	    ;;
	*)
	    buildarg+=("$1")
	    ;;
    esac
    shift
done

declare DEVICE_NAME

# 明示的に DESTINATION が設定された場合はそれを使用し、
# DESTINATION が指定されていない場合には、設定から取得する

if [ -z "$DESTINATION" ] ; then
    if [ -f ${HOME}/.config/.debug-target ] ; then
	DEVICE_NAME="$(cat ${HOME}/.config/.debug-target)"
    fi

    # OPTFLAG_RECONFIGが設定された場合もしくは、DESTINATIONが空の場合に対話的設定を行う
    if [ ! -z "$OPTFLAG_RECONFIG" -o -z "$DEVICE_NAME" ]; then
	declare tag=
	declare list_devices=$(xcrun xctrace list devices 2>&1)
	while read -r value ; do
	    if [ "$value" = "== Devices ==" ] ; then
		tag=device_names
	    elif [ "$value" = "== Simulators ==" ] ; then
		tag=simulators
	    elif [ ! -z "$tag" -a ! -z "$value" ] ; then
		eval $tag+='("''$'value'")'
	    fi
	done<<EOF
${list_devices}
EOF

	select device_name in "${device_names[@]}" "${simulators[@]}" ; do
	    DEVICE_NAME="$device_name"
	    if [ ! -d "${HOME}/.config" ] ; then
		mkdir "${HOME}/.config"
	    fi
	    echo $DEVICE_NAME > "${HOME}/.config/.debug-target"
	    break;
	done

    fi
    declare DESTINATION_ID=$(echo "$DEVICE_NAME" | egrep -oi -e '\([0-9A-F\\-]+\)$' | egrep -oi -e '[0-9A-F\\-]+')
    DESTINATION="platform=iOS,id=${DESTINATION_ID}"
fi

# 残りの引数を処理する部分の奇妙なイディオムに関しては
# https://stackoverflow.com/questions/7577052/bash-empty-array-expansion-with-set-u を確認のこと
xcodebuild -project "${PROJECT:-QuadDump.xcodeproj}" -destination "${DESTINATION}" -configuration "${CONFIGURATION:-Debug}"  ${buildarg[@]+"${buildarg[@]}"} &&
    if which ios-deploy ; then
	# 実機でのデバッグ実行
	DESTINATION_ID=$(echo "$DESTINATION" | sed "s/^platform=iOS,id=//")
	ios-deploy --bundle ./build/${CONFIGURATION:-Debug}-iphoneos/iOSplayground.app --debug --id $DESTINATION_ID
    else
	echo "ios-deployがインストールされていないので、実機でのデバッグ実行は行いません"
    fi
