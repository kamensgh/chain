import SwiftUI
import PhotosUI
import SwiftData

struct ScreenshotPickerView: View {
    let habit: Habit

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var selectedItem: PhotosPickerItem?
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.accentColor)

                VStack(spacing: 8) {
                    Text("Add Screenshot")
                        .font(.title2.bold())
                    Text("Submit a photo as proof you completed \"\(habit.name)\"")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                    Label("Choose from Photos", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                }

                if isSaving {
                    ProgressView("Saving…")
                }
            }
            .padding(28)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onChange(of: selectedItem) { _, item in
            guard let item else { return }
            isSaving = true
            Task { @MainActor in
                await saveScreenshot(from: item)
                isSaving = false
            }
        }
    }

    @MainActor
    private func saveScreenshot(from item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }

        let screenshotsDir = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("screenshots")
        try? FileManager.default.createDirectory(at: screenshotsDir, withIntermediateDirectories: true)

        let filename = "\(UUID().uuidString).jpg"
        let fileURL = screenshotsDir.appendingPathComponent(filename)
        guard (try? data.write(to: fileURL)) != nil else { return }

        let period = HabitScheduler.periodStart(for: habit.frequency, on: Date())
        if let existing = habit.entries.first(where: { $0.periodStart == period }) {
            existing.status = .verified
            existing.verifMethod = .screenshot
            existing.screenshotPath = fileURL.path
            existing.sourceLabel = "Screenshot"
            existing.verifiedAt = Date()
        } else {
            let entry = HabitEntry(habit: habit, periodStart: period)
            entry.status = .verified
            entry.verifMethod = .screenshot
            entry.screenshotPath = fileURL.path
            entry.sourceLabel = "Screenshot"
            entry.verifiedAt = Date()
            context.insert(entry)
        }
        try? context.save()
        dismiss()
    }
}
