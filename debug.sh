#!/bin/sh

# debug.sh [-reconfig] [-configuration [Debug | Release]]
#   -reconfig 対話的にデバッグ対象を選択する。
#   -configuration Debug/Releaseの選択

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
declare OPTFLAG_RECONFIG 
declare CONFIGURATION 
while [ $# -ne 0 ] && [ "$1" != "" ] ; do
	case $1 in
	"-reconfig" )
		# 再設定を行う
		OPTFLAG_RECONFIG="true"
		;;
	"-configuration" )
		shift
		CONFIGURATION="$1"
		;;
	esac
	shift
done

# DEVICE_NAME が記憶されている場合はそれを読み込む
declare DEVICE_NAME
if [ -f ${HOME}/.config/.debug-target ] ; then
DEVICE_NAME="$(cat ${HOME}/.config/.debug-target)"
fi

# OPTFLAG_RECONFIGが設定された場合もしくは、DEVICE_NAMEが空の場合に対話的設定を行う
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

	select device_name in "${device_names[@]}" ; do
		DEVICE_NAME="$device_name"
		if [ ! -d "${HOME}/.config" ] ; then
		mkdir "${HOME}/.config"
		fi
		echo $DEVICE_NAME > "${HOME}/.config/.debug-target"
		break;
	done
fi

declare DESTINATION_ID=$(echo "$DEVICE_NAME" | egrep -oi -e '\([0-9A-F\\-]+\)$' | egrep -oi -e '[0-9A-F\\-]+')

xcodebuild \
	-project "QuadDump.xcodeproj" \
	-scheme "QuadDump" \
	-destination "generic/platform=iOS" \
	-configuration "${CONFIGURATION:-Debug}" \
	-archivePath "build/QuadDump.xcarchive" \
	archive \
	-quiet

if which ios-deploy ; then
	# 実機でのデバッグ実行
	ios-deploy --bundle ./build/QuadDump.xcarchive/Products/Applications/QuadDump.app --debug --id $DESTINATION_ID
else
	echo "ios-deployがインストールされていないので、実機でのデバッグ実行は行いません"
fi
