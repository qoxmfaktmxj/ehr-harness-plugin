# table_entry

## 입력
`/impact TCPN771`

## fixture 구성
매퍼에서 TCPN771 을 UPDATE 하는 쿼리 + 해당 쿼리를 호출하는 Service 가 P_CPN_SEP_PAY_MAIN 연쇄 호출

## 기대 출력 핵심 포인트

### 6. 판정
`⚠ HOLD`
근거: 체인에 치명 프로시저 PKG_CPN_SEP 매칭
