import Foundation
import Network

struct WiiMDevice: Identifiable, Hashable {
    let id: String
    let name: String
    let host: String
    let port: UInt16

    var displayName: String {
        name.isEmpty ? host : name
    }
}

@MainActor
@Observable
class DeviceDiscovery {
    var devices: [WiiMDevice] = []
    var isSearching: Bool = false

    private var browser: NWBrowser?

    func startDiscovery() {
        devices = []
        isSearching = true

        // WiiM devices advertise as LinkPlay devices
        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        // Try _linkplay._tcp first (WiiM specific)
        let browser = NWBrowser(for: .bonjour(type: "_linkplay._tcp", domain: "local."), using: parameters)
        self.browser = browser

        browser.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                switch state {
                case .ready:
                    print("Browser ready")
                case let .failed(error):
                    print("Browser failed: \(error)")
                    self?.isSearching = false
                case .cancelled:
                    self?.isSearching = false
                default:
                    break
                }
            }
        }

        browser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor in
                self?.handleResults(results)
            }
        }

        browser.start(queue: .main)

        // Stop after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            self?.stopDiscovery()
        }
    }

    func stopDiscovery() {
        browser?.cancel()
        browser = nil
        isSearching = false
    }

    private func handleResults(_ results: Set<NWBrowser.Result>) {
        for result in results {
            switch result.endpoint {
            case let .service(name, type, domain, _):
                resolveService(name: name, type: type, domain: domain)
            default:
                break
            }
        }
    }

    private func resolveService(name: String, type: String, domain: String) {
        let parameters = NWParameters.tcp
        let endpoint = NWEndpoint.service(name: name, type: type, domain: domain, interface: nil)
        let connection = NWConnection(to: endpoint, using: parameters)

        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                if let endpoint = connection.currentPath?.remoteEndpoint,
                   case let .hostPort(host, port) = endpoint
                {
                    let hostString: String = switch host {
                    case let .ipv4(addr):
                        Self.ipv4String(from: addr)
                    case let .ipv6(addr):
                        Self.ipv6String(from: addr)
                    case let .name(hostname, _):
                        hostname
                    @unknown default:
                        ""
                    }

                    if !hostString.isEmpty {
                        Task { @MainActor [weak self] in
                            guard let self else { return }
                            let device = WiiMDevice(
                                id: "\(hostString):\(port)",
                                name: name,
                                host: hostString,
                                port: port.rawValue
                            )
                            if !self.devices.contains(where: { $0.host == hostString }) {
                                self.devices.append(device)
                            }
                        }
                    }
                }
                connection.cancel()
            case .failed, .cancelled:
                break
            default:
                break
            }
        }

        connection.start(queue: .global())
    }

    private nonisolated static func cleanIPAddress(_ str: String) -> String {
        // Remove interface suffix like %en0
        if let percentIndex = str.firstIndex(of: "%") {
            return String(str[..<percentIndex])
        }
        return str
    }

    private nonisolated static func ipv4String(from address: IPv4Address) -> String {
        // Use debugDescription but clean it
        cleanIPAddress(address.debugDescription)
    }

    private nonisolated static func ipv6String(from address: IPv6Address) -> String {
        // For IPv6, use debugDescription but clean it
        cleanIPAddress(address.debugDescription)
    }
}
