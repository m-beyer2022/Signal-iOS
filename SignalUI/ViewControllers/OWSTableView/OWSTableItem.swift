//
// Copyright 2023 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation
import SignalMessaging
import UIKit

public class OWSTableItemEditAction {

    public var title: String

    public var block: () -> Void

    public init(title: String, block: @escaping () -> Void) {
        self.title = title
        self.block = block
    }
}

public class OWSTableItem {

    public weak var tableViewController: UIViewController?

    public private(set) var title: String?

    private var customCellBlock: (() -> UITableViewCell)?
    private var dequeueCellBlock: ((UITableView) -> UITableViewCell)?

    public var customRowHeight: CGFloat?

    public private(set) var actionBlock: (() -> Void)?
    public var deleteAction: OWSTableItemEditAction?

    // MARK: -

    public init(title: String?, actionBlock: (() -> Void)?) {
        self.title = title
        self.actionBlock = actionBlock
    }

    public convenience init() {
        self.init(title: nil, actionBlock: nil)
    }

    public convenience init(
        customCellBlock: @escaping () -> UITableViewCell,
        actionBlock: (() -> Void)? = nil
    ) {
        self.init(title: nil, actionBlock: actionBlock)
        self.customCellBlock = customCellBlock
    }

    public convenience init(
        dequeueCellBlock: @escaping (UITableView) -> UITableViewCell,
        actionBlock: (() -> Void)? = nil
    ) {
        self.init(title: nil, actionBlock: actionBlock)
        self.dequeueCellBlock = dequeueCellBlock
    }

    public convenience init(
        text: String,
        actionBlock: (() -> Void)?,
        accessoryText: String? = nil,
        accessoryType: UITableViewCell.AccessoryType,
        accessibilityIdentifier: String? = nil
    ) {
        self.init(title: nil, actionBlock: actionBlock)
        self.customCellBlock = {
            OWSTableItem.buildCellWithAccessoryLabel(
                itemName: text,
                textColor: nil,
                accessoryText: accessoryText,
                accessoryType: accessoryType,
                accessoryImage: nil,
                accessibilityIdentifier: accessibilityIdentifier
            )
        }
    }

    // MARK: - Convenience constructors

    public static func checkmark(
        withText text: String,
        actionBlock: (() -> Void)? = nil,
        accessibilityIdentifier: String? = nil
    ) -> OWSTableItem {
        return OWSTableItem(
            text: text,
            actionBlock: actionBlock,
            accessoryText: nil,
            accessoryType: .checkmark,
            accessibilityIdentifier: accessibilityIdentifier
        )
    }

    public static func disclosureItem(
        withText text: String,
        detailText: String? = nil,
        accessibilityIdentifier: String? = nil,
        actionBlock: (() -> Void)? = nil
    ) -> OWSTableItem {
        let item = OWSTableItem(
            text: text,
            actionBlock: actionBlock,
            accessoryText: detailText,
            accessoryType: .disclosureIndicator,
            accessibilityIdentifier: accessibilityIdentifier
        )
        return item
    }

    public static func actionItem(
        withText text: String,
        textColor: UIColor? = nil,
        accessibilityIdentifier: String? = nil,
        actionBlock: (() -> Void)? = nil
    ) -> OWSTableItem {
        let item = OWSTableItem(title: nil, actionBlock: actionBlock)
        item.customCellBlock = {
            OWSTableItem.buildCellWithAccessoryLabel(
                itemName: text,
                textColor: textColor,
                accessibilityIdentifier: accessibilityIdentifier
            )
        }
        return item
    }

    public static func actionItem(
        withText text: String,
        accessoryImage: UIImage,
        accessibilityIdentifier: String? = nil,
        actionBlock: (() -> Void)? = nil
    ) -> OWSTableItem {
        let item = OWSTableItem(title: nil, actionBlock: actionBlock)
        item.customCellBlock = {
            OWSTableItem.buildCellWithAccessoryLabel(
                itemName: text,
                accessoryImage: accessoryImage,
                accessibilityIdentifier: accessibilityIdentifier
            )
        }
        return item
    }

    public static func subpage(
        withText text: String,
        accessibilityIdentifier: String? = nil,
        actionBlock: @escaping ((UIViewController) -> Void)
    ) -> OWSTableItem {
        let item = OWSTableItem()
        item.actionBlock = { [weak item] in
            guard let item else { return }
            guard let viewController = item.tableViewController else {
                owsFailDebug("viewController == nil")
                return
            }
            actionBlock(viewController)
        }
        item.customCellBlock = {
            OWSTableItem.buildCellWithAccessoryLabel(
                itemName: text,
                accessoryType: .disclosureIndicator,
                accessibilityIdentifier: accessibilityIdentifier
            )
        }
        return item
    }

    public static func softCenterLabel(
        withText text: String
    ) -> OWSTableItem {
        let item = OWSTableItem()
        item.customCellBlock = {
            let cell = OWSTableItem.newCell()
            let textLabel = UILabel()
            textLabel.text = text
            // These cells look quite different.
            //
            // Smaller font.
            textLabel.font = OWSTableItem.primaryLabelFont
            // Soft color.
            // TODO: Theme, review with design.
            textLabel.textColor = UIColor.ows_middleGray
            // Centered.
            textLabel.textAlignment = .center
            cell.contentView.addSubview(textLabel)
            textLabel.autoPinEdgesToSuperviewMargins()
            cell.isUserInteractionEnabled = false
            return cell
        }
        return item
    }

    public static func label(
        withText text: String,
        accessoryText: String? = nil
    ) -> OWSTableItem {
        let item = OWSTableItem()
        item.customCellBlock = {
            let cell = OWSTableItem.buildCellWithAccessoryLabel(
                itemName: text,
                accessoryText: accessoryText
            )
            cell.isUserInteractionEnabled = false
            return cell
        }
        return item
    }

    public static func longDisclosure(
        withText text: String,
        actionBlock: (() -> Void)? = nil
    ) -> OWSTableItem {
        let item = OWSTableItem(title: nil, actionBlock: actionBlock)
        item.customCellBlock = {
            let cell = OWSTableItem.newCell()
            cell.accessoryType = .disclosureIndicator

            let textLabel = UILabel()
            textLabel.text = text
            textLabel.numberOfLines = 0
            textLabel.lineBreakMode = .byWordWrapping
            cell.contentView.addSubview(textLabel)
            textLabel.autoPinEdgesToSuperviewMargins()

            return cell
        }
        return item
    }

    public static func `switch`(
        withText text: String,
        accessibilityIdentifier: String? = nil,
        isOn: @escaping (() -> Bool),
        isEnabled: @escaping (() -> Bool) = { true },
        target: AnyObject,
        selector: Selector
    ) -> OWSTableItem {
        let item = OWSTableItem()
        item.customCellBlock = { [weak target] in
            let cell = OWSTableItem.buildCellWithAccessoryLabel(
                itemName: text,
                accessibilityIdentifier: accessibilityIdentifier
            )
            cell.selectionStyle = .none

            let cellSwitch = UISwitch()
            cell.accessoryView = cellSwitch
            cellSwitch.isOn = isOn()
            cellSwitch.isEnabled = isEnabled()
            cellSwitch.accessibilityIdentifier = accessibilityIdentifier
            cellSwitch.addTarget(target, action: selector, for: .valueChanged)

            return cell
        }
        return item
    }

    // MARK: -

    public class func newCell() -> UITableViewCell {
        let cell = UITableViewCell()
        configureCell(cell)
        return cell
    }

    public class func configureCell(_ cell: UITableViewCell) {
        cell.selectedBackgroundView = UIView()
        cell.backgroundColor = Theme.backgroundColor
        cell.selectedBackgroundView?.backgroundColor = Theme.tableCell2SelectedBackgroundColor
        cell.multipleSelectionBackgroundView?.backgroundColor = Theme.tableCell2MultiSelectedBackgroundColor
        configureCellLabels(cell)
    }

    private class func configureCellLabels(_ cell: UITableViewCell) {
        cell.textLabel?.font = self.primaryLabelFont
        cell.textLabel?.textColor = Theme.primaryTextColor
        cell.detailTextLabel?.textColor = Theme.secondaryTextAndIconColor
        cell.detailTextLabel?.font = OWSTableItem.accessoryLabelFont
    }

    func getOrBuildCustomCell(_ tableView: UITableView) -> UITableViewCell? {
        if let customCellBlock {
            owsAssertDebug(dequeueCellBlock == nil)
            return customCellBlock()
        }
        if let dequeueCellBlock {
            return dequeueCellBlock(tableView)
        }
        return nil
    }
}

public extension OWSTableItem {

    enum AccessoryImageTint: Int {
        case untinted
        case tinted
    }

    static var primaryLabelFont: UIFont { .dynamicTypeBodyClamped }
    static var accessoryLabelFont: UIFont { .dynamicTypeBodyClamped }

    static var iconSpacing: CGFloat { 16 }
    static var iconSize: CGFloat { 24 }

    private static func accessoryGray() -> UIColor {
        Theme.isDarkThemeEnabled ? .ows_gray25 : .ows_gray45
    }

    static func buildCell(name: String, iconView: UIView) -> UITableViewCell {
        return buildCell(name: name, iconView: iconView, iconSpacing: self.iconSpacing)
    }

    static func buildCell(name: String, iconView: UIView, iconSpacing: CGFloat) -> UITableViewCell {
        assert(!name.isEmpty)

        let cell = OWSTableItem.newCell()
        cell.preservesSuperviewLayoutMargins = true
        cell.contentView.preservesSuperviewLayoutMargins = true

        let rowLabel = UILabel()
        rowLabel.text = name
        rowLabel.textColor = Theme.primaryTextColor
        rowLabel.font = OWSTableItem.primaryLabelFont
        rowLabel.lineBreakMode = .byTruncatingTail

        let contentRow = UIStackView(arrangedSubviews: [ iconView, rowLabel ])
        contentRow.spacing = iconSpacing

        cell.contentView.addSubview(contentRow)
        contentRow.autoPinEdgesToSuperviewMargins()

        return cell
    }

    static func imageView(forIcon icon: ThemeIcon,
                          tintColor: UIColor? = nil,
                          iconSize: CGFloat = iconSize) -> UIImageView {
        let iconImage = Theme.iconImage(icon)
        let iconView = imageView(forImage: iconImage)
        iconView.tintColor = tintColor ?? Theme.primaryIconColor
        return iconView
    }

    private static func imageView(forImage: UIImage,
                                  iconSize: CGFloat = iconSize) -> UIImageView {
        let result = UIImageView(image: forImage)
        result.contentMode = .scaleAspectFit
        result.layer.minificationFilter = .trilinear
        result.layer.magnificationFilter = .trilinear
        result.autoSetDimensions(to: CGSize(square: iconSize))
        return result
    }

    static func buildCell(name: String,
                          icon: ThemeIcon,
                          accessibilityIdentifier: String? = nil) -> UITableViewCell {
        let iconView = imageView(forIcon: icon)
        let cell = buildCell(name: name, iconView: iconView)
        cell.accessibilityIdentifier = accessibilityIdentifier
        return cell
    }

    static func buildDisclosureCell(name: String,
                                    icon: ThemeIcon,
                                    accessibilityIdentifier: String) -> UITableViewCell {
        let cell = buildCell(name: name, icon: icon)
        cell.accessoryType = .disclosureIndicator
        cell.accessibilityIdentifier = accessibilityIdentifier
        return cell
    }

    static func buildLabelCell(name: String,
                               icon: ThemeIcon,
                               accessibilityIdentifier: String) -> UITableViewCell {
        let cell = buildCell(name: name, icon: icon)
        cell.accessoryType = .none
        cell.accessibilityIdentifier = accessibilityIdentifier
        return cell
    }

    static func disclosureItem(icon: ThemeIcon,
                               name: String,
                               maxNameLines: Int? = nil,
                               accessoryText: String? = nil,
                               accessibilityIdentifier: String,
                               actionBlock: (() -> Void)?) -> OWSTableItem {
        item(icon: icon,
             name: name,
             maxNameLines: maxNameLines,
             accessoryText: accessoryText,
             accessoryType: .disclosureIndicator,
             accessibilityIdentifier: accessibilityIdentifier,
             actionBlock: actionBlock)
    }

    static func actionItem(icon: ThemeIcon? = nil,
                           tintColor: UIColor? = nil,
                           name: String,
                           textColor: UIColor? = nil,
                           accessoryText: String? = nil,
                           accessoryImage: UIImage? = nil,
                           accessoryImageTint: AccessoryImageTint = .tinted,
                           accessibilityIdentifier: String,
                           actionBlock: (() -> Void)?) -> OWSTableItem {
        item(icon: icon,
             tintColor: tintColor,
             name: name,
             textColor: textColor,
             accessoryText: accessoryText,
             accessoryImage: accessoryImage,
             accessoryImageTint: accessoryImageTint,
             accessibilityIdentifier: accessibilityIdentifier,
             actionBlock: actionBlock)
    }

    static func item(icon: ThemeIcon? = nil,
                     tintColor: UIColor? = nil,
                     name: String,
                     subtitle: String? = nil,
                     maxNameLines: Int? = nil,
                     textColor: UIColor? = nil,
                     accessoryText: String? = nil,
                     accessoryType: UITableViewCell.AccessoryType = .none,
                     accessoryImage: UIImage? = nil,
                     accessoryImageTint: AccessoryImageTint = .tinted,
                     accessoryView: UIView? = nil,
                     accessibilityIdentifier: String,
                     actionBlock: (() -> Void)? = nil) -> OWSTableItem {

        OWSTableItem(customCellBlock: {
            OWSTableItem.buildCellWithAccessoryLabel(
            icon: icon,
            tintColor: tintColor,
            itemName: name,
            subtitle: subtitle,
            maxItemNameLines: maxNameLines,
            textColor: textColor,
            accessoryText: accessoryText,
            accessoryType: accessoryType,
            accessoryImage: accessoryImage,
            accessoryImageTint: accessoryImageTint,
            accessoryView: accessoryView,
            accessibilityIdentifier: accessibilityIdentifier
            )
        },
                     actionBlock: actionBlock)
    }

    static func buildCellWithAccessoryLabel(icon: ThemeIcon? = nil,
                                            tintColor: UIColor? = nil,
                                            itemName: String,
                                            subtitle: String? = nil,
                                            maxItemNameLines: Int? = nil,
                                            textColor: UIColor? = nil,
                                            accessoryText: String? = nil,
                                            accessoryType: UITableViewCell.AccessoryType = .disclosureIndicator,
                                            accessoryImage: UIImage? = nil,
                                            accessoryImageTint: AccessoryImageTint = .tinted,
                                            accessoryView: UIView? = nil,
                                            accessibilityIdentifier: String? = nil) -> UITableViewCell {
        buildIconNameCell(icon: icon,
                          tintColor: tintColor,
                          itemName: itemName,
                          subtitle: subtitle,
                          maxItemNameLines: maxItemNameLines,
                          textColor: textColor,
                          accessoryText: accessoryText,
                          accessoryType: accessoryType,
                          accessoryImage: accessoryImage,
                          accessoryImageTint: accessoryImageTint,
                          accessoryView: accessoryView,
                          accessibilityIdentifier: accessibilityIdentifier)
    }

    static func buildIconNameCell(icon: ThemeIcon? = nil,
                                  tintColor: UIColor? = nil,
                                  itemName: String,
                                  subtitle: String? = nil,
                                  maxItemNameLines: Int? = nil,
                                  textColor: UIColor? = nil,
                                  accessoryText: String? = nil,
                                  accessoryTextColor: UIColor? = nil,
                                  accessoryType: UITableViewCell.AccessoryType = .none,
                                  accessoryImage: UIImage? = nil,
                                  accessoryImageTint: AccessoryImageTint = .tinted,
                                  accessoryView: UIView? = nil,
                                  customColor: UIColor? = nil,
                                  accessibilityIdentifier: String? = nil) -> UITableViewCell {
        var imageView: UIImageView?
        if let icon = icon {
            let iconView = self.imageView(forIcon: icon, tintColor: customColor ?? tintColor, iconSize: iconSize)
            iconView.setCompressionResistanceHorizontalHigh()
            imageView = iconView
        }
        return buildImageViewNameCell(imageView: imageView,
                                      itemName: itemName,
                                      subtitle: subtitle,
                                      maxItemNameLines: maxItemNameLines,
                                      textColor: textColor,
                                      accessoryText: accessoryText,
                                      accessoryTextColor: accessoryTextColor,
                                      accessoryType: accessoryType,
                                      accessoryImage: accessoryImage,
                                      accessoryImageTint: accessoryImageTint,
                                      accessoryView: accessoryView,
                                      customColor: customColor,
                                      accessibilityIdentifier: accessibilityIdentifier)
    }

    static func buildImageNameCell(image: UIImage? = nil,
                                   itemName: String,
                                   subtitle: String? = nil,
                                   accessoryText: String? = nil,
                                   accessoryTextColor: UIColor? = nil,
                                   accessoryType: UITableViewCell.AccessoryType = .none,
                                   accessibilityIdentifier: String? = nil) -> UITableViewCell {
        var imageView: UIImageView?
        if let image = image {
            let imgView = self.imageView(forImage: image)
            imgView.setCompressionResistanceHorizontalHigh()
            imageView = imgView
        }

        return buildImageViewNameCell(imageView: imageView,
                                      itemName: itemName,
                                      subtitle: subtitle,
                                      accessoryText: accessoryText,
                                      accessoryTextColor: accessoryTextColor,
                                      accessoryType: accessoryType,
                                      accessibilityIdentifier: accessibilityIdentifier)
    }

    private static func buildImageViewNameCell(imageView: UIImageView? = nil,
                                               tintColor: UIColor? = nil,
                                               itemName: String,
                                               subtitle: String? = nil,
                                               maxItemNameLines: Int? = nil,
                                               textColor: UIColor? = nil,
                                               accessoryText: String? = nil,
                                               accessoryTextColor: UIColor? = nil,
                                               accessoryType: UITableViewCell.AccessoryType = .none,
                                               accessoryImage: UIImage? = nil,
                                               accessoryImageTint: AccessoryImageTint = .tinted,
                                               accessoryView: UIView? = nil,
                                               customColor: UIColor? = nil,
                                               accessibilityIdentifier: String? = nil) -> UITableViewCell {

        // We can't use the built-in UITableViewCell with CellStyle.value1,
        // because if the content of the primary label and the accessory label
        // overflow the cell layout, their contents will overlap.  We want
        // the labels to truncate in that scenario.
        let cell = OWSTableItem.newCell()
        cell.preservesSuperviewLayoutMargins = true
        cell.contentView.preservesSuperviewLayoutMargins = true

        var subviews = [UIView]()

        if let imageView = imageView {
            subviews.append(imageView)
        }

        let nameLabel = UILabel()
        nameLabel.text = itemName
        if let textColor = textColor {
            nameLabel.textColor = textColor
        } else {
            nameLabel.textColor = Theme.primaryTextColor
        }
        nameLabel.font = OWSTableItem.primaryLabelFont
        nameLabel.adjustsFontForContentSizeCategory = true

        // Having two side-by-side multi-line labels makes
        // autolayout *really* confused because it doesn't
        // seem to know which height to respect (if they are
        // of different intrinsic height). It leads to lots of
        // very strange indeterminant behavior. To work around,
        // we only allow the longer of the two labels to be
        // multi-line.
        if let maxItemNameLines = maxItemNameLines {
            nameLabel.numberOfLines = maxItemNameLines
            nameLabel.lineBreakMode = .byTruncatingTail
        } else if itemName.count >= (accessoryText ?? "").count {
            nameLabel.numberOfLines = 0
            nameLabel.lineBreakMode = .byWordWrapping
        } else {
            nameLabel.numberOfLines = 1
            nameLabel.lineBreakMode = .byTruncatingTail
        }

        nameLabel.setContentHuggingLow()
        nameLabel.setCompressionResistanceHigh()

        if subtitle == nil {
            subviews.append(nameLabel)
        } else {
            let subtitleLabel = UILabel()
            subtitleLabel.text = subtitle
            subtitleLabel.textColor = accessoryGray()
            subtitleLabel.font = .dynamicTypeFootnoteClamped

            let labels = UIStackView(arrangedSubviews: [nameLabel, subtitleLabel])
            labels.axis = .vertical
            subviews.append(labels)
        }

        if let customColor = customColor {
            nameLabel.textColor = customColor
        }

        if let accessoryView = accessoryView {
            owsAssertDebug(accessoryText == nil)

            subviews.append(accessoryView)
        } else if let accessoryText = accessoryText {
            let accessoryLabel = UILabel()
            accessoryLabel.text = accessoryText
            accessoryLabel.textColor = accessoryTextColor ?? accessoryGray()
            accessoryLabel.font = OWSTableItem.accessoryLabelFont
            accessoryLabel.adjustsFontForContentSizeCategory = true

            if itemName.count >= accessoryText.count {
                accessoryLabel.numberOfLines = 1
                accessoryLabel.lineBreakMode = .byTruncatingTail
            } else {
                accessoryLabel.numberOfLines = 0
                accessoryLabel.lineBreakMode = .byWordWrapping
            }

            accessoryLabel.setCompressionResistanceHigh()
            accessoryLabel.setContentHuggingHorizontalHigh()
            accessoryLabel.setContentHuggingVerticalLow()
            subviews.append(accessoryLabel)
        }

        let contentRow = UIStackView(arrangedSubviews: subviews)
        contentRow.axis = .horizontal
        contentRow.alignment = .center
        contentRow.spacing = self.iconSpacing
        cell.contentView.addSubview(contentRow)

        contentRow.setContentHuggingHigh()
        contentRow.autoPinEdgesToSuperviewMargins()
        contentRow.autoSetDimension(.height, toSize: iconSize, relation: .greaterThanOrEqual)

        cell.accessibilityIdentifier = accessibilityIdentifier

        if let accessoryImage = accessoryImage {
            let accessoryImageView = UIImageView()

            switch accessoryImageTint {
            case .tinted:
                accessoryImageView.setTemplateImage(
                    accessoryImage,
                    // Match the OS accessory view colors
                    tintColor: Theme.isDarkThemeEnabled ? .ows_whiteAlpha25 : .ows_blackAlpha25
                )
            case .untinted:
                accessoryImageView.image = accessoryImage
            }

            accessoryImageView.sizeToFit()
            cell.accessoryView = accessoryImageView
        } else {
            cell.accessoryType = accessoryType
        }

        return cell
    }

    static func buildIconInCircleView(icon: ThemeIcon,
                                      innerIconSize: CGFloat) -> UIView {
        return buildIconInCircleView(icon: icon,
                                     iconSize: nil,
                                     innerIconSize: innerIconSize,
                                     iconTintColor: nil)
    }

    static func buildIconInCircleView(icon: ThemeIcon,
                                      innerIconSize: CGFloat,
                                      iconTintColor: UIColor) -> UIView {
        return buildIconInCircleView(icon: icon,
                                     iconSize: nil,
                                     innerIconSize: innerIconSize,
                                     iconTintColor: iconTintColor)
    }
}

// MARK: -

public extension OWSTableItem {

    static func buildIconInCircleView(icon: ThemeIcon,
                                      iconSize iconSizeParam: UInt? = nil,
                                      innerIconSize innerIconSizeParam: CGFloat? = nil,
                                      iconTintColor: UIColor? = nil) -> UIView {
        let iconSize = CGFloat(iconSizeParam ?? AvatarBuilder.standardAvatarSizePoints)
        let innerIconSize: CGFloat
        if let innerIconSizeParam = innerIconSizeParam {
            innerIconSize = innerIconSizeParam
        } else {
            innerIconSize = CGFloat(iconSize) * 0.6
        }
        let iconView = OWSTableItem.imageView(forIcon: icon, tintColor: iconTintColor ?? Theme.accentBlueColor, iconSize: innerIconSize)
        let iconWrapper = UIView.container()
        iconWrapper.addSubview(iconView)
        iconView.autoCenterInSuperview()
        iconWrapper.backgroundColor = Theme.isDarkThemeEnabled ? .ows_gray65 : .ows_gray02
        iconWrapper.layer.cornerRadius = iconSize * 0.5
        iconWrapper.autoSetDimensions(to: CGSize(square: iconSize))
        iconWrapper.setCompressionResistanceHigh()
        iconWrapper.setContentHuggingHigh()
        return iconWrapper
    }

    // Factory method for rows that display a labeled value.
    // The value can be copied to the pasteboard by tapping.
    static func copyableItem(label: String,
                             value displayValue: String?,
                             pasteboardValue: String? = nil,
                             accessibilityIdentifier: String? = nil) -> OWSTableItem {
        // If there is a custom pasteboardValue, honor it.
        // Otherwise just default to using the displayValue.
        let pasteboardValue = pasteboardValue ?? displayValue
        let accessibilityIdentifier = accessibilityIdentifier ?? label
        let displayValue = displayValue ?? OWSLocalizedString("MISSING_VALUE",
                                                             comment: "Generic indicator that no value is available for display")
        return .item(
            name: label,
            accessoryText: displayValue,
            accessibilityIdentifier: accessibilityIdentifier,
            actionBlock: {
                if let pasteboardValue = pasteboardValue {
                    UIPasteboard.general.string = pasteboardValue
                }

                guard let fromVC = CurrentAppContext().frontmostViewController() else {
                    owsFailDebug("could not identify frontmostViewController")
                    return
                }
                let toast = OWSLocalizedString("COPIED_TO_CLIPBOARD",
                                              comment: "Indicator that a value has been copied to the clipboard.")
                fromVC.presentToast(text: toast)

            }
        )
    }
}
