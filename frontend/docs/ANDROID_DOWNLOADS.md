# Android downloads and web hosting

Public downloads live in the separate [qabas-downloads repository](https://github.com/r-abdulwahed/qabas-downloads). Application source and recording instructions are not uploaded there.

The web banner always points to:

https://github.com/r-abdulwahed/qabas-downloads/releases/latest/download/qabas.apk

Keep the asset filename **qabas.apk** in every published latest release. Each release keeps its own APK and SHA256SUMS. Publishing another release updates the permanent URL without rebuilding or deploying the website. Android users still install the downloaded update manually; this does not add automatic in-app updates. Preserve the signing certificate and increment Android versionCode for future updates.

Publish an APK that has already been built and verified:

```sh
sh tool/publish_android_release.sh 1.0.1 /absolute/path/to/app-release.apk
```

The script is for the current preview distribution and labels it as sample content. Review its notes and signing configuration before publishing a live production build. Do not upload the private recording scripts.

Latest release **v1.0.1** (versionCode **2**) was built with `config/recording.json` on 2026-10-06 and includes the loading UI refinement. APK SHA-256: `928b2ba1529ca2070aec67ff18f730e3a399f33317a580bf84b871afb64d3ba2`; 98,709,814 bytes. Its signing certificate matches v1.0.0. Next update should increment both release version and Android versionCode (for example 1.0.2 / 3).

Initial release v1.0.0 uses the exact Qabas-Recording/Qabas-recording.apk delivered on 2026-10-06 (SHA-256 d07e9785ceb5cf348d180b0d232a50c33d732e7759f20894e85394e091403e9c). It is 98,644,010 bytes, package com.rw.qabas, Android API 24+, and uses the existing development signing certificate. Physical Android checks and live backend integration remain outstanding.

The web-only Journey banner uses the existing gold button and night emerald palette, supports English/Arabic, and is dismissible for the mounted Journey flow. Its six-platform copy describes platform targets, not six published installers; the public packages currently available are Android and Web.

Cloudflare Pages project **qabas-app** serves https://qabas-app.pages.dev/#/journey. The requested `qabas` project was assigned `qabas-d5k.pages.dev`, so the exact `qabas.pages.dev` address could not be assigned. No deployment was made to the unused `qabas` project. The old `qabas-demo` project is retained for existing links.

Deploy competition website changes with the populated preview configuration (visible reviewer access and bilingual sample content):

```sh
flutter build web --release --dart-define-from-file=config/competition.json
npx wrangler@4.147.0 pages deploy build/web --project-name=qabas-app --branch=main --commit-dirty=true
```

The banner link is defined in `lib/app/config/download_links.dart`; localized copy lives in the Journey ARB fragments. No endpoint or wire-contract assumptions were introduced.

Judges can open `https://qabas-app.pages.dev/#/reviewer/login` directly and choose **Explore reviewer dashboard**, or use the visible card in Profile. Reviewer sign-out returns to their saved learner progress. The downloadable APK is still v1.0.1 and does not contain the new public-entry UI.
