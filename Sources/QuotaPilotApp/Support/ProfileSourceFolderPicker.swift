import AppKit

enum ProfileSourceFolderPicker {
    @MainActor
    static func chooseFolder(startingAt path: String?) -> String? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose Folder"
        panel.message = "Select the profile root directory to track."

        if let path,
           !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            panel.directoryURL = URL(fileURLWithPath: path, isDirectory: true)
        }

        return panel.runModal() == .OK ? panel.url?.standardizedFileURL.path : nil
    }
}
