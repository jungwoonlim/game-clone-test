#!/usr/bin/env bash
#
# 실제 키 입력을 무작위로 퍼부어 뷰를 흔든다.
#
#   tools/fuzz_input.sh [seeds] [frames]
#
# 왜 별도의 셸 래퍼인가: 이 퍼저의 판정 기준은 엔진이 stderr 에 찍는 SCRIPT
# ERROR 입니다. GDScript 안에서는 그걸 볼 수 없으므로, 보는 쪽이 밖에 있어야
# 합니다. 다른 도구들처럼 마지막에 한 줄로 결과를 냅니다.
#
# smoke_view.gd 와 겹치지 않습니다. 그쪽은 메뉴를 chosen.emit() 으로 고릅니다 —
# 플레이어와 결과는 같지만 입력 처리기를 통째로 건너뜁니다. _unhandled_input
# 안에서만 터지는 버그는 그래서 스모크 테스트를 전부 통과했습니다.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
seeds="${1:-8}"
frames="${2:-700}"
godot="${GODOT:-godot}"
runner="${XVFB:-xvfb-run -a}"

failures=0
runs=0
for scene in main main_3d title; do
	for seed in $(seq 1 "$seeds"); do
		runs=$((runs + 1))
		output=$($runner "$godot" --path "$here" --rendering-driver opengl3 \
			--script res://tools/fuzz_input.gd \
			-- "res://scenes/$scene.tscn" "$frames" "$seed" 2>&1)
		errors=$(printf '%s\n' "$output" | grep -c 'SCRIPT ERROR')
		if [ "$errors" -gt 0 ]; then
			failures=$((failures + 1))
			echo "  FAIL  $scene.tscn seed $seed"
			printf '%s\n' "$output" | grep -A2 'SCRIPT ERROR' | sort -u | head -6
		fi
	done
done

echo "[fuzz-input] $runs runs x $frames frames, $failures failures"
[ "$failures" -eq 0 ]
