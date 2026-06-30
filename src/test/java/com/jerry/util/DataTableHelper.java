package com.jerry.util;

import io.cucumber.datatable.DataTable;
import com.jerry.stepDefinitions.Context;

import java.util.List;
import java.util.Map;

public class DataTableHelper {
    public static List<Map<String, String>> replaceParameter(DataTable dataTable, Context ctx) {
        // 簡化實作：直接回傳 asMaps
        return dataTable.asMaps();
    }
}

