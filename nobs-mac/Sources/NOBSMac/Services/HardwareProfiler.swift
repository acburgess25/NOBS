import Foundation

struct HardwareProfiler {
    func currentProfile() async -> HardwareProfile {
        await Task.detached(priority: .utility) {
            HardwareProfile(
                modelIdentifier: Self.shell("/usr/sbin/sysctl", "-n", "hw.model"),
                chipName: Self.shell("/usr/sbin/sysctl", "-n", "machdep.cpu.brand_string"),
                memoryGB: Self.memoryGB(),
                cpuCores: Int(Self.shell("/usr/sbin/sysctl", "-n", "hw.ncpu")) ?? 0,
                gpuDescription: Self.gpuDescription()
            )
        }.value
    }

    private static func memoryGB() -> Int {
        guard let bytes = Int64(shell("/usr/sbin/sysctl", "-n", "hw.memsize")) else { return 0 }
        return Int((Double(bytes) / 1_073_741_824).rounded())
    }

    private static func gpuDescription() -> String {
        let output = shell("/usr/sbin/system_profiler", "SPDisplaysDataType")
        return output
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { $0.localizedCaseInsensitiveContains("Chipset Model") }
            .map { $0.replacingOccurrences(of: "Chipset Model:", with: "").trimmingCharacters(in: .whitespaces) }
            ?? "Unknown GPU"
    }

    private static func shell(_ executable: String, _ arguments: String...) -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(filePath: executable)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        } catch {
            return ""
        }
    }
}
