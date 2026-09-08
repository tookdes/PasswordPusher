# Personal quick-share mode

This fork adds a small personal secret-delivery flow on top of Password Pusher without replacing the upstream data model or account system.

## What is added

- `/` (when `PWP_PERSONAL_MODE=1`) and `/quick`: authenticated creator page for text-only temporary secrets.
- `/s/<code>`: very small recipient page designed to work without JavaScript, including old Safari/iOS browsers.
- Required PIN/passphrase for every quick secret.
- Optional custom short code (`/s/phone`, `/s/abc123`); blank values get a 6-character unambiguous random code.
- Wrong PIN attempts do **not** consume a view. Password attempts are rate limited per secret.
- Normal Password Pusher expiration/view limits and atomic burn-after-read behavior are reused.
- Secret recipient responses send `no-store`, `no-cache`, `no-referrer` and `noindex` headers.

The original Password Pusher UI and `/p/<token>` routes are still present.

## Linux x64 single-file build

GitHub Actions builds `password-pusher-linux-x64` using OCRAN. It bundles Ruby, Rails, gems and native libraries into one Linux x64 executable; Ruby does not need to be installed on the target machine. The executable self-extracts to a temporary directory when it starts.

The binary enables `PWP_PERSONAL_MODE=1` and defaults to a locked-down personal configuration:

- anonymous creation disabled;
- public signups disabled;
- file/URL/QR pushes disabled;
- Simplified Chinese locale;
- one successful view by default;
- retrieval-step and viewer-delete defaults disabled.

All normal Password Pusher `PWP__...` settings remain overridable through environment variables.

### First run

Create the first account directly from the binary (signups remain disabled):

```sh
chmod +x password-pusher-linux-x64
./password-pusher-linux-x64 --init-user you@example.com 'a-long-login-password'
```

Then start it:

```sh
./password-pusher-linux-x64
```

Default bind address is `0.0.0.0`, default port is `5100`.

Runtime data is stored in `password-pusher-data/` beside the executable by default. The directory contains the SQLite database plus generated `SECRET_KEY_BASE` and `PWPUSH_MASTER_KEY` files. Keep that directory private and back it up if existing encrypted pushes must survive a machine migration.

Useful overrides:

```sh
PORT=8080 ./password-pusher-linux-x64
PWP_BIND=127.0.0.1 ./password-pusher-linux-x64
PWP_DATA_DIR=/srv/password-pusher ./password-pusher-linux-x64
```

For reverse-proxy deployments, set the standard Password Pusher URL/proxy settings such as `PWP__OVERRIDE_BASE_URL`, `PWP__ALLOWED_HOSTS`, `PWP__SECURE_COOKIES` and `PWP__CLOUDFLARE_PROXY` as appropriate.

## Source/Docker deployments

The quick-share routes work in the normal Docker/source deployment too. Set `PWP_PERSONAL_MODE=1` to make the quick creator the root page, and configure at least:

```sh
PWP_PERSONAL_MODE=1
PWP__ALLOW_ANONYMOUS=false
PWP__DISABLE_SIGNUPS=true
PWP__ENABLE_FILE_PUSHES=false
PWP__ENABLE_URL_PUSHES=false
PWP__ENABLE_QR_PUSHES=false
PWP__DEFAULT_LOCALE=zh-CN
PWP__PW__EXPIRE_AFTER_VIEWS_DEFAULT=1
PWP__PW__RETRIEVAL_STEP_DEFAULT=false
```

Create the desired user before disabling signups, or create it through Rails console/admin tooling.

## Old-browser note

The `/s/<code>` passphrase and secret pages use server-rendered HTML forms and inline CSS only. They intentionally do not depend on JavaScript, Web Crypto, Turbo, Bootstrap or Clipboard APIs. That removes the application-level compatibility blocker for browsers as old as iOS 6 Safari. TLS/certificate compatibility still depends on the reverse proxy/CDN in front of the service and should be tested on the actual old device.
