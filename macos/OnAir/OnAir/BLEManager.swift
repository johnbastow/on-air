import CoreBluetooth
import Foundation

private let serviceUUID    = CBUUID(string: "19B10000-E8F2-537E-4F6C-D104768A1214")
private let micStateUUID   = CBUUID(string: "19B10001-E8F2-537E-4F6C-D104768A1214")
private let deviceListUUID = CBUUID(string: "19B10002-E8F2-537E-4F6C-D104768A1214")
private let adminCmdUUID   = CBUUID(string: "19B10003-E8F2-537E-4F6C-D104768A1214")

private let kArduinoUUIDKey = "arduinoPeripheralUUID"

// Admin command bytes — must match Arduino firmware
private let cmdRemoveDevice: UInt8 = 0x01
private let cmdClearAll: UInt8     = 0x02

enum ConnectionState {
    case bluetoothUnavailable
    case scanning
    case connecting
    case connected
    case disconnected
}

/// Manages the BLE connection to the Arduino on-air-light peripheral.
/// All CBCentralManager callbacks run on the main queue, so all property
/// mutations happen on the main thread.
final class BLEManager: NSObject {

    /// Called on the main thread whenever the connection state changes.
    var onStateChanged: ((ConnectionState) -> Void)?
    /// Called on the main thread whenever the Arduino's paired device list is read.
    var onDeviceListUpdated: (([String]) -> Void)?

    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var micStateChar: CBCharacteristic?
    private var deviceListChar: CBCharacteristic?
    private var adminCmdChar: CBCharacteristic?
    private var reconnectTimer: Timer?

    func start() {
        // queue: .main ensures all delegate callbacks arrive on the main thread
        central = CBCentralManager(delegate: self, queue: .main)
    }

    // MARK: - Public interface (call from main thread)

    func sendMicState(_ active: Bool) {
        guard let char = micStateChar, isReady else { return }
        let byte: UInt8 = active ? 1 : 0
        peripheral?.writeValue(Data([byte]), for: char, type: .withoutResponse)
    }

    func removeDevice(_ mac: String) {
        guard let char = adminCmdChar, isReady else { return }
        let bytes = mac.split(separator: ":").compactMap { UInt8($0, radix: 16) }
        guard bytes.count == 6 else { return }
        var data = Data([cmdRemoveDevice])
        data.append(contentsOf: bytes)
        peripheral?.writeValue(data, for: char, type: .withoutResponse)
        scheduleDeviceListRefresh()
    }

    func clearAllDevices() {
        guard let char = adminCmdChar, isReady else { return }
        peripheral?.writeValue(Data([cmdClearAll]), for: char, type: .withoutResponse)
        scheduleDeviceListRefresh()
    }

    /// Clears the stored peripheral UUID and starts scanning from scratch.
    func forget() {
        reconnectTimer?.invalidate()
        if let p = peripheral { central.cancelPeripheralConnection(p) }
        peripheral = nil
        clearCharacteristics()
        UserDefaults.standard.removeObject(forKey: kArduinoUUIDKey)
        scan()
    }

    // MARK: - Private helpers

    private var isReady: Bool {
        peripheral?.state == .connected && micStateChar != nil
    }

    private func clearCharacteristics() {
        micStateChar = nil
        deviceListChar = nil
        adminCmdChar = nil
    }

    private func scan() {
        onStateChanged?(.scanning)
        central.scanForPeripherals(withServices: [serviceUUID])
    }

    private func readDeviceList() {
        guard let char = deviceListChar, isReady else { return }
        peripheral?.readValue(for: char)
    }

    private func scheduleDeviceListRefresh() {
        // Give the Arduino a moment to update its EEPROM before we re-read
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.readDeviceList()
        }
    }

    private func scheduleReconnect() {
        reconnectTimer?.invalidate()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            self?.scan()
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            // Try to reconnect to the last known peripheral without scanning
            if let uuidString = UserDefaults.standard.string(forKey: kArduinoUUIDKey),
               let uuid = UUID(uuidString: uuidString) {
                let known = central.retrievePeripherals(withIdentifiers: [uuid])
                if let p = known.first {
                    peripheral = p
                    p.delegate = self
                    onStateChanged?(.connecting)
                    central.connect(p)
                    return
                }
            }
            scan()
        case .poweredOff, .unauthorized, .unsupported:
            onStateChanged?(.bluetoothUnavailable)
        default:
            break
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard peripheral.name == "on-air-light" else { return }
        central.stopScan()
        self.peripheral = peripheral
        peripheral.delegate = self
        onStateChanged?(.connecting)
        central.connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        UserDefaults.standard.set(peripheral.identifier.uuidString, forKey: kArduinoUUIDKey)
        onStateChanged?(.connected)
        peripheral.discoverServices([serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        onStateChanged?(.disconnected)
        scheduleReconnect()
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        clearCharacteristics()
        onStateChanged?(.disconnected)
        scheduleReconnect()
    }
}

// MARK: - CBPeripheralDelegate

extension BLEManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let service = peripheral.services?.first(where: { $0.uuid == serviceUUID }) else { return }
        peripheral.discoverCharacteristics([micStateUUID, deviceListUUID, adminCmdUUID], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        for char in service.characteristics ?? [] {
            switch char.uuid {
            case micStateUUID:
                micStateChar = char
            case deviceListUUID:
                deviceListChar = char
                peripheral.readValue(for: char) // load current list on connect
            case adminCmdUUID:
                adminCmdChar = char
            default:
                break
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard characteristic.uuid == deviceListUUID, let data = characteristic.value else { return }
        guard !data.isEmpty else { onDeviceListUpdated?([]); return }

        let count = Int(data[0])
        var macs: [String] = []
        for i in 0..<count {
            let offset = 1 + i * 6
            guard offset + 6 <= data.count else { break }
            let mac = data[offset..<offset + 6].map { String(format: "%02x", $0) }.joined(separator: ":")
            macs.append(mac)
        }
        onDeviceListUpdated?(macs)
    }
}
