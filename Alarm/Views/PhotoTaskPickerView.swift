//
//  PhotoTaskPickerView.swift
//  Alarm
//
//  Category-tabbed multi-select picker for the Photo mission. Mirrors the
//  "Select items" layout from the design reference: category chips at the top,
//  a scrollable grid of emoji tiles with checkboxes, and an "All" toggle.
//  Offers a "Test detection" flow that snaps a photo and runs it through the
//  same backend used at alarm time, so the user can verify their choices will
//  actually be recognised.
//

import SwiftUI

struct PhotoTaskPickerView: View {
    /// Initial selection — nil / empty means "all selected".
    let initial: [String]?
    /// Called with the final selection (or nil if user wants "all").
    let onDone: ([String]?) -> Void
    let onCancel: () -> Void

    @State private var selected: Set<String>
    @State private var activeCategory: PhotoTaskCategory = .bathroom
    @State private var showTestSheet = false

    init(initial: [String]?,
         onDone: @escaping ([String]?) -> Void,
         onCancel: @escaping () -> Void) {
        self.initial = initial
        self.onDone = onDone
        self.onCancel = onCancel
        let ids = initial.map(Set.init) ?? Set(TaskCatalog.all.map(\.id))
        _selected = State(initialValue: ids)
    }

    private var allSelected: Bool {
        selected.count == TaskCatalog.totalCount
    }

    var body: some View {
        ZStack {
            OB.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                navBar
                categoryChips
                    .padding(.top, 14)

                allToggleRow
                    .padding(.horizontal, 20)
                    .padding(.top, 14)

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        ForEach(TaskCatalog.byCategory, id: \.category) { group in
                            section(for: group.category, tasks: group.tasks)
                                .id(group.category)
                        }
                        Color.clear.frame(height: 120)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                }
            }

            testButton
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .sheet(isPresented: $showTestSheet) {
            PhotoTaskTestSheet(
                candidates: selectedTasksForTest,
                onClose: { showTestSheet = false }
            )
            .presentationDetents([.large])
            .presentationBackground(OB.bg)
        }
    }

    // MARK: - Nav bar

    private var navBar: some View {
        HStack {
            Button("Cancel", action: onCancel)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(OB.ink2)
            Spacer()
            VStack(spacing: 2) {
                Text("Select items")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(OB.ink)
                Text("\(selected.count) of \(TaskCatalog.totalCount) selected")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(OB.ink3)
            }
            Spacer()
            Button("OK") {
                let normalized: [String]? = allSelected
                    ? nil
                    : TaskCatalog.all.map(\.id).filter { selected.contains($0) }
                onDone(normalized)
            }
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(selected.isEmpty ? OB.ink3 : OB.accent)
            .disabled(selected.isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
    }

    // MARK: - Category chips

    private var categoryChips: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PhotoTaskCategory.allCases, id: \.self) { cat in
                        chip(for: cat)
                            .id(cat)
                    }
                }
                .padding(.horizontal, 20)
            }
            .onChange(of: activeCategory) { _, new in
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(new, anchor: .center)
                }
            }
        }
    }

    private func chip(for cat: PhotoTaskCategory) -> some View {
        let active = activeCategory == cat
        return Button {
            activeCategory = cat
        } label: {
            Text(cat.rawValue)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(active ? OB.bg : OB.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    active ? OB.ink : OB.card,
                    in: Capsule()
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - All toggle

    private var allToggleRow: some View {
        Button {
            if allSelected {
                selected.removeAll()
            } else {
                selected = Set(TaskCatalog.all.map(\.id))
            }
        } label: {
            HStack(spacing: 10) {
                checkbox(on: allSelected)
                Text("All (\(TaskCatalog.totalCount))")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(OB.ink)
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Category section

    private func section(for category: PhotoTaskCategory, tasks: [AlarmTask]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(category.rawValue)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(OB.ink)

            let cols = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
            LazyVGrid(columns: cols, spacing: 10) {
                ForEach(tasks) { task in
                    tile(for: task)
                        .onTapGesture { toggle(task.id) }
                }
            }
        }
    }

    private func tile(for task: AlarmTask) -> some View {
        let on = selected.contains(task.id)
        return ZStack(alignment: .topLeading) {
            VStack(spacing: 10) {
                Text(task.emoji)
                    .font(.system(size: 42))
                    .frame(maxWidth: .infinity)
                    .frame(height: 72)
                Text(task.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(OB.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(OB.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(on ? OB.accent : Color.clear, lineWidth: 2)
            )

            checkbox(on: on)
                .padding(8)
        }
        .contentShape(Rectangle())
    }

    private func checkbox(on: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(on ? OB.accent : OB.bg)
                .frame(width: 20, height: 20)
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(on ? OB.accent : OB.ink3.opacity(0.4), lineWidth: 1.5)
                .frame(width: 20, height: 20)
            if on {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Test button

    private var testButton: some View {
        Button {
            showTestSheet = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 15, weight: .semibold))
                Text("Test detection")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(OB.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: OB.accent.opacity(0.3), radius: 10, y: 4)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(selected.isEmpty)
        .opacity(selected.isEmpty ? 0.5 : 1)
    }

    private var selectedTasksForTest: [AlarmTask] {
        TaskCatalog.all.filter { selected.contains($0.id) }
    }

    // MARK: - Mutators

    private func toggle(_ id: String) {
        if selected.contains(id) { selected.remove(id) }
        else { selected.insert(id) }
    }
}

#Preview {
    PhotoTaskPickerView(
        initial: ["laptop", "coffee", "sink"],
        onDone: { print("done", $0 ?? "all") },
        onCancel: { print("cancel") }
    )
}
