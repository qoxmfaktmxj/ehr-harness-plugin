# Changelog

본 문서는 Keep a Changelog 형식을 따른다.
v1.10.0 부터 신규 릴리즈는 이 파일에 기록한다.
v1.9.x 이하 history 는 `README.md` 내 변경 이력 섹션 참조.

## [Unreleased]

### Added
- (placeholder)

## [1.10.0] — TBD (Stage 9 에서 채움)

### Added
- self-evolving 메커니즘 (런타임 capture + 배치 harvest + audit 승인)
- HARNESS_SCHEMA v5 (learnings_meta 필드)
- profile별 `ehr-lessons` skill (lazy-load, 검증 함수 명명 + 회신 템플릿)
- AGENTS.md.skel eager 지식 (분석 요청 프로토콜, EHR 운영 상수)
- correction harvester hook (UserPromptSubmit)
- preferences inject hook (SessionStart, CLAUDE_ENV_FILE + additionalContext)
- `/ehr-harvest-learnings` slash command
- PII redaction 라이브러리 + .claude/learnings/ gitignore 강제
- 경량 가드 8종 종합 테스트 (`harness-weight.test.sh`)

### Changed
- HARNESS.json schema v4 → v5 (자동 마이그레이션, strict-append)
- 기존 hooks 의 path 를 `$CLAUDE_PROJECT_DIR` 기준으로 마이그레이션

### Security
- raw 원문 sha256 금지, redacted normalized 기반으로 전환
- staged file nonce 검증 (sha256, lowercase hex 64)
- scope 격리 (project-local 기본, plugin-dev 는 cwd 검증, org-template reserved)
