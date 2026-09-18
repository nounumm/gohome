#!/bin/bash
# gohome 빌드 + 배포 패키지 생성
#
# 애드혹 서명(CODE_SIGN_IDENTITY="-")으로 빌드한다.
# Apple 계정·인증서·프로비저닝 프로파일이 전혀 필요 없고 만료도 없다.
# 대신 받는 쪽에서 install.command 를 한 번 실행해 quarantine 을 떼야 한다.

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
# 빌드·패키징 디렉토리는 반드시 iCloud 동기화 밖에 둔다.
# ~/Desktop 이 iCloud 동기화 대상이라 그 안에서 빌드하면 iCloud 가 확장속성을
# 붙이고 codesign 이 "resource fork ... detritus not allowed" 로 실패한다.
WORK_DIR="$HOME/Library/Developer/gohome-build"
BUILD_DIR="$WORK_DIR/DerivedData"
DIST_DIR="$WORK_DIR/dist"
ZIP="$HOME/Desktop/gohome_배포.zip"

cd "$PROJECT_DIR"

echo "==> 이전 산출물 정리"
rm -rf "$WORK_DIR"
mkdir -p "$DIST_DIR/gohome"

echo "==> 빌드 (애드혹 서명, 프로파일 없음)"
# CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO 는 get-task-allow(디버거 attach 허용)를
# 배포본에서 빼기 위한 것. Xcode 에서 직접 Run 할 때는 영향 없음.
xcodebuild \
  -project gohome.xcodeproj \
  -scheme gohome \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGN_STYLE=Manual \
  PROVISIONING_PROFILE_SPECIFIER="" \
  DEVELOPMENT_TEAM="" \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
  ONLY_ACTIVE_ARCH=NO \
  ARCHS="arm64 x86_64" \
  build \
  > "$WORK_DIR/build.log" 2>&1 \
  || { echo "빌드 실패 — $WORK_DIR/build.log 확인"; tail -20 "$WORK_DIR/build.log"; exit 1; }

APP="$BUILD_DIR/Build/Products/Release/gohome.app"
[ -d "$APP" ] || { echo "빌드 산출물을 찾을 수 없음: $APP"; exit 1; }

echo "==> 검증"
if [ -e "$APP/Contents/embedded.provisionprofile" ]; then
  echo "  ! 프로비저닝 프로파일이 포함됨 — 설정 확인 필요"; exit 1
fi
codesign --verify --deep --strict "$APP" || { echo "  ! 서명 검증 실패"; exit 1; }
ARCHS_OUT=$(lipo -archs "$APP/Contents/MacOS/gohome")
case "$ARCHS_OUT" in
  *arm64*x86_64*|*x86_64*arm64*) : ;;
  *) echo "  ! universal 아님 ($ARCHS_OUT) — 인텔 맥에서 실행 불가"; exit 1 ;;
esac
echo "  프로파일 없음 / 서명 검증 통과 / universal ($ARCHS_OUT)"

echo "==> 패키징"
# ditto 로 복사해야 리소스 포크·확장속성이 안 붙는다 (cp -R 은 붙을 수 있음)
ditto "$APP" "$DIST_DIR/gohome/gohome.app"
xattr -cr "$DIST_DIR/gohome/gohome.app"

cat > "$DIST_DIR/gohome/install.command" <<'INSTALL'
#!/bin/bash
# gohome 설치 — 더블클릭해서 실행하세요.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/gohome.app"
DEST="/Applications/gohome.app"

echo "gohome 을 설치합니다."
[ -d "$SRC" ] || { echo "gohome.app 을 찾을 수 없습니다. 압축을 먼저 풀어주세요."; read -n1 -p "엔터를 누르면 종료"; exit 1; }

# 실행 중이면 종료
pkill -f "/Applications/gohome.app/Contents/MacOS/gohome" 2>/dev/null || true

rm -rf "$DEST"
ditto "$SRC" "$DEST"

# 다운로드 표식(quarantine) 제거 — 이게 없으면 Gatekeeper 가 차단합니다.
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true
xattr -cr "$DEST" 2>/dev/null || true

open "$DEST"
echo "설치 완료. 메뉴 막대에 아이콘이 나타납니다."
read -n1 -p "엔터를 누르면 종료"
INSTALL

chmod +x "$DIST_DIR/gohome/install.command"

cat > "$DIST_DIR/gohome/읽어주세요.txt" <<'README'
gohome 설치 방법
================

1. 이 폴더의 install.command 를 더블클릭합니다.
2. "확인되지 않은 개발자" 경고가 뜨면:
   시스템 설정 > 개인정보 보호 및 보안 으로 가서
   아래쪽 "무시하고 열기" 를 누른 뒤 다시 실행합니다.
3. 설치가 끝나면 메뉴 막대에 아이콘이 나타납니다.

이 앱은 Apple 유료 개발자 계정 없이 만들어져서
처음 실행할 때만 위 과정이 필요합니다. 이후에는 그냥 실행됩니다.
README

echo "==> 압축"
ditto -c -k --sequesterRsrc --keepParent "$DIST_DIR/gohome" "$ZIP"

echo
echo "완료: $ZIP"
echo "   크기: $(du -h "$ZIP" | cut -f1)"
echo "   전달 방법: zip 전달 → 압축 해제 → install.command 더블클릭"
