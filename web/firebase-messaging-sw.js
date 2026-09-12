importScripts('https://www.gstatic.com/firebasejs/9.22.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.22.0/firebase-messaging-compat.js');

// قم بوضع إعدادات Firebase الخاصة بمشروعك هنا
firebase.initializeApp({
  apiKey: "AIzaSyBNgovQzj6d0TOj605cX21OaZ60y8_IDZU",
  authDomain: "mystore-d2838.firebaseapp.com",
  projectId: "mystore-d2838",
  storageBucket: "mystore-d2838.firebasestorage.app",
  messagingSenderId: "550067676415",
  appId: "1:550067676415:web:0ae5263ae497fe354d18ca"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/icons/Icon-192.png'
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});