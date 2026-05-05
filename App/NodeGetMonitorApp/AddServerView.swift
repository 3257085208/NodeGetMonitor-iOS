import SwiftUI

struct AddServerView: View {
    @State private var serverURL = ""
    @State private var token = ""
    @State private var resultText = "尚未测试"
    @State private var isLoading = false

    var body: some View {
        Form {
            Section("连接信息") {
                TextField("https://example.com/", text: $serverURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()

                SecureField("Token，hello 接口暂时不会使用", text: $token)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section {
                Button {
                    Task {
                        await testConnection()
                    }
                } label: {
                    if isLoading {
                        HStack {
                            ProgressView()
                            Text("测试中...")
                        }
                    } else {
                        Text("测试连接")
                    }
                }
                .disabled(isLoading)
            }

            Section("结果") {
                Text(resultText)
                    .font(.body)
            }

            Section("说明") {
                Text("当前版本只测试 nodeget-server_hello。下一版会加入服务器保存、Keychain Token 存储、Agent 列表和监控数据。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("添加服务器")
    }

    @MainActor
    private func testConnection() async {
        guard let url = URL(string: serverURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            resultText = "URL 格式不正确"
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let client = NodeGetClient(baseURL: url)
            let message = try await client.hello()
            resultText = "连接成功：\(message)"
        } catch {
            resultText = "连接失败：\(error.localizedDescription)"
        }
    }
}
