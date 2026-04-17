# url_direct

## 입력
`/impact /SepDcPayMgr.do`

## fixture 구성
SepDcPayMgrController.java (`@Autowired AuthTableService` 주입) + 매퍼에 `${query}` 사용

## 기대 출력 핵심 포인트

### 6. 판정
`⚙ Conditional-Go`
근거: SIGNAL_LAW_C=1 — AuthTableService 주입 + `${query}` 매퍼
