package com.jerry.support;

import com.jerry.stepDefinitions.Context;
import com.jerry.requestBO.SzcuLoginRequest;

import java.util.Base64;

public class ClientHelper {
    private final Context ctx;

    public ClientHelper(Context ctx) {
        this.ctx = ctx;
    }

    public CBKResponse post(String endpoint, CBKHeader header, Object body) {
        // simulate request handling for SZCUA01L001
        if (header != null && header.getServiceCode() == CBKServiceCode.SZCUA01L001 && body instanceof SzcuLoginRequest) {
            SzcuLoginRequest req = (SzcuLoginRequest) body;
            String encoded = req.getPasswords();
            String decoded = null;
            if (encoded != null) {
                try {
                    decoded = new String(Base64.getDecoder().decode(encoded));
                } catch (IllegalArgumentException e) {
                    decoded = null;
                }
            }
            if (decoded != null && decoded.length() > 6) {
                return new CBKResponse("SZC0000");
            } else {
                return new CBKResponse("SZC1001");
            }
        }
        return new CBKResponse("SZC9999");
    }
}

