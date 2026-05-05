import SwiftUI
#if canImport(UIKit)
import UIKit
#endif


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
        ZStack {
            AppBackgroundView()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("添加服务器")
                            .font(.system(size: 34, weight: .black, design: .rounded))
                        Text("把 NodeGet Server 地址和 Token 存到本机，后续就可以直接查看监控仪表盘。")
                            .font(.subheadline)
                            .foregroundStyle(Color.ngMuted)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        SectionCaption(text: "连接信息")

                        VStack(spacing: 14) {
                            AppTextField(title: "名称", placeholder: "可留空，默认取域名", text: $name)
                            AppTextField(title: "服务器地址", placeholder: "https://example.com/", text: $serverURL, keyboard: .URL)
                            AppSecureField(title: "Token", placeholder: "例如 key:secret", text: $token)
                        }
                        .padding(18)
                        .ngSoftCard()
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Button {
                            Task { await testConnection() }
                        } label: {
                            HStack {
                                Spacer()
                                if isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Label("测试 hello 连接", systemImage: "bolt.horizontal.circle.fill")
                                        .font(.headline)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 16)
                            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.ngPrimary))
                            .foregroundStyle(.white)
                        }
                        .disabled(isLoading || normalizedURL == nil)
                        .opacity((isLoading || normalizedURL == nil) ? 0.6 : 1)

                        Button {
                            saveServer()
                        } label: {
                            HStack {
                                Spacer()
                                Label("保存服务器", systemImage: "square.and.arrow.down.fill")
                                    .font(.headline)
                                Spacer()
                            }
                            .padding(.vertical, 16)
                            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.black))
                            .foregroundStyle(.white)
                        }
                        .disabled(!canSave)
                        .opacity(canSave ? 1 : 0.6)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        SectionCaption(text: "测试结果")
                        Text(resultText)
                            .font(.subheadline)
                            .foregroundStyle(resultText.contains("成功") ? Color.ngPrimary : Color.ngText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(18)
                            .ngSoftCard()
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        SectionCaption(text: "说明")
                        Text("hello 接口不使用 Token；保存后，Agent 列表会使用 Token 调用 nodeget-server_list_all_agent_uuid。Token 会保存到 iOS Keychain。")
                            .font(.subheadline)
                            .foregroundStyle(Color.ngMuted)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(18)
                            .ngSoftCard()
                    }
                }
                .padding(20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
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
            _ = try serverStore.add(name: name, baseURL: url, token: token)
            dismiss()
        } catch {
            resultText = "保存失败：\(error.localizedDescription)"
        }
    }
}

struct AppTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.ngMuted)
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(keyboard)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.ngBackground))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.ngBorder, lineWidth: 1))
        }
    }
}

struct AppSecureField: View {
    let title: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.ngMuted)
            SecureField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.ngBackground))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.ngBorder, lineWidth: 1))
        }
    }
}
