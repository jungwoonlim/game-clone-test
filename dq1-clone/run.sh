#!/usr/bin/env bash
#
# 게임을 실행합니다. 필요하면 임포트를 먼저 합니다.
#
#   ./run.sh                     2D (설정에서 고른 렌더러)
#   ./run.sh res://scenes/main_3d.tscn
#   GODOT=/path/to/godot ./run.sh
#
# 왜 이 스크립트가 있는가:
#
# Godot을 `--path` 로만 실행하면 그건 "게임 실행" 모드입니다. 이 모드는
# class_name 을 스캔하지 않고 .godot/global_script_class_cache.cfg 를 읽기만
# 합니다. 그 파일은 에디터나 --import 가 만들고, .godot/ 은 저장소에 들어가지
# 않습니다. 그래서 갓 clone 한 저장소나 새 스크립트를 받아 온 저장소를 바로
# 실행하면 "Identifier ... not declared" 가 쏟아집니다. 게임이 고장 난 게 아니라
# 아직 스캔되지 않은 것입니다.
#
# 이 스크립트는 그 스캔이 필요한지 직접 판단해서, 필요할 때만 돌립니다.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cache="$here/.godot/global_script_class_cache.cfg"

godot="${GODOT:-}"
if [ -z "$godot" ]; then
	for candidate in godot godot4 /Applications/Godot.app/Contents/MacOS/Godot; do
		if command -v "$candidate" >/dev/null 2>&1 || [ -x "$candidate" ]; then
			godot="$candidate"
			break
		fi
	done
fi
if [ -z "$godot" ]; then
	echo "Godot을 찾지 못했습니다. GODOT=<Godot 실행 파일 경로> ./run.sh 로 알려주세요." >&2
	echo "  macOS 기본 설치: GODOT=/Applications/Godot.app/Contents/MacOS/Godot" >&2
	exit 1
fi

# 캐시가 없거나, 캐시보다 새로운 파일이 하나라도 있으면 다시 스캔합니다.
# git pull 은 받아 온 파일의 시각을 지금으로 바꾸므로 이 조건에 걸립니다 —
# 새 스크립트나 새 에셋이 들어온 뒤 그냥 실행해서 깨지는 경우가 바로 그것입니다.
needs_import=0
if [ ! -f "$cache" ]; then
	needs_import=1
elif [ -n "$(find "$here" -path "$here/.godot" -prune -o -newer "$cache" -type f -print -quit)" ]; then
	needs_import=1
fi

if [ "$needs_import" -eq 1 ]; then
	echo "[run] 프로젝트를 임포트합니다 (처음이거나 파일이 바뀌었을 때만)..."
	"$godot" --headless --path "$here" --import
	# 임포트는 캐시를 쓴 뒤에도 .import 파일 몇 개를 더 건드립니다. 그대로 두면
	# 그것들이 캐시보다 새로워서 다음 실행이 또 임포트를 합니다. 끝난 시점으로
	# 도장을 찍어 둡니다.
	if [ -f "$cache" ]; then
		touch "$cache"
	fi
fi

exec "$godot" --path "$here" "$@"
