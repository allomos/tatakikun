// Kotlin's Engine (com.tatakikun.android.Engine) over the engine's C interface. Results are UTF-8
// JSON, handed to Kotlin as bytes (NewStringUTF would mangle characters outside the BMP).
#include <jni.h>
#include <stdint.h>
#include <string.h>

void *ttk_create(const char *packs, const char *data);
void ttk_destroy(void *handle);
void ttk_set_text_before(void *handle, const char *text);
void ttk_set_turned_off(void *handle, const char *languages);
char *ttk_key(void *handle, int32_t kind, uint32_t scalar);
char *ttk_choose(void *handle, int32_t row, int32_t column);
char *ttk_finish(void *handle);
void ttk_free(char *p);

static jbyteArray take(JNIEnv *env, char *s) {
    if (!s) return NULL;
    jsize n = (jsize)strlen(s);
    jbyteArray out = (*env)->NewByteArray(env, n);
    (*env)->SetByteArrayRegion(env, out, 0, n, (const jbyte *)s);
    ttk_free(s);
    return out;
}

JNIEXPORT jlong JNICALL
Java_com_tatakikun_android_Engine_create(JNIEnv *env, jclass cls, jstring packs, jstring data) {
    const char *p = (*env)->GetStringUTFChars(env, packs, NULL);
    const char *d = (*env)->GetStringUTFChars(env, data, NULL);
    void *h = ttk_create(p, d);
    (*env)->ReleaseStringUTFChars(env, packs, p);
    (*env)->ReleaseStringUTFChars(env, data, d);
    return (jlong)(intptr_t)h;
}

JNIEXPORT void JNICALL
Java_com_tatakikun_android_Engine_destroy(JNIEnv *env, jclass cls, jlong h) {
    ttk_destroy((void *)(intptr_t)h);
}

JNIEXPORT void JNICALL
Java_com_tatakikun_android_Engine_setTextBefore(JNIEnv *env, jclass cls, jlong h, jbyteArray text) {
    if (!text) { ttk_set_text_before((void *)(intptr_t)h, NULL); return; }
    jsize n = (*env)->GetArrayLength(env, text);
    char buf[64];
    if (n > (jsize)sizeof(buf) - 1) n = sizeof(buf) - 1;
    (*env)->GetByteArrayRegion(env, text, 0, n, (jbyte *)buf);
    buf[n] = 0;
    ttk_set_text_before((void *)(intptr_t)h, buf);
}

JNIEXPORT void JNICALL
Java_com_tatakikun_android_Engine_setTurnedOff(JNIEnv *env, jclass cls, jlong h, jstring languages) {
    const char *s = (*env)->GetStringUTFChars(env, languages, NULL);
    ttk_set_turned_off((void *)(intptr_t)h, s);
    (*env)->ReleaseStringUTFChars(env, languages, s);
}

JNIEXPORT jbyteArray JNICALL
Java_com_tatakikun_android_Engine_key(JNIEnv *env, jclass cls, jlong h, jint kind, jint scalar) {
    return take(env, ttk_key((void *)(intptr_t)h, kind, (uint32_t)scalar));
}

JNIEXPORT jbyteArray JNICALL
Java_com_tatakikun_android_Engine_choose(JNIEnv *env, jclass cls, jlong h, jint row, jint column) {
    return take(env, ttk_choose((void *)(intptr_t)h, row, column));
}

JNIEXPORT jbyteArray JNICALL
Java_com_tatakikun_android_Engine_finish(JNIEnv *env, jclass cls, jlong h) {
    return take(env, ttk_finish((void *)(intptr_t)h));
}
