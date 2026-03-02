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
    
    private val IMG_WIDTH = 256
    private val IMG_HEIGHT = 288
    // Using the manufacturer's larger buffer for stability
    private val RAW_BUFFER_SIZE = 256 * 360 
    private val rawImage = ByteArray(RAW_BUFFER_SIZE)

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        zaclient = ZAAPI()
        za = ZAZJni()

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
                        val resultData = processCapture()
                        Handler(Looper.getMainLooper()).post {
                            if (resultData != null) result.success(resultData)
                            else result.error("ENROLL_FAIL", "Capture failed", null)
                        }
                    }
                }

                "search" -> {
                    val strList = call.argument<List<String>>("fpcharlist") ?: emptyList()
                    val timeNum = call.argument<Number>("time")?.toLong() ?: 15000L
                    
                    bgPool.execute {
                        val start = System.currentTimeMillis()
                        var matchFound: HashMap<String, Any>? = null

                        while (System.currentTimeMillis() - start < timeNum) {
                            val currentCapture = processCapture()
                            if (currentCapture != null) {
                                val liveFp = currentCapture["text"] as String
                                for (i in strList.indices) {
                                    val score = match2fp(liveFp, strList[i])
                                    if (score >= 30) {
                                        currentCapture["score"] = score
                                        currentCapture["id"] = i
                                        matchFound = currentCapture
                                        break
                                    }
                                }
                            }
                            if (matchFound != null) break
                            Thread.sleep(100)
                        }

                        Handler(Looper.getMainLooper()).post {
                            if (matchFound != null) result.success(matchFound)
                            else {
                                val fail = HashMap<String, Any>()
                                fail["id"] = -1
                                result.success(fail)
                            }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    // --- THE WINNING LOGIC: CAPTURE + RGB LOOP ---
    private fun processCapture(): HashMap<String, Any>? {
        val DEV_ADDR = -0x1
        val len = IntArray(1)
        val fpchar = ByteArray(512)

        if (zaclient.ZAZGetImage(DEV_ADDR) == 0) {
            zaclient.ZAZUpImage(DEV_ADDR, rawImage, len)
            if (zaclient.ZAZGenChar(DEV_ADDR, 1) == 0) {
                if (zaclient.ZAZUpChar(DEV_ADDR, 1, fpchar, len) == 0) {
                    
                    // START TRIPLE-CHANNEL LOOP
                    val rgbData = ByteArray(IMG_WIDTH * IMG_HEIGHT * 3)
                    for (i in 0 until IMG_HEIGHT) {
                        for (j in 0 until IMG_WIDTH) {
                            val gray = rawImage[i * IMG_WIDTH + j]
                            val base = (i * IMG_WIDTH * 3) + (j * 3)
                            rgbData[base] = gray     // R
                            rgbData[base + 1] = gray // G
                            rgbData[base + 2] = gray // B
                        }
                    }

                    val map = HashMap<String, Any>()
                    map["text"] = Base64.encodeToString(fpchar, Base64.NO_WRAP)
                    map["bytes"] = addBMP24Header(IMG_WIDTH, IMG_HEIGHT, rgbData)
                    return map
                }
            }
        }
        return null
    }

    private fun addBMP24Header(width: Int, height: Int, data: ByteArray): ByteArray {
        val headerSize = 54
        val bmp = ByteArray(headerSize + data.size)
        val totalSize = bmp.size

        // File Header
        bmp[0] = 'B'.toByte(); bmp[1] = 'M'.toByte()
        bmp[2] = (totalSize and 0xFF).toByte()
        bmp[3] = (totalSize shr 8 and 0xFF).toByte()
        bmp[4] = (totalSize shr 16 and 0xFF).toByte()
        bmp[5] = (totalSize shr 24 and 0xFF).toByte()
        bmp[10] = headerSize.toByte()

        // Info Header
        bmp[14] = 40.toByte()
        bmp[18] = (width and 0xFF).toByte(); bmp[19] = (width shr 8 and 0xFF).toByte()
        
        // Flipped Height for Correct Orientation
        val negHeight = -height
        bmp[22] = (negHeight and 0xFF).toByte()
        bmp[23] = (negHeight shr 8 and 0xFF).toByte()
        bmp[24] = (negHeight shr 16 and 0xFF).toByte()
        bmp[25] = (negHeight shr 24 and 0xFF).toByte()

        bmp[26] = 1.toByte()
        bmp[28] = 24.toByte() // 24-bit RGB

        System.arraycopy(data, 0, bmp, headerSize, data.size)
        return bmp
    }

    private fun match2fp(fp1: String, fp2: String): Int {
        return try {
            val b1 = Base64.decode(fp1, Base64.DEFAULT)
            val b2 = Base64.decode(fp2, Base64.DEFAULT)
            za.ZAZMatch2Fp(b1, b2)
        } catch (e: Exception) { 0 }
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

    override fun onDestroy() {
        IO_Switch(FINGER_POWER_PATCH, 0)
        bgPool.shutdownNow()
        super.onDestroy()
    }
}