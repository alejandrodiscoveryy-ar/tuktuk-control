importScripts('https://www.gstatic.com/firebasejs/12.17.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/12.17.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyAVDRuwMJZStQGCqHRGMuoNydCbG3JeUIo',
  authDomain: 'tuktuk-control-9e74c.firebaseapp.com',
  projectId: 'tuktuk-control-9e74c',
  storageBucket: 'tuktuk-control-9e74c.firebasestorage.app',
  messagingSenderId: '835856456604',
  appId: '1:835856456604:web:f9ce95c62e04f050fec659'
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const title = payload.notification?.title || payload.data?.title;
  const body = payload.notification?.body || payload.data?.body;

  if (!title && !body) return;

  self.registration.showNotification(title || 'TukTuk Control', {
    body: body || '',
    data: payload.data || {}
  });
});
