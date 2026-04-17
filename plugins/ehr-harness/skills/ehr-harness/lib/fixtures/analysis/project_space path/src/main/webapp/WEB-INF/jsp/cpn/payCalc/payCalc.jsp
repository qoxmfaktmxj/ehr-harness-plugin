<script>
  $.ajax({ url: "PayCalc.do", data: { cmd: "getPayList" } });
  $.ajax({ url: "ExecPrc.do", data: { cmd: "prcPayCalc" } });
  // authSqlID="TCPN201"
</script>
