import SwiftUI

struct YearOverviewSheet: View {
    @Binding var selectedDate: Date
    @Environment(\.dismiss) private var dismiss

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)

    private var currentYear: Int {
        calendar.component(.year, from: selectedDate)
    }

    @State private var displayedYear: Int

    init(selectedDate: Binding<Date>) {
        self._selectedDate = selectedDate
        self._displayedYear = State(initialValue: Calendar.current.component(.year, from: selectedDate.wrappedValue))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Year selector
                HStack {
                    Button(action: { displayedYear -= 1 }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.white)
                            .padding(8)
                    }

                    Spacer()

                    Text(String(displayedYear))
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Spacer()

                    Button(action: { displayedYear += 1 }) {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.white)
                            .padding(8)
                    }
                }
                .padding(.horizontal)

                // Month grid
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(1...12, id: \.self) { month in
                        MonthCard(
                            month: month,
                            year: displayedYear,
                            isSelected: isSelectedMonth(month),
                            isCurrentMonth: isCurrentMonth(month)
                        )
                        .onTapGesture {
                            selectMonth(month)
                        }
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top)
            .background(Color.black)
            .navigationTitle("Select Month")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func isSelectedMonth(_ month: Int) -> Bool {
        let selectedMonth = calendar.component(.month, from: selectedDate)
        let selectedYear = calendar.component(.year, from: selectedDate)
        return month == selectedMonth && displayedYear == selectedYear
    }

    private func isCurrentMonth(_ month: Int) -> Bool {
        let currentMonth = calendar.component(.month, from: Date())
        let currentYear = calendar.component(.year, from: Date())
        return month == currentMonth && displayedYear == currentYear
    }

    private func selectMonth(_ month: Int) {
        var components = DateComponents()
        components.year = displayedYear
        components.month = month
        components.day = 1

        if let newDate = calendar.date(from: components) {
            selectedDate = newDate
            dismiss()
        }
    }
}

struct MonthCard: View {
    let month: Int
    let year: Int
    let isSelected: Bool
    let isCurrentMonth: Bool

    private let calendar = Calendar.current

    private var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        var components = DateComponents()
        components.month = month
        if let date = calendar.date(from: components) {
            return formatter.string(from: date)
        }
        return ""
    }

    private var isFutureMonth: Bool {
        let currentYear = calendar.component(.year, from: Date())
        let currentMonth = calendar.component(.month, from: Date())

        if year > currentYear {
            return true
        } else if year == currentYear && month > currentMonth {
            return true
        }
        return false
    }

    var body: some View {
        VStack(spacing: 8) {
            Text(monthName)
                .font(.headline)
                .fontWeight(.semibold)

            // Mini calendar preview
            MiniMonthView(month: month, year: year)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.purple : Color.clear, lineWidth: 2)
                )
        )
        .opacity(isFutureMonth ? 0.5 : 1.0)
    }

    private var backgroundColor: Color {
        if isCurrentMonth {
            return Color.purple.opacity(0.3)
        }
        return Color(white: 0.15)
    }
}

struct MiniMonthView: View {
    let month: Int
    let year: Int

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 1), count: 7)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(daysInMonth(), id: \.self) { day in
                if let day = day {
                    Text("\(day)")
                        .font(.system(size: 8))
                        .foregroundColor(.gray)
                } else {
                    Text("")
                        .font(.system(size: 8))
                }
            }
        }
    }

    private func daysInMonth() -> [Int?] {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1

        guard let startOfMonth = calendar.date(from: components) else { return [] }

        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        let daysInMonth = calendar.range(of: .day, in: .month, for: startOfMonth)?.count ?? 0

        var days: [Int?] = []

        // Empty cells before first day
        for _ in 1..<firstWeekday {
            days.append(nil)
        }

        // Days of month
        for day in 1...daysInMonth {
            days.append(day)
        }

        return days
    }
}
