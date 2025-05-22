package com.example.hashtara.java;

import android.util.Log;
import com.google.firebase.messaging.FirebaseMessagingService;
import com.google.firebase.messaging.RemoteMessage;

public class MyFirebaseMessagingService extends FirebaseMessagingService {
    private static final String TAG = "MyFirebaseMsgService";

    @Override
    public void onMessageReceived(RemoteMessage remoteMessage) {
        // 메시지 수신 처리
        Log.d(TAG, "From: " + remoteMessage.getFrom());

        // 데이터 페이로드가 있는지 확인
        if (remoteMessage.getData().size() > 0) {
            Log.d(TAG, "Message data payload: " + remoteMessage.getData());
        }

        // 알림 페이로드가 있는지 확인
        if (remoteMessage.getNotification() != null) {
            Log.d(TAG, "Message Notification Body: " + remoteMessage.getNotification().getBody());
        }
    }

    @Override
    public void onNewToken(String token) {
        Log.d(TAG, "Refreshed token: " + token);
        
        // 새로운 토큰을 서버로 전송하는 로직을 여기에 추가할 수 있습니다
        sendRegistrationToServer(token);
    }

    private void sendRegistrationToServer(String token) {
        // 서버에 토큰을 전송하는 로직
        // 현재는 로그만 출력
        Log.d(TAG, "Token sent to server: " + token);
    }
}