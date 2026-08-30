import SwiftUI

struct SettingsView: View {
    @Bindable var vm: StoryViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Settings")
                .font(.headline)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            Form {
                Section("Story Canvas") {
                    Toggle("Snap to Grid", isOn: $vm.snapEnabled)

                    if vm.snapEnabled {
                        Stepper(
                            "Grid Size: \(Int(vm.gridSize)) pt",
                            value: $vm.gridSize,
                            in: 10...80,
                            step: 10
                        )
                    }

                    Toggle("Display Identifier", isOn: $vm.showCanvasIdentifier)
                    Toggle("Add New Story Entry on Command Key+ Click", isOn: $vm.addNodeOnCommandClick)
                    Toggle("Display Zoom-Out Mini-Map", isOn: $vm.showZoomOut)
                }

                Section("Story Entry") {
                    Toggle("Display Identifier", isOn: $vm.showIdentifier)
                    Toggle("Left/Right Justified on Canvas", isOn: $vm.rightJustifiedOnCanvas)
                }

                Section("Other") {
                    Text("No other settings yet")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 300)
    }
}
