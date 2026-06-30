package com.jerry.stepDefinitions;

import com.jerry.support.CIFData;
import com.jerry.support.CBKResponse;

import java.util.HashMap;
import java.util.Map;

public class Context {
    private final Map<String, CIFData> data = new HashMap<>();
    private CBKResponse response;

    public void put(String name, CIFData cifData) {
        data.put(name, cifData);
    }

    public CIFData get(String name) {
        return data.get(name);
    }

    public void setResponse(CBKResponse response) {
        this.response = response;
    }

    public CBKResponse getResponse() {
        return response;
    }
}
