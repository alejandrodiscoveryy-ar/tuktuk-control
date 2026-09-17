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

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const data = event.notification.data || {};
  if (data.kind !== 'marketplace_job_available' ||
      !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(data.job_id || '')) return;
  const target = new URL(self.registration.scope);
  target.searchParams.set('marketplace_job_id', data.job_id);
  event.waitUntil(clients.openWindow(target.toString()));
});
