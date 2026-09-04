'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"flutter_bootstrap.js": "512ea73798df2ba79a72bbd9d9e421db",
"icons/Icon-maskable-512.png": "8226c3ef7099083c8660782637217c47",
"icons/Icon-512.png": "567694095e42fa93392ab73d2c630037",
"icons/Icon-maskable-192.png": "883187820f7eae1baa785bebb7456bea",
"icons/Icon-192.png": "1a3fd827d9cffa061a1dd4b6d9878549",
"favicon.png": "12a17f6e072fa4d87c64712e302fe5a3",
"index.html": "51882779326869e46f4d0c275b37540f",
"/": "51882779326869e46f4d0c275b37540f",
"flutter.js": "f393d3c16b631f36852323de8e583132",
"manifest.json": "59998e864f642c80ccc54381ad0e86d7",
"assets/packages/lucide_icons/assets/lucide.ttf": "03f254a55085ec6fe9a7ae1861fda9fd",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "e986ebe42ef785b27164c36a9abc7818",
"assets/AssetManifest.bin.json": "d1fc1e8f52fd6a52dbb0cb5d5fda266e",
"assets/NOTICES": "271404d8c3189b7bbdb0966d93bcda33",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/fonts/MaterialIcons-Regular.otf": "b21f7f39e47a3873db6ce593b37dd1fb",
"assets/AssetManifest.json": "7bc5616526713e3599966ddb61e1bb1c",
"assets/assets/svgs/shamcash/logo_icon.png": "799116d67e97eaf6aae788f8cb8ba76f",
"assets/assets/svgs/shamcash/logo.png": "2f2f857bd4dd99e2a63153099b0a4342",
"assets/assets/svgs/shamcash/logo_dark.png": "5e137c4ea12cf52fad7efdf957c4ed4a",
"assets/assets/svgs/shamcash/dabirni.png": "41f6c64db710fb3737532483427e186a",
"assets/assets/svgs/shamcash/dabirni.svg": "c55826b96544c6804f502c7ee1b9c7f9",
"assets/assets/svgs/shamcash/logo_light.png": "78b50ee899d4f767d35c058dd8d9d60c",
"assets/assets/svgs/shamcash/logo_for_pdf.png": "ad5edd7f47c1e7df86ba69c154b9b5ce",
"assets/assets/fonts/1f173e5e25f3efee-s.woff2": "f143fb4877cf7ada1b84423ee86a0198",
"assets/assets/fonts/904be59b21bd51cb-s.p.woff2": "c154477b9affa3a0a47f894c8b80c03c",
"assets/assets/fonts/shamcash/ExpoArabic-Medium.ttf": "61d385606e1cc23125af16a442f375a0",
"assets/assets/fonts/shamcash/TradeIcons.ttf": "766922ac15e4b5d56a8eb0e02db3a78b",
"assets/assets/fonts/shamcash/CustomIcons.ttf": "fa1bc130eb9245d71131d1026921969a",
"assets/assets/fonts/shamcash/SessionsIcon.ttf": "583bfe498f8557de81244531b67352a6",
"assets/assets/fonts/shamcash/AccountFieldsIcons.ttf": "fc66b0985f30701678f20ad041bad8dc",
"assets/assets/fonts/shamcash/ExpoArabic-Book.ttf": "fe9a0ad452cd1c07da91ff905ba0d191",
"assets/assets/fonts/shamcash/ExpoArabic-Light.ttf": "7aae6e71e588f9a3af59c21c23105aba",
"assets/assets/fonts/shamcash/Montserrat-Medium.ttf": "9d496514aedf5c9bb3f689de8b094cd8",
"assets/assets/fonts/shamcash/Montserrat-Regular.ttf": "203d753a80557746c23ce95191fbf013",
"assets/assets/fonts/shamcash/Montserrat-Bold.ttf": "c300fff4e4ae0ca994c58ac9f6639b19",
"assets/assets/fonts/shamcash/Montserrat-SemiBold.ttf": "c1bd726715a688ead84c2dbf4c82f88d",
"assets/assets/fonts/shamcash/FaceId.ttf": "4470d74b7c4c7a8e825641b49d57cbf8",
"assets/assets/fonts/4ab97f0807701770-s.p.ttf": "833140a611c7025ab748efd787f753af",
"assets/assets/fonts/12cc825a4ea1cb9f-s.p.ttf": "fe9a0ad452cd1c07da91ff905ba0d191",
"assets/assets/fonts/37d836b25de4ac93-s.p.ttf": "895670f9160dd1c15d871a0c7e8f822e",
"assets/assets/fonts/a8d6a1bcd63b5612-s.p.ttf": "61d385606e1cc23125af16a442f375a0",
"assets/assets/images/dabirni.png": "9b05c127fcf3fda28823a1f27c80b29f",
"assets/FontManifest.json": "1ee00d31df7d0b30bfafc1cf4922abf8",
"assets/AssetManifest.bin": "ae4c9d612a47f1de5fd6e1ae06172518",
"version.json": "68b052052c1c646695d83c8df38fcaf2",
"canvaskit/canvaskit.wasm": "1f237a213d7370cf95f443d896176460",
"canvaskit/skwasm.wasm": "9f0c0c02b82a910d12ce0543ec130e60",
"canvaskit/skwasm.js.symbols": "262f4827a1317abb59d71d6c587a93e2",
"canvaskit/canvaskit.js": "66177750aff65a66cb07bb44b8c6422b",
"canvaskit/chromium/canvaskit.wasm": "b1ac05b29c127d86df4bcfbf50dd902a",
"canvaskit/chromium/canvaskit.js": "671c6b4f8fcc199dcc551c7bb125f239",
"canvaskit/chromium/canvaskit.js.symbols": "a012ed99ccba193cf96bb2643003f6fc",
"canvaskit/canvaskit.js.symbols": "48c83a2ce573d9692e8d970e288d75f7",
"canvaskit/skwasm.js": "694fda5704053957c2594de355805228",
"canvaskit/skwasm.worker.js": "89990e8c92bcb123999aa81f7e203b1c",
"main.dart.js": "12dcdf08fb7a56554f63894fdd14713a"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
