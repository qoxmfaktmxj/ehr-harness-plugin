# mapper_dynamic

## 입력
`/impact dynamic-sql-query.xml`

## fixture 구성
- `dynamic-sql-query.xml` 에 `EXECUTE IMMEDIATE` 1건 포함

## 기대 출력 핵심 포인트

### 5. Unresolved Refs (CHECK 대상)
- EXECUTE IMMEDIATE: dynamic-sql-query.xml:23

### 6. 판정
`✅ Go · CHECK`
근거: 일반 매퍼 + Unresolved refs 1건
