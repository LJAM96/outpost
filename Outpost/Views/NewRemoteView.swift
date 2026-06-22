import SwiftUI

struct NewRemoteView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    let editingRemote: RcloneRemote?

    @State private var remoteName = ""
    @State private var selectedType = ""
    @State private var parameters: [ParamField] = []
    @State private var providers: [String] = []
    @State private var isLoadingProviders = true
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var isLoadingConfig = false
    @State private var configPrompt: RcloneConfigPrompt?
    @State private var promptAnswer = ""
    @State private var configState: String?
    @State private var useInteractive = true

    struct ParamField: Identifiable {
        let id = UUID()
        var key: String
        var value: String
    }

    var isEditing: Bool { editingRemote != nil }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(isEditing ? "Edit Remote" : "New Remote")
                    .font(.headline)
                Spacer()
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    nameSection
                    typeSection

                    if let prompt = configPrompt {
                        promptSection(prompt)
                    } else if !selectedType.isEmpty && !isEditing {
                        parametersSection
                    }
                }
                .padding()
            }

            Divider()

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)
                Spacer()
                Button {
                    if configPrompt != nil {
                        submitAnswer()
                    } else if isEditing {
                        updateRemote()
                    } else {
                        createRemote()
                    }
                } label: {
                    if isSaving { ProgressView().scaleEffect(0.8) }
                    Text(isEditing ? "Save" : configPrompt != nil ? "Submit Answer" : "Create Remote")
                }
                .keyboardShortcut(.return)
                .disabled(remoteName.isEmpty || selectedType.isEmpty || isSaving)
            }
            .padding()
        }
        .frame(width: 440, height: 480)
        .task {
            await loadProviders()
            if let remote = editingRemote { await loadExistingConfig(remote) }
        }
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Remote Name").font(.subheadline).fontWeight(.medium)
            TextField("e.g. mydrive", text: $remoteName)
                .textFieldStyle(.roundedBorder)
                .disabled(isEditing)
                .opacity(isEditing ? 0.6 : 1.0)
        }
    }

    private var typeSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Storage Type").font(.subheadline).fontWeight(.medium)
            if isLoadingProviders || isLoadingConfig {
                HStack {
                    ProgressView().scaleEffect(0.8)
                    Text("Loading...").font(.caption).foregroundStyle(.secondary)
                }
            } else if isEditing {
                HStack {
                    Text(providerDisplayName(selectedType))
                    Spacer()
                }
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color(nsColor: .controlBackgroundColor)))
            } else {
                Picker("Type", selection: $selectedType) {
                    Text("Select a type...").tag("")
                    ForEach(providers, id: \.self) { provider in
                        Text(providerDisplayName(provider)).tag(provider)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var parametersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
            }

            Toggle("Interactive setup (step-by-step)", isOn: $useInteractive)
                .font(.caption)

            if !useInteractive {
                Divider()
                Text("Parameters").font(.subheadline).fontWeight(.medium)
                Text("Add key-value pairs. Leave blank for OAuth or defaults.")
                    .font(.caption).foregroundStyle(.secondary)

                ForEach($parameters) { $param in
                    HStack(spacing: 8) {
                        TextField("Key", text: $param.key)
                            .textFieldStyle(.roundedBorder).frame(maxWidth: 140)
                        TextField("Value", text: $param.value)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                HStack {
                    Button {
                        parameters.append(ParamField(key: "", value: ""))
                    } label: {
                        Label("Add Parameter", systemImage: "plus.circle").font(.caption)
                    }
                    .buttonStyle(.borderless)
                    if !parameters.isEmpty {
                        Button {
                            parameters.removeAll { $0.key.isEmpty && $0.value.isEmpty }
                        } label: {
                            Label("Clear", systemImage: "trash").font(.caption)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
    }

    private func promptSection(_ prompt: RcloneConfigPrompt) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let error = prompt.error {
                Text("Error: \(error)").foregroundStyle(.red)
            }

            if let oauth = prompt.oauth, let authURL = oauth.authURL {
                VStack(alignment: .leading, spacing: 8) {
                    Text("OAuth Required").font(.subheadline).fontWeight(.medium)
                    Text("Open this URL in your browser, authorize, then paste the code below:")
                        .font(.caption).foregroundStyle(.secondary)

                    Button {
                        if let url = URL(string: authURL) {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "safari")
                            Text(authURL)
                                .lineLimit(2)
                                .font(.caption2)
                        }
                    }
                    .buttonStyle(.link)

                    TextField("Paste authorization code", text: $promptAnswer)
                        .textFieldStyle(.roundedBorder)
                }
            } else if let option = prompt.option {
                VStack(alignment: .leading, spacing: 6) {
                    Text(option.name ?? "Configuration").font(.subheadline).fontWeight(.medium)
                    if let help = option.help {
                        Text(help).font(.caption).foregroundStyle(.secondary)
                    }
                    if option.isPassword == true {
                        SecureField("Value", text: $promptAnswer)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        TextField("Value", text: $promptAnswer)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            } else {
                Text("Configuration prompt received. Enter your answer:").font(.caption)
                TextField("Answer", text: $promptAnswer).textFieldStyle(.roundedBorder)
            }

            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
            }
        }
    }

    private func loadProviders() async {
        do {
            providers = try await RcloneService.shared.listProviders()
        } catch {
            errorMessage = "Failed to load providers: \(error.localizedDescription)"
        }
        isLoadingProviders = false
    }

    private func loadExistingConfig(_ remote: RcloneRemote) async {
        isLoadingConfig = true
        remoteName = remote.name
        do {
            let config = try await RcloneService.shared.getRemote(name: remote.name)
            selectedType = config.type
            parameters = config.parameters.map { ParamField(key: $0.key, value: $0.value) }
        } catch {
            errorMessage = "Failed to load config: \(error.localizedDescription)"
        }
        isLoadingConfig = false
    }

    private func createRemote() {
        isSaving = true
        errorMessage = nil

        if useInteractive {
            createInteractive()
        } else {
            createDirect()
        }
    }

    private func createInteractive() {
        Task {
            do {
                let params = collectParameters()
                let prompt = try await RcloneService.shared.createRemoteInteractive(
                    name: remoteName, type: selectedType, parameters: params
                )
                await MainActor.run {
                    configState = prompt?.state
                    if let prompt, prompt.state != nil {
                        configPrompt = prompt
                        promptAnswer = ""
                        isSaving = false
                    } else {
                        dismiss()
                        Task { await viewModel.checkDaemon() }
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed: \(error.localizedDescription)"
                    isSaving = false
                }
            }
        }
    }

    private func submitAnswer() {
        guard let state = configState, !promptAnswer.isEmpty else { return }
        isSaving = true
        errorMessage = nil

        Task {
            do {
                let prompt = try await RcloneService.shared.continueCreateRemote(
                    name: remoteName, state: state, result: promptAnswer
                )
                await MainActor.run {
                    configState = prompt?.state
                    if let prompt, prompt.state != nil {
                        configPrompt = prompt
                        promptAnswer = ""
                        isSaving = false
                    } else {
                        dismiss()
                        Task { await viewModel.checkDaemon() }
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed: \(error.localizedDescription)"
                    isSaving = false
                }
            }
        }
    }

    private func createDirect() {
        Task {
            do {
                try await RcloneService.shared.createRemote(
                    name: remoteName, type: selectedType, parameters: collectParameters()
                )
                await MainActor.run {
                    dismiss()
                    Task { await viewModel.checkDaemon() }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed: \(error.localizedDescription)"
                    isSaving = false
                }
            }
        }
    }

    private func updateRemote() {
        isSaving = true
        errorMessage = nil
        Task {
            do {
                try await RcloneService.shared.updateRemote(name: remoteName, parameters: collectParameters())
                await MainActor.run {
                    dismiss()
                    Task { await viewModel.checkDaemon() }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed: \(error.localizedDescription)"
                    isSaving = false
                }
            }
        }
    }

    private func collectParameters() -> [String: String] {
        var params: [String: String] = [:]
        for field in parameters where !field.key.isEmpty { params[field.key] = field.value }
        return params
    }

    private func providerDisplayName(_ key: String) -> String {
        let names: [String: String] = [
            "drive": "Google Drive", "gcs": "Google Cloud Storage",
            "s3": "Amazon S3", "b2": "Backblaze B2",
            "sftp": "SSH / SFTP", "ftp": "FTP",
            "webdav": "WebDAV", "dropbox": "Dropbox",
            "onedrive": "Microsoft OneDrive", "azureblob": "Azure Blob Storage",
            "local": "Local Filesystem", "crypt": "Encrypted (Crypt)",
            "union": "Union", "cache": "Cache",
            "googlephotos": "Google Photos", "pcloud": "pCloud",
            "mega": "Mega", "box": "Box", "jottacloud": "Jottacloud",
            "opendrive": "OpenDrive", "putio": "put.io",
            "koofr": "Koofr", "yandex": "Yandex Disk", "hdfs": "HDFS", "http": "HTTP",
        ]
        return names[key] ?? key.capitalized
    }
}
