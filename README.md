# PATCH//WORLD

《PATCH//WORLD: 인간이 마지막으로 정한 규칙》은 피해·시간·충돌 규칙의 오류를 역이용하고, 패치의 부작용으로 `THE OPTIMIZER`를 무너뜨리는 5~8분 분량의 탑다운 액션 퍼즐입니다.

## 현재 구성

- Flutter 3.44.8 stable · Dart 3.12.2 · Flame 1.38.0
- 960×540 고정 논리 해상도, 데스크톱 웹 우선
- 3개 룸 + 보스 룸, 일반 적 2종, 패치 카드 6개, 8개 조합
- 키보드·마우스·터치 입력
- 한국어/영어, 텍스트 배율, 볼륨, 화면 흔들림, 플래시 감소, Assist Mode
- Tiled 객체 레이어 기반 스폰·충돌·상호작용 좌표
- 타이틀, 설정, 크레딧, 패배, 엔딩 선택, 런 요약, 최고 점수

## 실행

```powershell
flutter pub get
flutter run -d chrome
```

## 전체 검증

```powershell
powershell -ExecutionPolicy Bypass -File tool/check.ps1
```

Linux/macOS에서는 `./tool/check.sh`를 사용합니다.

## 릴리스

```bash
./tool/release_web.sh 0.2.0-rc1
```

Firebase Hosting 설정은 `firebase.json`, GitHub Pages 배포는 `.github/workflows/pages.yml`에 있습니다. 실제 공개 배포에는 Firebase 프로젝트 ID와 Git remote가 필요합니다.

## 제출 자료

- [제출 소개·영상 구성](docs/submission/SUBMISSION.md)
- [Codex 협업 기록](docs/CODEX_COLLABORATION.md)
- [서드파티 고지](THIRD_PARTY_NOTICES.md)
- [에셋 권리 원장](assets/licenses/ASSET_LEDGER.md)

프로젝트 기준 문서: [PATCH//WORLD Project HQ](https://app.notion.com/p/3b2299e2188881ec8e45d6d7fa5ee356)
