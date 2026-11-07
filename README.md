# 파크골프다이어리 (PARKGOLF DIARY)

버튼 · 말로 기록하는 파크골프 스코어 앱 — Flutter (Android · iOS)

Figma **PARKGOLF-DIARY › 정리 › 와이어프레임 (라이트)** (`node 2108:303`) 을 기준으로 만든 1단계(폰 핵심) 버전이에요.

## 원칙

- 회원가입 · 로그인 없음. **모든 데이터는 휴대폰에만 저장**돼요 (서버 없음).
- 하단 탭: **홈 · 기록 · MY**. 동반자는 이름만 저장해요.
- 백업은 파일 내보내기 · 가져오기 (`.zip`, 휴대폰 공유 시트).
- 삭제한 라운드는 30일 동안 휴지통에 보관해요.
- 공유는 스코어카드 이미지만.

## 규정 ((사)한국프로파크골프협회 규정집)

- 18홀 Par 72 · **3-3-3 방식** (9홀마다 Par 3 · 4 · 5 가 3개씩, 9홀 Par 36) — 홀별 파 입력 화면에서 개수 체크
- 벌타 2타 (OB · 분실구 · 언플레이어블)
- 헛스윙은 타수에 넣지 않음 (제26조)
- 내 기록: **그린까지(벌타 포함) + 퍼트 → 총 타수 자동 계산**. 동반자: 총 타수만.

## 음성 입력 (휴대폰 마이크)

기기 내장 음성 인식(ko-KR, `speech_to_text`)으로 듣고 → 해석 → **확인 후 탭해서 적용** → 5초 동안 되돌리기.
자동으로 반영하지 않아요. 애매하면 되물어요.

| 말 | 결과 |
| --- | --- |
| 그린까지 3, 퍼트 2 | 그린까지 3 · 퍼트 2 → 5타 |
| 5타, 퍼트 2 | 그린까지 = 5 − 2 |
| 다섯 타 | 퍼트를 되물어요 |
| 벌타 / OB / 오비 | 그린까지 +2 (벌타 2) |
| 어피치 4 | 동반자 총 타수 |
| 다음 홀 · 이전 홀 · 취소 | 홀 이동 · 마지막 음성 입력 되돌리기 |

해석 규칙: `lib/logic/voice_parser.dart`, 테스트: `test/logic_test.dart`

## 화면 (와이어프레임 번호)

| 영역 | 화면 |
| --- | --- |
| 시작 | S-01 스플래시 · S-02 접근 권한 · S-06 닉네임 |
| 홈 | S-10 홈 (진행 중 라운드 이어서 입력) |
| 라운드 시작 | S-13 라운드 시작 · S-14 파크골프장 검색 · S-14-1 홀별 파 (3-3-3) · S-14-2 직접 추가 · S-15 동반자 · S-15-1 동반자 추가 시트 |
| 스코어 입력 | S-23 한 홀씩 / 표 · SV-02 듣는 중 · SV-08 결과 확인(탭) · SV-04 되묻기 · SV-05 반영 · 되돌리기 · SV-06 못 알아들음 |
| 기록 | S-31 라운드 완료 · S-31-1 스코어카드 이미지 공유 · S-30 기록(통계 + 파크골프장별) · S-32 파크골프장 상세 · S-33 라운드 상세 · S-35 다이어리 |
| MY | S-60 MY · S-60-1 삭제된 라운드 복구 · S-60-2 타수 표시 · 화면 모드(라이트 / 다크) · S-61 백업 · 복원 · S-61-1 복원 확인 · S-61-2 모든 데이터 삭제(2단계) |

## 이어폰 연동 (Android, Figma EP-03 ~ EP-10)

`android/.../EarphonePlugin.kt` (네이티브) + `lib/services/earphone.dart` + `lib/logic/earbuds.dart`(해석, 테스트 있음)

- 연결 상태 · 이름 · 마이크 여부 · 전체 배터리(HFP)
- 에어팟: BLE 광고로 왼쪽 · 오른쪽 · 케이스 배터리 · 충전 · 착용, AACP(휴대폰이 허용할 때만)로 1% 배터리 · 청취 모드 변경 · 기기 정보 · 이름 변경
- 주변 이어폰 검색 · 페어링(EP-03 · EP-04), 이어폰 상태(EP-05), 이어폰 정보 · 이름 변경(EP-07 · EP-08)
- 라운드 중: 상단 배지(🎧 L 80 · R 75), 귀에서 빼면 음성 입력 멈춤(EP-09), 배터리 20% 이하 알림(EP-10)
- 이어폰 마이크(SCO)로 말하기 — 끄면 휴대폰 마이크
- MY › 이어폰에서 열어요. 숨김 API는 우회 없이 일반 반사로만 시도해요(플레이 스토어 배포 가능).

다음 단계(이번 범위 밖): 이어폰 자이로 고개 제스처 · 워치 앱 · 샷 루틴 · 입력 설정(SS-01~04) · 워치/이어폰 연동(S-12, EP-01/02).

## 컴포넌트 (2027 Friends Screen Library)

`lib/widgets/library.dart` — 라이브러리 컴포넌트를 앱 위젯으로 옮겼어요 (모양 · 치수는 라이브러리, 색은 Theme 토큰).
popupDefault → `PopupCard` · toast → SnackBar 테마 · tabCombination → `UnderlineTabs` · sort → `SortChip` ·
labelSort / labelContents → `LabelSort` / `LabelContents` · courseInfo → `CourseInfo` · common/note → `NoteText` ·
report/screenList → `RoundListItem` · report/scorecard → `PersonalScorecard` · badge → `Badge2` / `Tag` · bottomsheet/header → `SheetHeader`

## 색 (Figma Theme 변수)

`lib/theme/app_theme.dart` — 2027 Friends Screen Library 색. brand/primary `#22BB5F`(primary-green/600), 회색은 gray/50~900, 에러 `#FA5E4C`. 라이브러리에 다크 값이 없어 다크는 같은 회색 단계로 만들었어요.
글꼴은 Pretendard (SIL OFL, `assets/fonts/`).

## 파크골프장 목록

`assets/data/parks.json` 에는 지금 **예시 4곳**만 들어 있어요 (`"sample": true`).
공공데이터포털에서 기관별 「파크골프장 표준데이터」 CSV를 내려받아 아래처럼 바꿔 넣으세요.

```bash
python3 tool/build_parks.py 내려받은/*.csv > assets/data/parks.json
```

목록에 없는 곳은 앱에서 직접 추가할 수 있어요. 홀별 파는 처음 한 번 구장 안내판을 보며 탭으로 입력하면 저장돼요.

## 실행 · 빌드

```bash
flutter pub get
flutter test              # 규정 · 음성 해석 · 저장 · 백업 · 화면 테스트
flutter run               # 기기 / 에뮬레이터
flutter build apk         # Android
flutter build ipa         # iOS (Xcode · 서명 필요)
```

예시 데이터로 화면 확인: `flutter run -d chrome -t tool/preview_main.dart` 후 주소에 `?screen=records&theme=dark` 처럼 붙여요.

## 구조

```
lib/
  main.dart                 앱 시작 · 테마 모드
  theme/app_theme.dart      Theme 토큰 (Light / Dark)
  models/models.dart        파크골프장 · 코스 · 라운드 · 설정
  logic/rules.dart          규정집 상수 · 3-3-3 · 파 대비 이름
  logic/stats.dart          통계 · 월별 · 파크골프장별
  logic/voice_parser.dart   음성 해석
  data/storage.dart         휴대폰 파일 저장 (원자적 쓰기)
  data/app_store.dart       상태 · 저장 · 휴지통
  data/backup.dart          백업 zip 만들기 · 읽기
  data/park_catalog.dart    내장 파크골프장 목록 · 검색
  services/speech.dart      휴대폰 마이크 음성 인식
  screens/…                 화면
  widgets/common.dart       공통 요소 (버튼 · 카드 · 칩 · 행 · 시트)
```
