import SwiftUI

struct FriendsView: View {
    @EnvironmentObject var store: AppStore
    
    @State private var selectedSegment = 0 // 0: Bạn bè, 1: Lời mời, 2: Tìm kiếm
    @State private var searchQuery = ""
    @State private var searchResults: [UserSearchResult] = []
    @State private var isSearching = false
    @State private var searchError: String? = nil
    
    @State private var loadingRequests = false
    @State private var loadingFriends = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Banner sang trọng
                KHeroHeader(icon: "person.2.fill",
                            title: "Bạn bè",
                            subtitle: "Kết bạn · Lời mời · Nhắn tin trực tiếp")
                    .padding(.horizontal)
                    .padding(.top, 8)

                // Segmented picker
                Picker("", selection: $selectedSegment) {
                    Text("Bạn bè").tag(0)
                    Text("Lời mời").tag(1)
                    Text("Tìm kiếm").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()
                
                Group {
                    if selectedSegment == 0 {
                        friendsPane
                    } else if selectedSegment == 1 {
                        requestsPane
                    } else {
                        searchPane
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Bạn bè")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ThreeDLogoText(size: 20)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await refreshData()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task {
                await refreshData()
            }
        }
    }
    
    // MARK: - Friends Pane
    private var friendsPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if loadingFriends {
                    HStack {
                        Spacer()
                        ProgressView("Đang tải danh sách...")
                        Spacer()
                    }
                    .padding(.top, 40)
                } else if store.friends.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.2.slash.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("Chưa có bạn bè")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text("Hãy qua tab 'Tìm kiếm' để kết bạn với những người khác!")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    ForEach(store.friends) { friend in
                        NavigationLink(destination: DirectMessageChatView(friend: friend)) {
                            HStack {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.title)
                                    .foregroundStyle(Theme.accent)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(friend.username)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text("Bấm để nhắn tin")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .kGlassInteractive(RoundedRectangle(cornerRadius: 16))
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Requests Pane
    private var requestsPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if loadingRequests {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding(.top, 40)
                } else {
                    let username = store.username ?? ""
                    let incomingRequests = store.friendRequests.filter { $0.receiverName.lowercased() == username.lowercased() }
                    let outgoingRequests = store.friendRequests.filter { $0.senderName.lowercased() == username.lowercased() }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Lời mời nhận được (\(incomingRequests.count))")
                            .font(.subheadline)
                            .bold()
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                        
                        if incomingRequests.isEmpty {
                            Text("Không có lời mời nào")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .kGlass(RoundedRectangle(cornerRadius: 12))
                                .padding(.horizontal)
                        } else {
                            ForEach(incomingRequests) { req in
                                HStack {
                                    Image(systemName: "person.badge.plus")
                                        .font(.headline)
                                        .foregroundStyle(Theme.purple)
                                    Text(req.senderName)
                                        .font(.headline)
                                    Spacer()
                                    Button("Từ chối") {
                                        Task { await respond(reqId: req.id, action: "decline") }
                                    }
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color(.systemGray5))
                                    .cornerRadius(8)
                                    
                                    Button("Đồng ý") {
                                        Task { await respond(reqId: req.id, action: "accept") }
                                    }
                                    .font(.caption)
                                    .bold()
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Theme.accent)
                                    .cornerRadius(8)
                                }
                                .padding()
                                .kGlass(RoundedRectangle(cornerRadius: 16))
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Outgoing requests
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Yêu cầu đã gửi (\(outgoingRequests.count))")
                            .font(.subheadline)
                            .bold()
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                            .padding(.top, 10)
                        
                        if outgoingRequests.isEmpty {
                            Text("Không có yêu cầu đang chờ")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .kGlass(RoundedRectangle(cornerRadius: 12))
                                .padding(.horizontal)
                        } else {
                            ForEach(outgoingRequests) { req in
                                HStack {
                                    Image(systemName: "paperplane.fill")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(req.receiverName)
                                        .font(.body)
                                    Spacer()
                                    Text("Đang chờ phản hồi")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                                .kGlass(RoundedRectangle(cornerRadius: 16))
                                .padding(.horizontal)
                            }
                        }
                    }
                }
            }
            .padding(.vertical)
        }
    }
    
    // MARK: - Search Pane
    private var searchPane: some View {
        VStack(spacing: 12) {
            // Search Input
            HStack {
                TextField("Nhập tên tài khoản...", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                
                if isSearching {
                    ProgressView()
                } else {
                    Button {
                        Task { await runSearch() }
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .bold()
                            .foregroundStyle(Theme.accent)
                    }
                }
            }
            .padding(12)
            .kGlass(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
            
            if let err = searchError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }
            
            ScrollView {
                VStack(spacing: 12) {
                    if searchResults.isEmpty && !searchQuery.isEmpty && !isSearching {
                        Text("Không tìm thấy kết quả phù hợp")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 40)
                    } else {
                        ForEach(searchResults) { res in
                            HStack {
                                Image(systemName: "person.fill")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                Text(res.username)
                                    .font(.headline)
                                Spacer()
                                
                                searchResultActionView(for: res)
                            }
                            .padding()
                            .kGlass(RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
        }
        .padding(.vertical)
    }
    
    @ViewBuilder
    private func searchResultActionView(for user: UserSearchResult) -> some View {
        let isFriend = store.friends.contains { $0.id == user.id }
        let incomingRequest = store.friendRequests.first { $0.senderName.lowercased() == user.username.lowercased() }
        let outgoingRequest = store.friendRequests.first { $0.receiverName.lowercased() == user.username.lowercased() }
        
        if isFriend {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text("Bạn bè").font(.caption).foregroundStyle(.secondary)
            }
        } else if let incReq = incomingRequest {
            Button("Chấp nhận") {
                Task { await respond(reqId: incReq.id, action: "accept") }
            }
            .font(.caption)
            .bold()
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Theme.accent)
            .cornerRadius(8)
        } else if outgoingRequest != nil {
            Text("Đã gửi lời mời")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Button("Thêm bạn") {
                Task { await sendRequest(friendId: user.id) }
            }
            .font(.caption)
            .bold()
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Theme.accent)
            .cornerRadius(8)
        }
    }
    
    // MARK: - Helpers & API calls
    private func refreshData() async {
        loadingFriends = true
        loadingRequests = true
        await store.refreshFriends()
        loadingFriends = false
        await store.refreshFriendRequests()
        loadingRequests = false
    }
    
    private func runSearch() async {
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSearching = true
        searchError = nil
        do {
            searchResults = try await store.api.searchUsers(query: searchQuery)
        } catch {
            searchError = error.localizedDescription
        }
        isSearching = false
    }
    
    private func sendRequest(friendId: Int) async {
        do {
            _ = try await store.api.sendFriendRequest(friendId: friendId)
            await refreshData()
        } catch {
            searchError = error.localizedDescription
        }
    }
    
    private func respond(reqId: Int, action: String) async {
        do {
            _ = try await store.api.respondToFriendRequest(requestId: reqId, action: action)
            await refreshData()
        } catch {
            searchError = error.localizedDescription
        }
    }
}
