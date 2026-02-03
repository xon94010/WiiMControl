import SwiftUI

struct EQRowView: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 14))
                .foregroundColor(isSelected ? .white : .white.opacity(0.5))
                .frame(width: 24)

            Text(name)
                .font(.caption)
                .foregroundColor(isSelected ? .white : .white.opacity(0.8))
                .lineLimit(1)

            Spacer()

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(isSelected ? Color.gray.opacity(0.55) : Color.black.opacity(0.8))
        .contentShape(Rectangle())
        .onTapGesture {
            action()
        }
    }
}
