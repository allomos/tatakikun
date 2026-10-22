package com.tatakikun.android

import android.content.Context
import java.io.File

/**
 * The language packs ship inside the APK (assets/packs/<zh|ja|en>/…); the engine memory-maps them,
 * so they are copied once into the app's files, again when the app is updated.
 */
object Packs {
    fun folder(context: Context): File {
        val dir = File(context.filesDir, "packs")
        val stamp = File(dir, ".version")
        val version = context.packageManager.getPackageInfo(context.packageName, 0).longVersionCode.toString() +
            "-" + context.packageManager.getPackageInfo(context.packageName, 0).lastUpdateTime
        if (stamp.isFile && stamp.readText() == version) return dir
        dir.deleteRecursively()
        for (lang in context.assets.list("packs").orEmpty()) {
            val target = File(dir, lang).apply { mkdirs() }
            for (name in context.assets.list("packs/$lang").orEmpty()) {
                context.assets.open("packs/$lang/$name").use { input ->
                    File(target, name).outputStream().use { input.copyTo(it) }
                }
            }
        }
        stamp.writeText(version)
        return dir
    }
}
