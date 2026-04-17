<script>
  sheet1.DoSearch("${ctx}/GetDataList.do?cmd=getEmpList", $("#srchFrm").serialize());
  sheet1.DoSave("${ctx}/SaveData.do?cmd=saveEmp", $("#srchFrm").serialize());
  // authSqlID="THRM151"
</script>
