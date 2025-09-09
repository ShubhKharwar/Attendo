package com.example.attendo

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.content.Context
import android.os.Bundle
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer
import java.util.*

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.attendo/beacon"
    private var advertiser: BluetoothLeAdvertiser? = null
    private var advertiseCallback: AdvertiseCallback? = null
    
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startBeacon" -> {
                    val uuid = call.argument<String>("uuid") ?: ""
                    val major = call.argument<Int>("major") ?: 0
                    val minor = call.argument<Int>("minor") ?: 0
                    startBeacon(uuid, major, minor)
                    result.success(null)
                }
                "stopBeacon" -> {
                    stopBeacon()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
    
    private fun startBeacon(uuidStr: String, major: Int, minor: Int) {
        val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        val bluetoothAdapter = bluetoothManager.adapter
        advertiser = bluetoothAdapter.bluetoothLeAdvertiser
        
        val advertiseData = buildBeaconAdvertiseData(uuidStr, major, minor)
        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH)
            .setConnectable(false)
            .build()
            
        advertiseCallback = object : AdvertiseCallback() {
            override fun onStartSuccess(settingsInEffect: AdvertiseSettings) {
                super.onStartSuccess(settingsInEffect)
                // Beacon started successfully
            }
            
            override fun onStartFailure(errorCode: Int) {
                super.onStartFailure(errorCode)
                // Handle beacon start failure
            }
        }
        
        advertiser?.startAdvertising(settings, advertiseData, advertiseCallback)
    }
    
    private fun stopBeacon() {
        advertiser?.stopAdvertising(advertiseCallback)
    }
    
    private fun buildBeaconAdvertiseData(uuidStr: String, major: Int, minor: Int): AdvertiseData {
        val manufacturerData = ByteArray(23)
        manufacturerData[0] = 0x02 // Length
        manufacturerData[1] = 0x15 // iBeacon type
        
        val uuid = UUID.fromString(uuidStr)
        val bb = ByteBuffer.wrap(ByteArray(16))
        bb.putLong(uuid.mostSignificantBits)
        bb.putLong(uuid.leastSignificantBits)
        val uuidBytes = bb.array()
        System.arraycopy(uuidBytes, 0, manufacturerData, 2, 16)
        
        manufacturerData[18] = (major shr 8).toByte()
        manufacturerData[19] = (major and 0xFF).toByte()
        manufacturerData[20] = (minor shr 8).toByte()
        manufacturerData[21] = (minor and 0xFF).toByte()
        manufacturerData[22] = (-59).toByte() // Measured Power
        
        return AdvertiseData.Builder()
            .addManufacturerData(0x004C, manufacturerData) // Apple company ID
            .build()
    }
}
