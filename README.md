# ⚾ KBO 선수 레이더 카드 (2026)

KBO 공식기록을 크롤링해 타자를 **FIFA 카드 스타일 레이더 + S~F 등급**으로 보여주는 웹.

## 구성
- `index.html` — 카드 웹페이지 (단일 파일)
- `data.js` — 선수 데이터 (KBO 크롤링 결과 + 사진 base64 임베드)
- `scrape.ps1` — KBO 기록 크롤러 (재실행 시 `data.js` 자동 갱신)

## 지표
- 레이더 6축: 타율(AVG) · 출루(OBP) · 장타(SLG) · 선구안(BB/K) · 주루(SB) · 생산력(wRC+)
- **OVR** = 타격 종합등급 (wRC+ 중심, 리그 백분위 100점 만점, 수비 미반영)
- wRC+ 는 리그 합계 베이스라인으로 자체 산출 (파크팩터 미적용 근사)

## 배포
정적 사이트라 Vercel / Netlify에 저장소 Import 만으로 배포됩니다.

## 데이터 갱신
```powershell
./scrape.ps1   # KBO 최신 기록으로 data.js 재생성
```
