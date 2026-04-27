# Changelog

본 문서는 Keep a Changelog 형식을 따른다.
v1.10.0 부터 신규 릴리즈는 이 파일에 기록한다.
v1.9.x 이하 history 는 `README.md` 내 변경 이력 섹션 참조.

## [Unreleased]

## [1.10.0] — 2026-04-25

### Added
- self-evolving 메커니즘 (런타임 capture + 배치 harvest + audit 승인)
- HARNESS_SCHEMA v5 (`ehr_cycle.learnings_meta`)
- profile별 `ehr-lessons` skill (lazy-load, 검증 함수 명명 + 회신 템플릿)
- AGENTS.md.skel eager 지식 (분석 요청 프로토콜, EHR 운영 상수)
- correction harvester hook (UserPromptSubmit, redaction 강제)
- preferences inject hook (SessionStart, CLAUDE_ENV_FILE + additionalContext)
- `/ehr-harvest-learnings` slash command
- PII redaction 라이브러리 + `.claude/learnings/` gitignore 강제
- 경량 가드 8종 종합 테스트 (`harness-weight.test.sh`)
- 통합 테스트 runner (`lib/tests/run-all.sh`)

### Changed
- `HARNESS.json` schema v4 → v5 자동 마이그레이션 (strict-append, jq spread/node spread)
- 기존 hook path 를 `$CLAUDE_PROJECT_DIR` 기준으로 마이그레이션
- README 변경 이력 정책: v1.10 부터 신규 릴리즈는 본 CHANGELOG 로 분리

### Fixed
- `ehr_classify_signal` 길이 임계가 locale 의존이라 Windows Git-bash 에서 비결정적이던 문제. byte 단위 (`wc -c`) 로 고정.

### Security
- raw 원문 sha256 금지 → redacted normalized 기반 sha256
- staged file nonce 검증 (sha256 lowercase hex 64)
- scope 격리: project-local (기본) / plugin-dev (cwd 검증) / org-template (reserved)
