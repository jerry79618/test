package com.jerry.support;

public class CBKHeader {
    private CBKServiceCode serviceCode;

    public CBKHeader() {}

    public CBKHeader(CBKServiceCode serviceCode) {
        this.serviceCode = serviceCode;
    }

    public CBKServiceCode getServiceCode() {
        return serviceCode;
    }

    public void setServiceCode(CBKServiceCode serviceCode) {
        this.serviceCode = serviceCode;
    }

    public static CBKHeader defaultHeader(CBKServiceCode code) {
        return new CBKHeader(code);
    }
}

