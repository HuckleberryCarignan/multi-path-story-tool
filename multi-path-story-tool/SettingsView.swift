import SwiftUI

struct SettingsView: View {
    @Bindable var vm: StoryViewModel
    @AppStorage("appearanceMode") private var appearanceMode: String = "dark"
    @AppStorage("showTooltips") private var showTooltips: Bool = true

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

                Section("Appearance") {
                    Picker("Mode", selection: $appearanceMode) {
                        Text("Dark").tag("dark")
                        Text("Light").tag("light")
                        Text("Color").tag("color")
                    }
                    .pickerStyle(.segmented)
                    Toggle("Show Tooltips", isOn: $showTooltips)
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 300)
    }
}
