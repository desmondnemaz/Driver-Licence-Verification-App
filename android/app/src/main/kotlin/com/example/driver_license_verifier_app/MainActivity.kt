package com.example.driver_license_verifier_app

import android.os.Handler
import android.os.Looper
import android.util.Base64
import androidx.annotation.NonNull
import com.za.finger.ZAAPI
import com.zaz.zazjni.ZAZJni
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedWriter
import java.io.File
import java.io.FileWriter
import java.io.IOException
import java.util.*
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.finger.get/battery"
    private lateinit var zaclient: ZAAPI
    private lateinit var za: ZAZJni
    private val bgPool = Executors.newSingleThreadExecutor()
    private val FINGER_POWER_PATCH = "/sys/devices/platform/m536as_gpio_pin/usbhub4_power"
    
    // Using the synchronized dimensions from Fingerprintsy
    private val IMG_WIDTH = 256
    private val IMG_HEIGHT = 288
    private val Image = ByteArray(IMG_WIDTH * IMG_HEIGHT)

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        zaclient = ZAAPI()
        za = ZAZJni()

        // Hardware Reset/Power On
        IO_Switch(FINGER_POWER_PATCH, 0)
        Thread.sleep(100)
        IO_Switch(FINGER_POWER_PATCH, 1)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "opendev" -> {
                    bgPool.execute {
                        val status = zaclient.opendevice(this, 1, 4, 6, 0, 0)
                        Handler(Looper.getMainLooper()).post {
                            if (status == 1) {
                                zaclient.ZAZSetImageSize(IMG_WIDTH * IMG_HEIGHT)
                                result.success(0)
                            } else {
                                result.error("UNAVAILABLE", "Scanner hardware not found", null)
                            }
                        }
                    }
                }

                "enroll" -> {
                    bgPool.execute {
                        val DEV_ADDR = -0x1
                        val len = IntArray(1)
                        val fpchar = ByteArray(512)
                        
                        if (zaclient.ZAZGetImage(DEV_ADDR) == 0) {
                            zaclient.ZAZUpImage(DEV_ADDR, Image, len)
                            if (zaclient.ZAZGenChar(DEV_ADDR, 1) == 0) {
                                if (zaclient.ZAZUpChar(DEV_ADDR, 1, fpchar, len) == 0) {
                                    val map = HashMap<String, Any>()
                                    map["text"] = Base64.encodeToString(fpchar, Base64.NO_WRAP)
                                    // Wrap raw bytes in BMP Header before sending to Flutter
                                    map["bytes"] = addBMPHeader(Image, IMG_WIDTH, IMG_HEIGHT)
                                    Handler(Looper.getMainLooper()).post { result.success(map) }
                                    return@execute
                                }
                            }
                        }
                        Handler(Looper.getMainLooper()).post { result.error("ENROLL_FAIL", "Capture failed", null) }
                    }
                }

                "search" -> {
                    val strList = call.argument<List<String>>("fpcharlist") ?: emptyList()
                    val timeNum = call.argument<Number>("time")?.toLong() ?: 15000L
                    
                    bgPool.execute {
                        val DEV_ADDR = -0x1
                        val len = IntArray(1)
                        val fpchar = ByteArray(512)
                        val start = System.currentTimeMillis()
                        val searchImage = ByteArray(IMG_WIDTH * IMG_HEIGHT)

                        var found = false
                        while (System.currentTimeMillis() - start < timeNum) {
                            if (zaclient.ZAZGetImage(DEV_ADDR) != 0) {
                                Thread.sleep(100)
                                continue
                            }
                            if (zaclient.ZAZUpImage(DEV_ADDR, searchImage, len) != 0) continue
                            zaclient.ZAZGenChar(DEV_ADDR, 1)
                            zaclient.ZAZUpChar(DEV_ADDR, 1, fpchar, len)

                            val liveFp = Base64.encodeToString(fpchar, Base64.NO_WRAP)

                            for (i in strList.indices) {
                                // Match live scan against the list from Flutter
                                val score = match2fp(liveFp, strList[i])
                                if (score >= 30) {
                                    val m = HashMap<String, Any>()
                                    m["score"] = score
                                    m["id"] = i
                                    m["bytes"] = addBMPHeader(searchImage, IMG_WIDTH, IMG_HEIGHT)
                                    Handler(Looper.getMainLooper()).post { result.success(m) }
                                    found = true
                                    break
                                }
                            }
                            if (found) break
                        }
                        if (!found) {
                            Handler(Looper.getMainLooper()).post { 
                                val m = HashMap<String, Any>()
                                m["id"] = -1
                                result.success(m) 
                            }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    // --- BMP ENCODER (Crucial for Flutter Image.memory) ---
    private fun addBMPHeader(rawData: ByteArray, width: Int, height: Int): ByteArray {
        val headerSize = 54
        val paletteSize = 1024
        val buffer = ByteArray(headerSize + paletteSize + rawData.size)
        
        // 'BM' Signature
        buffer[0] = 'B'.toByte(); buffer[1] = 'M'.toByte()
        val fileSize = buffer.size
        buffer[2] = (fileSize and 0xFF).toByte()
        buffer[3] = (fileSize ushr 8 and 0xFF).toByte()
        buffer[4] = (fileSize ushr 16 and 0xFF).toByte()
        buffer[5] = (fileSize ushr 24 and 0xFF).toByte()
        buffer[10] = (headerSize + paletteSize).toByte()

        // Info Header
        buffer[14] = 40.toByte()
        buffer[18] = (width and 0xFF).toByte()
        buffer[19] = (width ushr 8 and 0xFF).toByte()
        buffer[22] = (height and 0xFF).toByte()
        buffer[23] = (height ushr 8 and 0xFF).toByte()
        buffer[26] = 1.toByte()
        buffer[28] = 8.toByte() // 8-bit grayscale

        // Create Grayscale Palette
        for (i in 0 until 256) {
            val off = headerSize + i * 4
            buffer[off] = i.toByte()     // B
            buffer[off + 1] = i.toByte() // G
            buffer[off + 2] = i.toByte() // R
            buffer[off + 3] = 0.toByte()
        }

        System.arraycopy(rawData, 0, buffer, headerSize + paletteSize, rawData.size)
        return buffer
    }

    private fun IO_Switch(path: String, on: Int): Int {
        return try {
            val powerFile = File(path)
            if (!powerFile.exists()) return 0
            val writer = BufferedWriter(FileWriter(powerFile))
            writer.write(on.toString())
            writer.close()
            1
        } catch (e: IOException) { 0 }
    }

    private fun match2fp(fp1: String, fp2: String): Int {
        return try {
            val b1 = Base64.decode(fp1, Base64.DEFAULT)
            val b2 = Base64.decode(fp2, Base64.DEFAULT)
            za.ZAZMatch2Fp(b1, b2)
        } catch (e: Exception) { 0 }
    }

    override fun onDestroy() {
        IO_Switch(FINGER_POWER_PATCH, 0) // Power off scanner to save battery
        bgPool.shutdownNow()
        super.onDestroy()
    }
}