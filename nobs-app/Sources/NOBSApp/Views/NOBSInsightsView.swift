import SwiftUI
import Charts
import NOBSCore
import NOBSDatabase

struct NOBSInsightsView: View {
    @State private var taskData: [DayStat] = []
    @State private var memoryData: [WeekStat] = []
    @State private var totalTasks = 0
    @State private var totalMemories = 0
    private let context: DataContext = NOBSDatabase.shared.isPersonalModeEnabled ? .personal : .work

    var body: some View {
        NavigationStack {
            List {
                // Summary stats
                Section {
                    HStack(spacing: 0) {
                        StatTile(
                            value: "\(totalTasks)",
                            label: "Pending Tasks",
                            icon: "checklist",
                            color: .nobsAccent
                        )
                        Divider()
                        StatTile(
                            value: "\(totalMemories)",
                            label: "Memories",
                            icon: "brain.head.profile",
                            color: .nobsGreen
                        )
                    }
                    .frame(maxWidth: .infinity)
                }
                .listRowBackground(Color.nobsCard)
                .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))

                // Tasks chart
                Section {
                    if taskData.isEmpty {
                        Text("No task data yet.")
                            .font(NOBSFont.body())
                            .foregroundStyle(Color.nobsSecondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, Spacing.md)
                    } else {
                        Chart(taskData) { item in
                            BarMark(
                                x: .value("Day", item.label),
                                y: .value("Tasks", item.count)
                            )
                            .foregroundStyle(Color.nobsAccent.gradient)
                            .cornerRadius(4)
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) {
                                AxisGridLine()
                                AxisValueLabel()
                            }
                        }
                        .chartXAxis {
                            AxisMarks { _ in AxisValueLabel() }
                        }
                        .frame(height: 150)
                        .padding(.vertical, Spacing.sm)
                    }
                } header: {
                    Text("Tasks Created — Last 7 Days").sectionOverline()
                }
                .listRowBackground(Color.nobsCard)

                // Memories chart
                Section {
                    if memoryData.isEmpty {
                        Text("No memory data yet.")
                            .font(NOBSFont.body())
                            .foregroundStyle(Color.nobsSecondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, Spacing.md)
                    } else {
                        Chart(memoryData) { item in
                            AreaMark(
                                x: .value("Week", item.label),
                                y: .value("Memories", item.count)
                            )
                            .foregroundStyle(Color.nobsGreen.opacity(0.2).gradient)
                            LineMark(
                                x: .value("Week", item.label),
                                y: .value("Memories", item.count)
                            )
                            .foregroundStyle(Color.nobsGreen)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            PointMark(
                                x: .value("Week", item.label),
                                y: .value("Memories", item.count)
                            )
                            .foregroundStyle(Color.nobsGreen)
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) {
                                AxisGridLine()
                                AxisValueLabel()
                            }
                        }
                        .chartXAxis {
                            AxisMarks { _ in AxisValueLabel() }
                        }
                        .frame(height: 150)
                        .padding(.vertical, Spacing.sm)
                    }
                } header: {
                    Text("Memories Saved — Last 4 Weeks").sectionOverline()
                }
                .listRowBackground(Color.nobsCard)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.nobsBg)
            .navigationTitle("Insights")
            .task { loadData() }
        }
    }

    private func loadData() {
        do {
            let calendar = Calendar.current
            let today = Date()

            let taskRepo = TaskRepository(context: context)
            let pendingTasks = try taskRepo.fetchPending()
            totalTasks = pendingTasks.count

            taskData = (0..<7).reversed().compactMap { offset -> DayStat? in
                guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
                let count = pendingTasks.filter { calendar.isDate($0.createdAt, inSameDayAs: day) }.count
                let label = offset == 0 ? "Today" : day.formatted(.dateTime.weekday(.abbreviated))
                return DayStat(label: label, count: count)
            }

            let memRepo = MemoryRepository(context: context)
            let allMemories = try memRepo.fetchAll()
            totalMemories = allMemories.count

            memoryData = (0..<4).reversed().compactMap { offset -> WeekStat? in
                guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -offset, to: today),
                      let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else { return nil }
                let count = allMemories.filter { $0.createdAt >= weekStart && $0.createdAt < weekEnd }.count
                let label = offset == 0 ? "This wk" : "W-\(offset)"
                return WeekStat(label: label, count: count)
            }
        } catch {
            print("NOBSInsightsView: failed to load data — \(error)")
        }
    }
}

// MARK: - Data Models

struct DayStat: Identifiable {
    let id = UUID()
    let label: String
    let count: Int
}

struct WeekStat: Identifiable {
    let id = UUID()
    let label: String
    let count: Int
}

// MARK: - Stat Tile

private struct StatTile: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(color)
            Text(value)
                .font(NOBSFont.title1())
                .foregroundStyle(Color.nobsPrimary)
            Text(label)
                .font(NOBSFont.caption())
                .foregroundStyle(Color.nobsSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.md)
    }
}

#Preview {
    NOBSInsightsView()
}
