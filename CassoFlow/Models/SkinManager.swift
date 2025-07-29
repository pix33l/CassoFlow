import SwiftUI

// 创建一个新的皮肤模型文件
struct PlayerSkin: Identifiable {
    let id = UUID()
    let name: String
    let year: String
    let description: String
    let coverImage: String
    let panelColor: Color
    let panelOutlineColor: Color
    let buttonColor: Color
    let buttonTextColor: Color
    let buttonShadowColor: Color
    let screenColor: Color
    let screenTextColor: Color
    let screenOutlineColor: Color
    let playerImage: String
    let cassetteBgImage: String
    let buttonCornerRadius: CGFloat
    let buttonHeight: CGFloat

    // 播放器皮肤集合
    static let playerSkins: [PlayerSkin] = [
        
        PlayerSkin(
            name: "CF-DEMO",  // 名称作为唯一标识
            year: "2022",
            description: String(localized: "演示用磁带播放器"),
            coverImage: "cover-CF-DEMO",
            panelColor: .clear,
            panelOutlineColor: .clear,
            buttonColor: Color("button-dark"),
            buttonTextColor: .gray,
            buttonShadowColor: Color("shadow-button-dark"),
            screenColor: Color("bg-screen-orange"),
            screenTextColor: Color("text-screen-orange"),
            screenOutlineColor: .black,
            playerImage: "player-CF-DEMO",
            cassetteBgImage: "bg-cassette",
            buttonCornerRadius: 30,
            buttonHeight: 60
        ),
        PlayerSkin(
            name: "CF-PC13",  // 名称作为唯一标识
            year: "2024",
            description: String(localized: "飞翔牌磁带播放器"),
            coverImage: "cover-CF-PC13",
            panelColor: .clear,
            panelOutlineColor: .clear,
            buttonColor: Color("button-dark"),
            buttonTextColor: .gray,
            buttonShadowColor: Color("shadow-button-dark"),
            screenColor: Color("bg-screen-blue"),
            screenTextColor: Color("text-screen-blue"),
            screenOutlineColor: .black,
            playerImage: "player-CF-PC13",
            cassetteBgImage: "bg-cassette",
            buttonCornerRadius: 25,
            buttonHeight: 50
        ),
        PlayerSkin(
            name: "CF-M10",  // 名称作为唯一标识
            year: "2024",
            description: String(localized: "国宝牌磁带播放器"),
            coverImage: "cover-CF-M10",
            panelColor: .clear,
            panelOutlineColor: .clear,
            buttonColor: Color("button-dark"),
            buttonTextColor: .gray,
            buttonShadowColor: Color("shadow-button-dark"),
            screenColor: Color("bg-screen-orange"),
            screenTextColor: Color("text-screen-orange"),
            screenOutlineColor: .black,
            playerImage: "player-CF-M10",
            cassetteBgImage: "bg-cassette",
            buttonCornerRadius: 8,
            buttonHeight: 50
        ),
        PlayerSkin(
            name: "CF-MU01",  // 名称作为唯一标识
            year: "2024",
            description: String(localized: "卡农牌磁带播放器"),
            coverImage: "cover-CF-MU01",
            panelColor: .clear,
            panelOutlineColor: .clear,
            buttonColor: Color("button-dark"),
            buttonTextColor: .white,
            buttonShadowColor: Color("shadow-button-dark"),
            screenColor: Color("bg-screen-green"),
            screenTextColor: Color("text-screen-green"),
            screenOutlineColor: .black,
            playerImage: "player-CF-MU01",
            cassetteBgImage: "bg-cassette",
            buttonCornerRadius: 4,
            buttonHeight: 50
        ),
        PlayerSkin(
            name: "CF-L2",  // 名称作为唯一标识
            year: "1979",
            description: String(localized: "首款便携式磁带播放器"),
            coverImage: "cover-CF-L2",
            panelColor: .clear,
            panelOutlineColor: .clear,
            buttonColor: Color("button-light"),
            buttonTextColor: .black,
            buttonShadowColor: Color("shadow-button-light"),
            screenColor: Color("bg-screen-orange"),
            screenTextColor: Color("text-screen-orange"),
            screenOutlineColor: .black,
            playerImage: "player-CF-L2",
            cassetteBgImage: "bg-cassette",
            buttonCornerRadius: 8,
            buttonHeight: 50
        ),
        PlayerSkin(
            name: "CF-2",  // 名称作为唯一标识
            year: "1981",
            description: String(localized: "能时间旅行的磁带播放器"),
            coverImage: "cover-CF-2",
            panelColor: .clear,
            panelOutlineColor: .clear,
            buttonColor: Color("button-dark"),
            buttonTextColor: .white,
            buttonShadowColor: Color("shadow-button-dark"),
            screenColor: Color("bg-screen-blue"),
            screenTextColor: Color("text-screen-blue"),
            screenOutlineColor: .black,
            playerImage: "player-CF-2",
            cassetteBgImage: "bg-cassette",
            buttonCornerRadius: 25,
            buttonHeight: 50
        ),
        PlayerSkin(
            name: "CF-22",  // 名称作为唯一标识
            year: "1984",
            description: String(localized: "物美价廉的磁带播放器"),
            coverImage: "cover-CF-22",
            panelColor: Color("bg-panel-dark"),
            panelOutlineColor: .black,
            buttonColor: Color("button-dark"),
            buttonTextColor: .white,
            buttonShadowColor:  Color("shadow-button-dark"),
            screenColor: Color("bg-screen-green"),
            screenTextColor: Color("text-screen-green"),
            screenOutlineColor: Color("outline-screen-CF-11"),
            playerImage: "player-CF-22",
            cassetteBgImage: "bg-cassette",
            buttonCornerRadius: 8,
            buttonHeight: 50
        ),
        PlayerSkin(
            name: "CF-504",  // 名称作为唯一标识
            year: "1987",
            description: String(localized: "首款全透明磁带播放器"),
            coverImage: "cover-CF-504",
            panelColor: .clear,
            panelOutlineColor: .clear,
            buttonColor: Color("button-dark"),
            buttonTextColor: .gray,
            buttonShadowColor:  Color("shadow-button-dark"),
            screenColor: Color("bg-screen-blue"),
            screenTextColor: Color("text-screen-blue"),
            screenOutlineColor: .black,
            playerImage: "player-CF-504",
            cassetteBgImage: "bg-cassette",
            buttonCornerRadius: 12,
            buttonHeight: 50
        ),
        PlayerSkin(
            name: "CF-D6C",  // 名称作为唯一标识
            year: "1984",
            description: String(localized: "为专业用户生产的磁带播放器"),
            coverImage: "cover-CF-D6C",
            panelColor: Color("bg-panel-dark"),
            panelOutlineColor: .black,
            buttonColor: Color("button-dark"),
            buttonTextColor: .white,
            buttonShadowColor: Color("shadow-button-dark"),
            screenColor: Color("bg-screen-orange"),
            screenTextColor: Color("text-screen-orange"),
            screenOutlineColor: .black,
            playerImage: "player-CF-D6C",
            cassetteBgImage: "bg-cassette",
            buttonCornerRadius: 8,
            buttonHeight: 50
        ),
        PlayerSkin(
            name: "CF-DD9",  // 名称作为唯一标识
            year: "1989",
            description: String(localized: "磁带播放器之王"),
            coverImage: "cover-CF-DD9",
            panelColor: .clear,
            panelOutlineColor: .clear,
            buttonColor: Color("button-dark"),
            buttonTextColor: .gray,
            buttonShadowColor: Color("shadow-button-dark"),
            screenColor: Color("bg-screen-blue"),
            screenTextColor: Color("text-screen-blue"),
            screenOutlineColor: .black,
            playerImage: "player-CF-DD9",
            cassetteBgImage: "bg-cassette",
            buttonCornerRadius: 12,
            buttonHeight: 50
        ),
        PlayerSkin(
            name: "CF-DT1",  // 名称作为唯一标识
            year: "1993",
            description: String(localized: "经典动漫中的磁带播放器"),
            coverImage: "cover-CF-DT1",
            panelColor: Color("bg-panel-dark"),
            panelOutlineColor: .black,
            buttonColor: Color("button-dark"),
            buttonTextColor: .white,
            buttonShadowColor: Color("shadow-button-dark"),
            screenColor: Color("bg-screen-green"),
            screenTextColor: Color("text-screen-green"),
            screenOutlineColor: .black,
            playerImage: "player-CF-DT1",
            cassetteBgImage: "bg-cassette",
            buttonCornerRadius: 12,
            buttonHeight: 50
        ),
        PlayerSkin(
            name: "CF-CW5",  // 名称作为唯一标识
            year: "2001",
            description: String(localized: "极具性价比的入门磁带播放器"),
            coverImage: "cover-CF-CW5",
            panelColor: .clear,
            panelOutlineColor: .clear,
            buttonColor: Color("button-orange"),
            buttonTextColor: .black.opacity(0.5),
            buttonShadowColor: Color("shadow-button-orange"),
            screenColor: Color("bg-screen-green"),
            screenTextColor: Color("text-screen-green"),
            screenOutlineColor: .black,
            playerImage: "player-CF-CW5",
            cassetteBgImage: "bg-cassette",
            buttonCornerRadius: 25,
            buttonHeight: 50
        ),
        PlayerSkin(
            name: "CF-NT",  // 名称作为唯一标识
            year: "2025",
            description: String(localized: "极具未来感的磁带播放器"),
            coverImage: "cover-CF-NT",
            panelColor: .clear,
            panelOutlineColor: .clear,
            buttonColor: Color("button-dark"),
            buttonTextColor: .white.opacity(0.5),
            buttonShadowColor: Color("shadow-button-dark"),
            screenColor: Color("bg-screen-blue"),
            screenTextColor: Color("text-screen-blue"),
            screenOutlineColor: .black,
            playerImage: "player-CF-NT",
            cassetteBgImage: "bg-cassette",
            buttonCornerRadius: 25,
            buttonHeight: 50
        )
    ]
    
    // 根据名称获取播放器皮肤
    static func playerSkin(named name: String) -> PlayerSkin? {
        return playerSkins.first(where: { $0.name == name })
    }
    
    // 检查是否为默认免费皮肤
    func isFreeDefaultSkin() -> Bool {
        return ["CF-DEMO"].contains(self.name)
    }
    
    func isMemberExclusiveSkin() -> Bool {
        return ["CF-PC13", "CF-M10", "CF-MU01", "CF-L2", "CF-2", "CF-22", "CF-504", "CF-D6C", "CF-DD9", "CF-DT1", "CF-CW5", "CF-NT"].contains(self.name)
    }
}

struct CassetteSkin: Identifiable {
    let id = UUID()
    let name: String
    let year: String
    let description: String
    let coverImage: String
    let cassetteImage: String
    let cassetteHole: String
    let cassetteColor: Color

    // 磁带皮肤集合
    static let cassetteSkins: [CassetteSkin] = [
        
        CassetteSkin(
            name: "CFT-DEMO",  // 名称作为唯一标识
            year: "2025",
            description: String(localized: "透明演示磁带"),
            coverImage: "cover-CFT-DEMO",
            cassetteImage: "CFT-DEMO",
            cassetteHole: "holeDark",
            cassetteColor: Color("cassetteColor")
        ),
        CassetteSkin(
            name: "CFT-W60",  // 名称作为唯一标识
            year: "2022",
            description: String(localized: "彩虹条纹录音磁带"),
            coverImage: "cover-CFT-W60",
            cassetteImage: "CFT-W60",
            cassetteHole: "holeDark",
            cassetteColor: Color("cassetteColor")
        ),
        CassetteSkin(
            name: "CFT-C60",  // 名称作为唯一标识
            year: "1985",
            description: String(localized: "标签可写的彩色磁带"),
            coverImage: "cover-CFT-C60",
            cassetteImage: "CFT-C60",
            cassetteHole: "holeDark",
            cassetteColor: Color("cassetteColor")
        ),
        CassetteSkin(
            name: "CFT-60CR",  // 名称作为唯一标识
            year: "2025",
            description: String(localized: "二氧化铬作为材料的高端磁带"),
            coverImage: "cover-CFT-60CR",
            cassetteImage: "CFT-60CR",
            cassetteHole: "holeDark",
            cassetteColor: Color("cassetteColor")
        ),
        CassetteSkin(
            name: "CFT-MM60",  // 名称作为唯一标识
            year: "1988",
            description: String(localized: "白色陶瓷外壳的顶级磁带"),
            coverImage: "cover-CFT-MM60",
            cassetteImage: "CFT-MM60",
            cassetteHole: "holeDark",
            cassetteColor: Color("cassetteColor")
        )
    ]

    // 根据名称获取磁带皮肤
    static func cassetteSkin(named name: String) -> CassetteSkin? {
        return cassetteSkins.first(where: { $0.name == name })
    }
    
    // 检查是否为默认免费皮肤
    func isFreeDefaultSkin() -> Bool {
        return ["CFT-DEMO"].contains(self.name)
    }
    
    func isMemberExclusiveSkin() -> Bool {
        return ["CFT-W60", "CFT-C60", "CFT-60CR", "CFT-MM60"].contains(self.name)
    }
}

// MARK: - 皮肤工具类
@MainActor
class SkinHelper {
    
    /// 检查播放器皮肤是否已拥有（包含会员权限）
    static func isPlayerSkinOwned(_ skinName: String, storeManager: StoreManager) -> Bool {
        let skin = PlayerSkin.playerSkin(named: skinName)
        
        // 如果是免费皮肤，直接返回true
        if skin?.isFreeDefaultSkin() == true {
            return true
        }
        
        // 如果是会员用户（且会员状态有效），可以使用所有皮肤
        if storeManager.membershipStatus.isActive {
            return true
        }
        
        // 非会员用户需要单独购买皮肤才能使用
        return storeManager.ownsPlayerSkin(skinName)
    }
    
    /// 检查磁带皮肤是否已拥有（包含会员权限）
    static func isCassetteSkinOwned(_ skinName: String, storeManager: StoreManager) -> Bool {
        let skin = CassetteSkin.cassetteSkin(named: skinName)
        
        // 如果是免费皮肤，直接返回true
        if skin?.isFreeDefaultSkin() == true {
            return true
        }
        
        // 如果是会员用户（且会员状态有效），可以使用所有皮肤
        if storeManager.membershipStatus.isActive {
            return true
        }
        
        // 非会员用户需要单独购买皮肤才能使用
        return storeManager.ownsCassetteSkin(skinName)
    }
    
    /// 根据播放器皮肤名称获取价格显示文本
    static func getPlayerSkinPrice(_ skinName: String, storeManager: StoreManager) -> String {
        let skin = PlayerSkin.playerSkin(named: skinName)
        if skin?.isFreeDefaultSkin() == true {
            return String(localized: "免费")
        }
        
        // 如果是会员专享皮肤，显示会员专享
        if skin?.isMemberExclusiveSkin() == true {
            return String(localized: "PRO 专享")
        }
        
        // 如果是有效会员，显示"会员专享"
        if storeManager.membershipStatus.isActive {
            return String(localized: "选择")
        }
        
        let productID = getPlayerSkinProductID(skinName)
        return storeManager.getProductPrice(for: productID)
    }
    
    /// 根据磁带皮肤名称获取价格显示文本
    static func getCassetteSkinPrice(_ skinName: String, storeManager: StoreManager) -> String {
        let skin = CassetteSkin.cassetteSkin(named: skinName)
        if skin?.isFreeDefaultSkin() == true {
            return String(localized: "免费")
        }
        
        // 如果是会员专享皮肤，显示会员专享
        if skin?.isMemberExclusiveSkin() == true {
            return String(localized: "PRO 专享")
        }
        
        // 如果是有效会员，显示"会员专享"
        if storeManager.membershipStatus.isActive {
            return String(localized: "选择")
        }
        
        let productID = getCassetteSkinProductID(skinName)
        return storeManager.getProductPrice(for: productID)
    }
    
    /// 根据播放器皮肤名称获取产品ID
    static func getPlayerSkinProductID(_ skinName: String) -> String {
        switch skinName {
        case "CF-PC13": return StoreManager.ProductIDs.cfPC13
        case "CF-M10": return StoreManager.ProductIDs.cfM10
        case "CF-MU01": return StoreManager.ProductIDs.cfMU01
        case "CF-L2": return StoreManager.ProductIDs.cfL2
        case "CF-2": return StoreManager.ProductIDs.cf2
        case "CF-22": return StoreManager.ProductIDs.cf22
        case "CF-504": return StoreManager.ProductIDs.cf504
        case "CF-D6C": return StoreManager.ProductIDs.cfD6C
        case "CF-DD9": return StoreManager.ProductIDs.cfDD9
        case "CF-DT1": return StoreManager.ProductIDs.cfDT1
        default: return ""
        }
    }
    
    /// 根据磁带皮肤名称获取产品ID
    static func getCassetteSkinProductID(_ skinName: String) -> String {
        switch skinName {
        case "CFT-W60": return StoreManager.ProductIDs.cftW60
        case "CFT-C60": return StoreManager.ProductIDs.cftC60
        case "CFT-60CR": return StoreManager.ProductIDs.cft60CR
        case "CFT-MM60": return StoreManager.ProductIDs.cftMM60
        default: return ""
        }
    }
}
