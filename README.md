# PATCH//WORLD

《PATCH//WORLD: 인간이 마지막으로 정한 규칙》의 OpenAI Game Builders Seoul 대회용 웹 프로토타입입니다.

## 고정 환경

- Flutter 3.44.8 stable
- Dart 3.12.2
- Flame 1.38.0
- 논리 해상도 960×540, 16:9

## 실행

```powershell
flutter pub get
flutter run -d chrome
```

## 검증

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build web --release
```

## 현재 단계

P0 웹 부트스트랩 완료. 다음 단계는 입력 컨트롤러, 플레이어 이동, 벽 충돌, 기본 Patch Pulse 전투 기준선입니다.
