package com.example.pos_flutter

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.*
import android.os.Build
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.net.InetSocketAddress
import java.net.Socket

class MainActivity : FlutterActivity() {
    private val PRINTER_CHANNEL = "com.casolution.pos/printer"
    private val TAG = "POS_NativePrinter"
    private val ACTION_USB_PERMISSION = "com.casolution.pos.USB_PERMISSION"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Request USB permissions upfront on startup so POS hardware is immediately usable
        requestUsbPermissionsForPrinters()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PRINTER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "printRawData" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    if (bytes == null || bytes.isEmpty()) {
                        result.error("EMPTY_BYTES", "Print data cannot be empty", null)
                        return@setMethodCallHandler
                    }
                    val printed = printDirectToThermalHardware(bytes)
                    result.success(printed)
                }
                "kickCashDrawer" -> {
                    // Standard ESC/POS pulse command to pin 2 / 5 of RJ11 drawer port: ESC p 0 25 250
                    val drawerCommand = byteArrayOf(0x1B, 0x70, 0x00, 0x19, 0xFA.toByte())
                    val kicked = printDirectToThermalHardware(drawerCommand)
                    result.success(kicked)
                }
                "getPrinterStatus" -> {
                    val info = getDetectedHardwareInfo()
                    result.success(info)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun requestUsbPermissionsForPrinters() {
        try {
            val usbManager = getSystemService(Context.USB_SERVICE) as? UsbManager ?: return
            val deviceList = usbManager.deviceList ?: return
            for (device in deviceList.values) {
                if (isCandidatePrinterDevice(device) && !usbManager.hasPermission(device)) {
                    Log.i(TAG, "Requesting USB permission for ${device.deviceName} (VID: ${device.vendorId}, PID: ${device.productId})")
                    val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                    } else {
                        PendingIntent.FLAG_UPDATE_CURRENT
                    }
                    val permissionIntent = PendingIntent.getBroadcast(
                        this,
                        0,
                        Intent(ACTION_USB_PERMISSION),
                        flags
                    )
                    usbManager.requestPermission(device, permissionIntent)
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed requesting USB permissions: ${e.message}")
        }
    }

    private fun isCandidatePrinterDevice(device: UsbDevice): Boolean {
        if (device.deviceClass == UsbConstants.USB_CLASS_PRINTER) return true

        // Known thermal printer & USB-to-Serial bridge VIDs commonly used in POS terminals
        val printerVids = setOf(
            0x0483, // STMicroelectronics / Xprinter
            0x0416, // Winbond / Gprinter
            0x04b8, // Epson
            0x04f9, // Brother
            0x0519, // Star Micronics
            0x0fe6, // ICS
            0x1fc9, // NXP POS
            0x20d1, // Rongta
            0x0dd4, // Custom POS
            0x1504, // SNBC
            0x067b, // Prolific PL2303 USB-to-Serial
            0x1a86, // WCH CH340 USB-to-Serial
            0x10c4, // Silicon Labs CP210x USB-to-UART
            0x0403  // FTDI FT232
        )
        if (printerVids.contains(device.vendorId)) return true

        // Check interfaces
        for (i in 0 until device.interfaceCount) {
            val intf = device.getInterface(i)
            if (intf.interfaceClass == UsbConstants.USB_CLASS_PRINTER ||
                intf.interfaceClass == 255 ||
                intf.interfaceClass == 0
            ) {
                for (j in 0 until intf.endpointCount) {
                    val ep = intf.getEndpoint(j)
                    if (ep.type == UsbConstants.USB_ENDPOINT_XFER_BULK &&
                        ep.direction == UsbConstants.USB_DIR_OUT
                    ) {
                        return true
                    }
                }
            }
        }
        return false
    }

    /**
     * Sends raw ESC/POS byte sequence directly to the Android POS machine's built-in printer
     * using a 3-tier hardware pipeline:
     * 1. Direct USB Host bulk transfer (for USB / internal USB POS printers)
     * 2. Linux character device nodes (/dev/usb/lp0, /dev/ttyS*, etc.)
     * 3. Localhost POS print daemon (127.0.0.1:9100)
     */
    private fun printDirectToThermalHardware(bytes: ByteArray): Boolean {
        // Tier 1: Direct USB Host Bulk Transfer
        try {
            if (printViaUsbHost(bytes)) {
                Log.i(TAG, "Successfully printed via USB Host API (${bytes.size} bytes)")
                return true
            }
        } catch (e: Exception) {
            Log.w(TAG, "USB Host print attempt failed: ${e.message}")
        }

        // Tier 2: Linux character device nodes
        try {
            if (printViaLinuxDeviceNodes(bytes)) {
                Log.i(TAG, "Successfully printed via Linux device node (${bytes.size} bytes)")
                return true
            }
        } catch (e: Exception) {
            Log.w(TAG, "Linux device node print attempt failed: ${e.message}")
        }

        // Tier 3: Localhost socket daemon (127.0.0.1:9100)
        try {
            if (printViaLocalhostSocket(bytes)) {
                Log.i(TAG, "Successfully printed via Localhost socket 127.0.0.1:9100 (${bytes.size} bytes)")
                return true
            }
        } catch (e: Exception) {
            Log.w(TAG, "Localhost socket print attempt failed: ${e.message}")
        }

        Log.e(TAG, "All direct thermal printer hardware channels failed.")
        return false
    }

    /**
     * Direct print via Android UsbManager to built-in or connected USB thermal printer
     */
    private fun printViaUsbHost(bytes: ByteArray): Boolean {
        val usbManager = getSystemService(Context.USB_SERVICE) as? UsbManager ?: return false
        val deviceList = usbManager.deviceList ?: return false

        if (deviceList.isEmpty()) {
            Log.d(TAG, "No USB devices found on system")
            return false
        }

        for (device in deviceList.values) {
            var printerInterface: UsbInterface? = null
            var outEndpoint: UsbEndpoint? = null

            // Search for printer interface or bulk out endpoint
            for (i in 0 until device.interfaceCount) {
                val intf = device.getInterface(i)
                val isPrinterClass = intf.interfaceClass == UsbConstants.USB_CLASS_PRINTER // 7
                val isVendorClass = intf.interfaceClass == 255 || intf.interfaceClass == 0

                var candidateOut: UsbEndpoint? = null
                for (j in 0 until intf.endpointCount) {
                    val ep = intf.getEndpoint(j)
                    if (ep.type == UsbConstants.USB_ENDPOINT_XFER_BULK &&
                        ep.direction == UsbConstants.USB_DIR_OUT
                    ) {
                        candidateOut = ep
                        break
                    }
                }

                if (candidateOut != null && (isPrinterClass || isVendorClass || isCandidatePrinterDevice(device))) {
                    printerInterface = intf
                    outEndpoint = candidateOut
                    break
                }
            }

            if (printerInterface != null && outEndpoint != null) {
                if (!usbManager.hasPermission(device)) {
                    Log.w(TAG, "No permission for device ${device.deviceName} (VID: ${device.vendorId}), requesting now...")
                    val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                    } else {
                        PendingIntent.FLAG_UPDATE_CURRENT
                    }
                    val permissionIntent = PendingIntent.getBroadcast(
                        this,
                        0,
                        Intent(ACTION_USB_PERMISSION),
                        flags
                    )
                    usbManager.requestPermission(device, permissionIntent)
                    // Continue checking other devices if permission was pending
                }

                var connection: UsbDeviceConnection? = null
                try {
                    connection = usbManager.openDevice(device)
                    if (connection == null) {
                        Log.w(TAG, "Cannot open USB device ${device.deviceName}")
                        continue
                    }

                    if (!connection.claimInterface(printerInterface, true)) {
                        Log.w(TAG, "Cannot claim interface for device ${device.deviceName}")
                        connection.close()
                        continue
                    }

                    // Send in chunks of 4096 bytes to prevent buffer overflow on thermal boards
                    val chunkSize = 4096
                    var offset = 0
                    var allChunksSent = true

                    while (offset < bytes.size) {
                        val length = minOf(chunkSize, bytes.size - offset)
                        val chunk = ByteArray(length)
                        System.arraycopy(bytes, offset, chunk, 0, length)

                        val transferred = connection.bulkTransfer(outEndpoint, chunk, length, 4000)
                        if (transferred < 0) {
                            Log.e(TAG, "bulkTransfer failed: $transferred")
                            allChunksSent = false
                            break
                        }
                        offset += length
                    }

                    connection.releaseInterface(printerInterface)
                    connection.close()

                    if (allChunksSent) {
                        return true
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "Error writing to USB device ${device.deviceName}: ${e.message}")
                    try {
                        connection?.releaseInterface(printerInterface)
                        connection?.close()
                    } catch (_: Exception) {}
                }
            }
        }

        return false
    }

    /**
     * Direct print via Linux character device nodes on Android (/dev/usb/lp0, /dev/ttyS*)
     */
    private fun printViaLinuxDeviceNodes(bytes: ByteArray): Boolean {
        val candidatePaths = listOf(
            "/dev/usb/lp0",
            "/dev/usb/lp1",
            "/dev/ttyS1",
            "/dev/ttyS3",
            "/dev/ttyS4",
            "/dev/ttyS0",
            "/dev/ttyMSM1",
            "/dev/ttyMSM2",
            "/dev/ttyMT0",
            "/dev/ttyMT1",
            "/dev/ttyMT2",
            "/dev/ttyAMA0"
        )

        for (path in candidatePaths) {
            val file = File(path)
            if (file.exists()) {
                if (!file.canWrite()) {
                    try {
                        file.setWritable(true, false)
                    } catch (_: Exception) {}
                    try {
                        Runtime.getRuntime().exec(arrayOf("chmod", "666", path)).waitFor()
                    } catch (_: Exception) {}
                }

                if (file.canWrite()) {
                    try {
                        FileOutputStream(file).use { output ->
                            output.write(bytes)
                            output.flush()
                        }
                        Log.i(TAG, "Successfully wrote ${bytes.size} bytes to $path")
                        return true
                    } catch (e: Exception) {
                        Log.w(TAG, "Failed writing to device node $path: ${e.message}")
                    }
                }
            }
        }

        return false
    }

    /**
     * Direct print via Localhost loopback daemon (127.0.0.1:9100)
     */
    private fun printViaLocalhostSocket(bytes: ByteArray): Boolean {
        var socket: Socket? = null
        try {
            socket = Socket()
            socket.connect(InetSocketAddress("127.0.0.1", 9100), 300)
            val output = socket.getOutputStream()
            output.write(bytes)
            output.flush()
            socket.close()
            return true
        } catch (_: Exception) {
            try {
                socket?.close()
            } catch (_: Exception) {}
            return false
        }
    }

    /**
     * Diagnostics to identify the Android POS terminal hardware details
     */
    private fun getDetectedHardwareInfo(): Map<String, Any> {
        val usbManager = getSystemService(Context.USB_SERVICE) as? UsbManager
        val usbDeviceNames = usbManager?.deviceList?.values?.map {
            "${it.deviceName} (Vendor:${it.vendorId}, Product:${it.productId}, HasPerm:${usbManager.hasPermission(it)})"
        } ?: emptyList()

        val nodes = listOf("/dev/usb/lp0", "/dev/usb/lp1", "/dev/ttyS1", "/dev/ttyS3")
        val nodeStatus = nodes.map { "$it (exists:${File(it).exists()}, writable:${File(it).canWrite()})" }

        return mapOf(
            "manufacturer" to Build.MANUFACTURER,
            "model" to Build.MODEL,
            "device" to Build.DEVICE,
            "usbDevices" to usbDeviceNames,
            "deviceNodes" to nodeStatus
        )
    }
}
