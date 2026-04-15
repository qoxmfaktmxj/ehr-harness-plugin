package com.hr.legacy;

import java.util.HashMap;
import java.util.Map;

public class ValidUsage {
    public Map<String, Object> buildPrimary() {
        Map<String, Object> paramMap = new HashMap<>();
        paramMap.put("authSqlID", "TVLD101");
        return paramMap;
    }

    public Map<String, Object> buildSecondary() {
        Map<String, Object> paramMap = new HashMap<>();
        paramMap.put("authSqlID",  "TVLD202");
        return paramMap;
    }
}
