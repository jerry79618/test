package com.jerry.support;

public class CBKResponse {
    private String messageId;
    private Object body;

    public CBKResponse() {}

    public CBKResponse(String messageId) {
        this.messageId = messageId;
    }

    public CBKResponse(String messageId, Object body) {
        this.messageId = messageId;
        this.body = body;
    }

    public String getMessageId() {
        return messageId;
    }

    public void setMessageId(String messageId) {
        this.messageId = messageId;
    }

    public Object getBody() {
        return body;
    }

    public void setBody(Object body) {
        this.body = body;
    }
}

