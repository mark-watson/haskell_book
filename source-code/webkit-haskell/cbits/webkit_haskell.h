/*
 * webkit_haskell.h — C API for webkit-haskell
 *
 * A minimal C interface to macOS Cocoa + WKWebView, designed to be
 * called from Haskell via FFI.
 *
 * Thread safety: All functions must be called from the main thread.
 */

#ifndef WEBKIT_HASKELL_H
#define WEBKIT_HASKELL_H

#ifdef __cplusplus
extern "C" {
#endif

/* Opaque handle to a webkit-haskell application instance */
typedef void* wkhsk_app_t;

/*
 * Callback type for bridge invocations from JavaScript.
 *
 * When JS calls window.webkit_haskell.invoke(command, payload),
 * this callback fires.
 *
 * The callback must return a malloc'd JSON string (the bridge will free it),
 * or NULL to indicate no response / error.
 */
typedef const char* (*wkhsk_bridge_callback_t)(const char* command,
                                               const char* payload,
                                               void* userdata);

/* ── Lifecycle ───────────────────────────────────────────────── */

wkhsk_app_t wkhsk_create(const char* title, int width, int height);
void wkhsk_run(wkhsk_app_t app);
void wkhsk_quit(wkhsk_app_t app);
void wkhsk_destroy(wkhsk_app_t app);

/* ── Content Loading ─────────────────────────────────────────── */

void wkhsk_load_html(wkhsk_app_t app, const char* html);
void wkhsk_load_url(wkhsk_app_t app, const char* url);
void wkhsk_load_file(wkhsk_app_t app, const char* path);

/* ── JavaScript ──────────────────────────────────────────────── */

void wkhsk_eval_js(wkhsk_app_t app, const char* js);

/* ── Bridge ──────────────────────────────────────────────────── */

void wkhsk_set_bridge_callback(wkhsk_app_t app,
                               wkhsk_bridge_callback_t callback,
                               void* userdata);

/* ── Window Management ───────────────────────────────────────── */

void wkhsk_set_title(wkhsk_app_t app, const char* title);
void wkhsk_set_size(wkhsk_app_t app, int width, int height);
void wkhsk_set_resizable(wkhsk_app_t app, int resizable);

#ifdef __cplusplus
}
#endif

#endif /* WEBKIT_HASKELL_H */
