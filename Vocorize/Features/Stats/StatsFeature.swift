import ComposableArchitecture
import Dependencies
import SwiftUI

// MARK: - Models

struct StatsData: Codable, Equatable {
    var totalSpeakingTime: TimeInterval = 0
    var totalWordsCaptured: Int = 0
    var totalSessions: Int = 0
    var dailyStats: [DailyStats] = []
    
    var totalTypingTime: TimeInterval {
        // Estimate typing time based on average typing speed (40 WPM)
        return Double(totalWordsCaptured) / 40.0 * 60.0
    }
    
    var timeSaved: TimeInterval {
        return totalTypingTime - totalSpeakingTime
    }
    
    var averageWordsPerMinute: Double {
        guard totalSpeakingTime > 0 else { return 0 }
        return Double(totalWordsCaptured) / (totalSpeakingTime / 60.0)
    }
    
    var averageWordsPerSession: Double {
        guard totalSessions > 0 else { return 0 }
        return Double(totalWordsCaptured) / Double(totalSessions)
    }
    
    var speedMultiplier: Double {
        guard totalSpeakingTime > 0 else { return 0 }
        let estimatedTypingTime = Double(totalWordsCaptured) / 40.0 * 60.0
        return estimatedTypingTime / totalSpeakingTime
    }
}

struct DailyStats: Codable, Equatable, Identifiable {
    var id = UUID()
    let date: Date
    var speakingTime: TimeInterval
    var wordsCaptured: Int
    var sessions: Int
    
    init(date: Date, speakingTime: TimeInterval = 0, wordsCaptured: Int = 0, sessions: Int = 0) {
        self.date = date
        self.speakingTime = speakingTime
        self.wordsCaptured = wordsCaptured
        self.sessions = sessions
    }
}

extension SharedReaderKey
    where Self == FileStorageKey<StatsData>.Default
{
    static var statsData: Self {
        Self[
            .fileStorage(URL.documentsDirectory.appending(component: "stats_data.json")),
            default: .init()
        ]
    }
}

// MARK: - Stats Feature

@Reducer
struct StatsFeature {
    @ObservableState
    struct State: Equatable {
        @Shared(.statsData) var statsData: StatsData
        @Shared(.transcriptionHistory) var transcriptionHistory: TranscriptionHistory
        
        var isLoading: Bool = false
        var selectedTimeRange: TimeRange = .thirtyDays
        
        enum TimeRange: String, CaseIterable {
            case sevenDays = "7 Days"
            case thirtyDays = "30 Days"
            case ninetyDays = "90 Days"
            case allTime = "All Time"
        }
    }
    
    enum Action {
        case onAppear
        case refreshStats
        case setTimeRange(State.TimeRange)
        case statsUpdated(StatsData)
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .send(.refreshStats)
                
            case .refreshStats:
                state.isLoading = true
                let transcriptionHistory = state.transcriptionHistory
                return .run { send in
                    let updatedStats = await calculateStats(from: transcriptionHistory)
                    await send(.statsUpdated(updatedStats))
                }
                
            case .setTimeRange(let range):
                state.selectedTimeRange = range
                return .none
                
            case .statsUpdated(let updatedStats):
                state.isLoading = false
                state.$statsData.withLock { statsData in
                    statsData = updatedStats
                }
                return .none
            }
        }
    }
    
    private func calculateStats(from history: TranscriptionHistory) async -> StatsData {
        var stats = StatsData()
        var dailyStatsDict: [String: DailyStats] = [:]
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        for transcript in history.history {
            // Calculate words (rough estimate)
            let words = transcript.text.split(separator: " ").count
            
            // Update totals
            stats.totalSpeakingTime += transcript.duration
            stats.totalWordsCaptured += words
            stats.totalSessions += 1
            
            // Update daily stats
            let dateKey = dateFormatter.string(from: transcript.timestamp)
            if var dailyStat = dailyStatsDict[dateKey] {
                dailyStat.speakingTime += transcript.duration
                dailyStat.wordsCaptured += words
                dailyStat.sessions += 1
                dailyStatsDict[dateKey] = dailyStat
            } else {
                let startOfDay = Calendar.current.startOfDay(for: transcript.timestamp)
                dailyStatsDict[dateKey] = DailyStats(
                    date: startOfDay,
                    speakingTime: transcript.duration,
                    wordsCaptured: words,
                    sessions: 1
                )
            }
        }
        
        // Convert daily stats to array and sort by date
        stats.dailyStats = Array(dailyStatsDict.values).sorted { $0.date < $1.date }
        
        return stats
    }
}

// MARK: - Stats View

struct StatsView: View {
    @Bindable var store: StoreOf<StatsFeature>
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header with speed multiplier
                speedMultiplierHeader
                
                // Time metrics cards
                timeMetricsSection
                
                // Statistics grid
                statisticsGrid
                
                // 30-day trend
                trendChart
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
        .background(Color.gray.opacity(0.02))
        .navigationTitle("Stats")
        .onAppear {
            store.send(.onAppear)
        }
        .refreshable {
            store.send(.refreshStats)
        }
    }
    
    private var speedMultiplierHeader: some View {
        VStack(spacing: 8) {
            Text("You are")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Text("\(String(format: "%.1f", store.statsData.speedMultiplier))x Faster")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.green)
            
            Text("with Vocorize")
                .font(.title2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var timeMetricsSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                // Speaking Time Card
                VStack(spacing: 8) {
                    Image(systemName: "mic.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                    
                    Text("\(Int(store.statsData.totalSpeakingTime))s")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("SPEAKING TIME")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
                
                // Typing Time Card
                VStack(spacing: 8) {
                    Image(systemName: "keyboard")
                        .font(.title2)
                        .foregroundColor(.orange)
                    
                    Text("\(Int(store.statsData.totalTypingTime))s")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("TYPING TIME")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
            }
            
            // Time Saved
            VStack(spacing: 4) {
                Text("TIME SAVED")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("\(Int(store.statsData.timeSaved))s")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(store.statsData.timeSaved >= 0 ? .blue : .red)
            }
        }
    }
    
    private var statisticsGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
            // Words Captured
            StatCard(
                icon: "doc.text",
                title: "Words Captured",
                value: "\(store.statsData.totalWordsCaptured)",
                color: .blue
            )
            
            // Voice-to-Text Sessions
            StatCard(
                icon: "mic",
                title: "Voice-to-Text Sessions",
                value: "\(store.statsData.totalSessions)",
                color: .purple
            )
            
            // Average Words/Minute
            StatCard(
                icon: "clock",
                title: "Average Words/Minute",
                value: String(format: "%.1f", store.statsData.averageWordsPerMinute),
                color: .green
            )
            
            // Words/Session
            StatCard(
                icon: "chart.bar",
                title: "Words/Session",
                value: String(format: "%.1f", store.statsData.averageWordsPerSession),
                color: .orange
            )
        }
    }
    
    private var trendChart: some View {
        VStack(alignment: .leading, spacing: 20) {
            trendChartHeader
            trendChartContent
        }
        .padding(24)
        .background(trendChartBackground)
    }
    
    private var trendChartHeader: some View {
        HStack {
            Text("30-Day Vocorize Trend")
                .font(.title2)
                .fontWeight(.bold)
            
            Spacer()
            
            Text("Sessions per day")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
        }
    }
    
    private var trendChartContent: some View {
        Group {
            if store.statsData.dailyStats.isEmpty {
                emptyChartView
            } else {
                chartWithData
            }
        }
    }
    
    private var emptyChartView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundColor(.blue.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("No data yet")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("Start using Vocorize to see your productivity trends")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .padding(.vertical, 40)
        .background(emptyChartBackground)
    }
    
    private var emptyChartBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.blue.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.blue.opacity(0.1), lineWidth: 1)
            )
    }
    
    private var chartWithData: some View {
        VStack(spacing: 16) {
            chartBars
            chartLegend
        }
        .padding(.vertical, 20)
        .background(chartBackground)
    }
    
    private var chartBars: some View {
        VStack(spacing: 12) {
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(store.statsData.dailyStats.suffix(30)) { dailyStat in
                    chartBar(for: dailyStat)
                }
            }
            .frame(height: 160)
            .padding(.horizontal, 8)
            
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1)
                .padding(.horizontal, 8)
        }
    }
    
    private func chartBar(for dailyStat: DailyStats) -> some View {
        VStack(spacing: 8) {
            Text("\(dailyStat.sessions)")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.blue)
                .opacity(dailyStat.sessions > 0 ? 1.0 : 0.3)
            
            RoundedRectangle(cornerRadius: 4)
                .fill(chartBarGradient)
                .frame(
                    width: max(8, 400 / 35),
                    height: max(4, CGFloat(dailyStat.sessions) * 15)
                )
                .shadow(color: .blue.opacity(0.2), radius: 2, x: 0, y: 1)
            
            Text(formatDate(dailyStat.date))
                .font(.caption2)
                .foregroundColor(.secondary)
                .rotationEffect(.degrees(-45))
                .offset(y: 4)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var chartBarGradient: LinearGradient {
        LinearGradient(
            colors: [Color.blue.opacity(0.8), Color.blue],
            startPoint: .bottom,
            endPoint: .top
        )
    }
    
    private var chartLegend: some View {
        HStack {
            Circle()
                .fill(Color.blue)
                .frame(width: 8, height: 8)
            
            Text("Daily sessions")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text("Last 30 days")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
    }
    
    private var chartBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.gray.opacity(0.05))
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    private var trendChartBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.gray.opacity(0.03))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.gray.opacity(0.1), lineWidth: 1)
            )
    }
}

struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 16) {
            // Icon with background
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 48, height: 48)
                
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
            }
            
            // Value
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            // Title
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.05))
                .shadow(color: color.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.1), lineWidth: 1)
        )
    }
}

#Preview {
    StatsView(store: Store(initialState: StatsFeature.State()) {
        StatsFeature()
    })
}
