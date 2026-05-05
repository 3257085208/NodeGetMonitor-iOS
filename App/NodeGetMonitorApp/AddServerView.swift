import SwiftUI

struct AddServerView: View {
    @EnvironmentObject private var serverStore: ServerProfileStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var serverURL = ""
    @State private var token = ""
    @State private var resultText = "尚未测试"
    @State private var isLoading = false
    @State private var testedURL: URL?

    private var normalizedURL: URL? {
        URLNormalizer.normalize(serverURL)
    }

    private var canSave: Bool {
        normalizedURL != nil && !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Form {
            Section("连接信息") {
                TextField("名称，可留空", text: $name)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                TextField("https://example.com/", text: $serverURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()

                SecureField("Token，例如 key:secret", text: $token)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section {
                Button {
                    Task { await testConnection() }
                } label: {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text("测试 hello 连接")
                    }
                }
                .disabled(isLoading || normalizedURL == nil)

                Button("保存服务器") {
                    saveServer()
                }
                .disabled(!canSave)
            }

            Section("结果") {
                Text(resultText)
            }

            Section("说明") {
                Text("hello 接口不使用 Token；保存服务器后，Agent 列表会使用 Token 调用 nodeget-server_list_all_agent_uuid。Token 会保存到 iOS Keychain。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("添加服务器")
        .onChange(of: serverURL) { _, _ in
            testedURL = nil
        }
    }

    private func testConnection() async {
        guard let url = normalizedURL else {
            resultText = "URL 格式不正确"
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let client = NodeGetClient(baseURL: url)
            let message = try await client.hello()
            testedURL = url
            resultText = "连接成功：\(message)"
        } catch {
            resultText = "连接失败：\(error.localizedDescription)"
        }
    }

    private func saveServer() {
        guard let url = normalizedURL else {
            resultText = "URL 格式不正确"
            return
        }

        do {
            _ = try serverStore.add(
                name: name,
                baseURL: url,
                token: token
            )
            dismiss()
        } catch {
            resultText = "保存失败：\(error.localizedDescription)"
        }
    }
}
