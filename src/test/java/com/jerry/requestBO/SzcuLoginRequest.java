package com.jerry.requestBO;

import com.jerry.support.CBKRequestBody;

public class SzcuLoginRequest extends CBKRequestBody {
    private String userName;
    private String passwords;

    public String getUserName() {
        return userName;
    }

    public void setUserName(String userName) {
        this.userName = userName;
    }

    public String getPasswords() {
        return passwords;
    }

    public void setPasswords(String passwords) {
        this.passwords = passwords;
    }
}

