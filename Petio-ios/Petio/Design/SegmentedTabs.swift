//
//  SegmentedTabs.swift
//  Petio
//
//  Сегментированные табы и горизонтальные чипы.
//

import SwiftUI

struct SegmentedTabs<T: Hashable>: View {
    let items: [(key: T, label: String)]
    @Binding var selection: T

    var body: some View {
        HStack(spacing: 4) {
            ForEach(items, id: \.key) { item in
                Button {
                    selection = item.key
                } label: {
                    Text(item.label)
                        .font(.system(size: 14))
                        .foregroundColor(selection == item.key ? PetCareTheme.primary : PetCareTheme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .background {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(selection == item.key ? Color.white : Color.clear)
                }
                .shadow(color: selection == item.key ? Color.black.opacity(0.06) : .clear, radius: 2, y: 1)
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(PetCareTheme.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct ChipGroup: View {
    let haveAdditionalPadding: Bool
    let labels: [String]
    @Binding var selection: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(labels, id: \.self) { label in
                    Button {
                        selection = label
                    } label: {
                        Text(label)
                            .font(.system(size: 12))
                            .foregroundColor(selection == label ? .white : PetCareTheme.primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                    }
                    .background(
                        Capsule()
                            .fill(selection == label ? PetCareTheme.primary : PetCareTheme.secondary)
                    )
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, haveAdditionalPadding ? 20 : 4)
        }
    }
}
