// Service worker pour CHAP-CHAP PWA

const CACHE_NAME = 'chap-chap-cache-v1';
const OFFLINE_URL = 'offline.html';
const ASSETS_TO_CACHE = [
  './',
  './index.html',
  './main.dart.js',
  './assets/fonts/MaterialIcons-Regular.otf',
  './assets/AssetManifest.json',
  './assets/FontManifest.json',
  './icons/apple-touch-icon.png',
  './icons/Icon-192.png',
  './icons/Icon-512.png',
  './manifest.json',
  './favicon.png',
  OFFLINE_URL
];

// Installation du service worker
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      console.log('Service Worker: Mise en cache des ressources');
      return cache.addAll(ASSETS_TO_CACHE);
    })
  );
});

// Activation du service worker
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keyList) => {
      return Promise.all(
        keyList.map((key) => {
          if (key !== CACHE_NAME) {
            console.log('Service Worker: Suppression de l\'ancien cache', key);
            return caches.delete(key);
          }
        })
      );
    })
  );
  return self.clients.claim();
});

// Stratégie de cache et réseau
self.addEventListener('fetch', (event) => {
  // Pour les requêtes API
  if (event.request.url.includes('/api/')) {
    event.respondWith(networkFirstStrategy(event.request));
  } else {
    // Pour les ressources statiques
    event.respondWith(cacheFirstStrategy(event.request));
  }
});

// Stratégie "Cache d'abord, puis réseau"
async function cacheFirstStrategy(request) {
  const cachedResponse = await caches.match(request);
  if (cachedResponse) {
    return cachedResponse;
  }
  
  try {
    const networkResponse = await fetch(request);
    // Mettre en cache la nouvelle ressource
    if (networkResponse.ok) {
      const cache = await caches.open(CACHE_NAME);
      cache.put(request, networkResponse.clone());
    }
    return networkResponse;
  } catch (error) {
    // En cas d'échec et si c'est une requête de page
    if (request.mode === 'navigate') {
      const cache = await caches.open(CACHE_NAME);
      return cache.match(OFFLINE_URL);
    }
    return new Response('Contenu non disponible hors ligne', { 
      status: 503,
      statusText: 'Service Unavailable'
    });
  }
}

// Stratégie "Réseau d'abord, puis cache"
async function networkFirstStrategy(request) {
  try {
    const networkResponse = await fetch(request);
    // Mettre en cache la réponse API
    if (networkResponse.ok) {
      const cache = await caches.open(CACHE_NAME);
      cache.put(request, networkResponse.clone());
    }
    return networkResponse;
  } catch (error) {
    const cachedResponse = await caches.match(request);
    if (cachedResponse) {
      return cachedResponse;
    }
    return new Response(JSON.stringify({ 
      error: 'Réseau indisponible',
      offline: true,
      timestamp: new Date().toISOString()
    }), { 
      headers: { 'Content-Type': 'application/json' },
      status: 503
    });
  }
}
