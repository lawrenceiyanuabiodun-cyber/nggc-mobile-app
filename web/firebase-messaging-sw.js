// Firebase Messaging Service Worker
// Handles background notifications when the web app is not in focus

importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyALpgooEVOSXwsixboRKiMEvD7H2nncfoA",
  authDomain: "nggc-sunday-school.firebaseapp.com",
  projectId: "nggc-sunday-school",
  storageBucket: "nggc-sunday-school.firebasestorage.app",
  messagingSenderId: "584254133766",
  appId: "1:584254133766:web:52dd0f60444d10e3af1587"
});

const messaging = firebase.messaging();

// Handle background messages (when tab is closed or not focused)
messaging.onBackgroundMessage(function(payload) {
  console.log('[firebase-messaging-sw.js] Received background message:', payload);

  const notificationTitle = payload.notification?.title || 'NGGC';
  const notificationOptions = {
    body: payload.notification?.body || '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    tag: 'nggc-notification',
    requireInteraction: false,
    data: payload.data || {}
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});

// Handle notification click
self.addEventListener('notificationclick', function(event) {
  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function(clientList) {
      // If a tab is already open, focus it
      for (let i = 0; i < clientList.length; i++) {
        const client = clientList[i];
        if ('focus' in client) return client.focus();
      }
      // Otherwise, open a new tab
      if (clients.openWindow) return clients.openWindow('/');
    })
  );
});