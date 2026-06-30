package com.jerry.stepDefinitions;

import com.jerry.support.ClientHelper;
import com.jerry.support.CIFData;
import java.util.Map;

public class CucumberBase {
    private final Context ctx = new Context();
    protected final ClientHelper clientHelper = new ClientHelper(ctx);

    protected Context context() {
        return ctx;
    }

    protected void combineToCifData(String name, Map<String, String> map) {
        CIFData cif = new CIFData();
        if (map.containsKey("username")) {
            cif.setUserName(map.get("username"));
        }
        if (map.containsKey("password")) {
            cif.setPassword(map.get("password"));
        }
        context().put(name, cif);
    }
}
