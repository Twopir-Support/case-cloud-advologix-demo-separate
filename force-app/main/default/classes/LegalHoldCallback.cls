/**
 * Implement this interface and put the class name in Matter Management Settings > Legal Hold Callback Class
 * to be told when matters are placed on or released from legal hold.
 * Payload: {"recordsList":[{"recordId":"a0X...","status":"Added"|"Removed"}],"success":true,"result":""}
 */
public interface LegalHoldCallback {
    void handle(String payload);
}
