import SwiftUI

struct PracticeCalendarView: View {
    @Bindable var authService: AuthService

    @State private var calendarDays: [CalendarDayDTO] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var currentMonth = Date()

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)

    private var practiceDates: Set<String> {
        Set(calendarDays.map { $0.date })
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                monthHeader
                weekdayHeader
                calendarGrid

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.vertical, 12)
                        .padding(.horizontal)
                }
            }

            if isLoading {
                ProgressView()
                    .controlSize(.large)
                    .padding(24)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .navigationTitle("Practice Calendar")
        .task {
            await loadCalendar()
        }
        .refreshable {
            await loadCalendar()
        }
    }

    // MARK: - Month Header

    private var monthHeader: some View {
        HStack {
            Button {
                currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
            } label: {
                Image(systemName: "chevron.left")
            }

            Spacer()

            Text(monthYearString(from: currentMonth))
                .font(.title2)
                .fontWeight(.semibold)

            Spacer()

            Button {
                currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
            } label: {
                Image(systemName: "chevron.right")
            }
        }
        .padding()
    }

    // MARK: - Weekday Header

    private var weekdayHeader: some View {
        HStack {
            ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { day in
                Text(day)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    // MARK: - Calendar Grid

    private var calendarGrid: some View {
        let days = daysInMonth()

        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(days, id: \.self) { date in
                if let date {
                    DayCell(
                        date: date,
                        hasPractice: hasPractice(on: date),
                        isToday: calendar.isDateInToday(date)
                    )
                } else {
                    Color.clear
                        .frame(height: 44)
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Data Loading

    private func loadCalendar() async {
        guard let token = getToken() else {
            errorMessage = "Not authenticated"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let apiClient = ServiceProvider.shared.apiClient
            let completions = try await apiClient.getPracticeCompletions(token: token)
            calendarDays = buildCalendarDays(from: completions)
        } catch {
            errorMessage = "Failed to load calendar: \(error.localizedDescription)"
        }

        isLoading = false
    }

    private func getToken() -> String? {
        guard let tokenData = KeychainHelper.load(key: "jwt_token"),
              let token = String(data: tokenData, encoding: .utf8) else {
            return nil
        }
        return token
    }

    // MARK: - Calendar Helpers

    private func daysInMonth() -> [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: currentMonth),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth)) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: firstDay)
        let leadingEmptyDays = firstWeekday - 1

        var days: [Date?] = Array(repeating: nil, count: leadingEmptyDays)

        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }

        return days
    }

    private func hasPractice(on date: Date) -> Bool {
        practiceDates.contains(CalendarDayDTO.dateString(from: date))
    }

    private func buildCalendarDays(from completions: [SessionCompletionDTO]) -> [CalendarDayDTO] {
        var counts: [String: Int] = [:]
        for completion in completions {
            let dateString = CalendarDayDTO.dateString(from: completion.completedAt)
            counts[dateString, default: 0] += 1
        }

        return counts
            .sorted { $0.key < $1.key }
            .map { CalendarDayDTO(date: $0.key, sessionCount: $0.value) }
    }

    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Day Cell

private struct DayCell: View {
    let date: Date
    let hasPractice: Bool
    let isToday: Bool

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 2) {
            Text("\(calendar.component(.day, from: date))")
                .font(.body)
                .fontWeight(isToday ? .bold : .regular)
                .foregroundStyle(isToday ? .blue : .primary)

            if hasPractice {
                Image(systemName: "star.fill")
                    .font(.caption2)
                    .foregroundStyle(.yellow)
            }
        }
        .frame(height: 44)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isToday ? Color.blue.opacity(0.1) : Color.clear)
        )
    }
}

#Preview {
    NavigationStack {
        PracticeCalendarView(authService: AuthService())
    }
}
