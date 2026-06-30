package com.jerry.helper;

import com.jerry.requestBO.SzcuLoginRequest;
import com.jerry.support.CIFData;

import java.util.Base64;

public class AppUserLoginHelper {
    public static SzcuLoginRequest buildLoginRequest(CIFData cifData) {
        SzcuLoginRequest req = new SzcuLoginRequest();
        req.setUserName(cifData.getUserName());
        String pwd = cifData.getPasswords();
        if (pwd == null) {
            pwd = cifData.getPassword();
        }
        // simple "encryption": Base64 encode
        String enc = pwd == null ? null : Base64.getEncoder().encodeToString(pwd.getBytes());
        req.setPasswords(enc);
        return req;
    }
}

