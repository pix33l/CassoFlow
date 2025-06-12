import SwiftUI

// 创建一个新的皮肤模型文件
struct PlayerSkin: Identifiable {
    let id = UUID()
    let name: String
    let year: String
    let description: String
    let coverImage: String
    let panelColor: Color
    let buttonColor: Color
    let buttonTextColor: Color
    let buttonShadowColor: Color
    let screenColor: Color
    let screenTextColor: Color
    let screenOutlineColor: Color
    let playerImage: String
    let cassetteBgImage: String
    
    // 播放器皮肤集合
    static let playerSkins: [PlayerSkin] = [
        
        PlayerSkin(
            name: "CF-DEMO",  // 名称作为唯一标识
            year: "2025",
            description: "正在研发的播放器蓝图",
            coverImage: "cover-CF-DEMO",
            panelColor: Color("cassetteLight"),
            buttonColor: Color("cassetteLight"),
            buttonTextColor: Color("cassetteDark"),
            buttonShadowColor: Color("cassetteDark"),
            screenColor: Color("cassetteLight"),
            screenTextColor: Color("cassetteDark"),
            screenOutlineColor: Color("cassetteDark"),
            playerImage: "player-CF-DEMO",
            cassetteBgImage: "bg-cassette"
        ),
        PlayerSkin(
            name: "CF-L2",  // 名称作为唯一标识
            year: "1985",
            description: "第一款 CF 便携式播放器",
            coverImage: "cover-CF-L2",
            panelColor: Color("bg-panel-light"),
            buttonColor: Color("button-light"),
            buttonTextColor: .black,
            buttonShadowColor: Color("shadow-button-light"),
            screenColor: Color("bg-screen-orange"),
            screenTextColor: Color("text-screen-orange"),
            screenOutlineColor: .black,
            playerImage: "player-CF-L2",
            cassetteBgImage: "bg-cassette"
        ),
        PlayerSkin(
            name: "CF-22",  // 名称作为唯一标识
            year: "1984",
            description: "经典的黑色播放器设计",
            coverImage: "cover-CF-22",
            panelColor: .black,
            buttonColor: .white.opacity(0.1),
            buttonTextColor: .white,
            buttonShadowColor: .black,
            screenColor: Color("bg-screen-green"),
            screenTextColor: Color("text-screen-green"),
            screenOutlineColor: Color("outline-screen-CF-11"),
            playerImage: "player-CF-22",
            cassetteBgImage: "bg-cassette"
        ),
        PlayerSkin(
            name: "CF-504",  // 名称作为唯一标识
            year: "1987",
            description: "经典便携式播放器",
            coverImage: "CF-101",
            panelColor: .black,
            buttonColor: .white.opacity(0.1),
            buttonTextColor: .white,
            buttonShadowColor: .black,
            screenColor: Color("bg-screen-green"),
            screenTextColor: Color("text-screen-green"),
            screenOutlineColor: Color("outline-screen-CF-11"),
            playerImage: "player-CF-504",
            cassetteBgImage: "bg-cassette"
        ),
        PlayerSkin(
            name: "CF-D6C",  // 名称作为唯一标识
            year: "1984",
            description: "磁带播放器的老大哥，专为专业用户生产",
            coverImage: "cover-CF-D6C",
            panelColor: Color("bg-panel-dark"),
            buttonColor: Color("button-dark"),
            buttonTextColor: .white,
            buttonShadowColor: Color("shadow-button-dark"),
            screenColor: Color("bg-screen-blue"),
            screenTextColor: Color("text-screen-blue"),
            screenOutlineColor: .black,
            playerImage: "player-CF-D6C",
            cassetteBgImage: "bg-cassette"
        ),
        PlayerSkin(
            name: "CF-DT1",  // 名称作为唯一标识
            year: "1993",
            description: "经典动漫中反复出现的播放器",
            coverImage: "cover-CF-DT1",
            panelColor: Color("bg-panel-dark"),
            buttonColor: Color("button-dark"),
            buttonTextColor: .white,
            buttonShadowColor: Color("shadow-button-dark"),
            screenColor: Color("bg-screen-green"),
            screenTextColor: Color("text-screen-green"),
            screenOutlineColor: .black,
            playerImage: "player-CF-DT1",
            cassetteBgImage: "bg-cassette"
        )
    ]
    
    // 根据名称获取播放器皮肤
    static func playerSkin(named name: String) -> PlayerSkin? {
        return playerSkins.first(where: { $0.name == name })
    }
    
    // 检查是否为默认免费皮肤
    func isFreeDefaultSkin() -> Bool {
        return ["CF-DEMO, CF-L2, CF-DT1"].contains(self.name)
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

    // 磁带皮肤集合
    static let cassetteSkins: [CassetteSkin] = [
        
        CassetteSkin(
            name: "CFT-DEMO",  // 名称作为唯一标识
            year: "2025",
            description: "演示磁带皮肤",
            coverImage: "CF-001",
            cassetteImage: "CFT-DEMO",
            cassetteHole: "hole"
        ),
        CassetteSkin(
            name: "CFT-TRA",  // 名称作为唯一标识
            year: "1988",
            description: "经典透明磁带皮肤",
            coverImage: "CF-001",
            cassetteImage: "CFT-TRA",
            cassetteHole: "holeDark"
        ),
        CassetteSkin(
            name: "CFT-C60",  // 名称作为唯一标识
            year: "1988",
            description: "C60录音磁带皮肤",
            coverImage: "CF-001",
            cassetteImage: "CFT-C60",
            cassetteHole: "holeDark"
        )
    ]

    // 根据名称获取磁带皮肤
    static func cassetteSkin(named name: String) -> CassetteSkin? {
        return cassetteSkins.first(where: { $0.name == name })
    }
    
    // 检查是否为默认免费皮肤
    func isFreeDefaultSkin() -> Bool {
        return ["CFT-DEMO", "CFT-TRA"].contains(self.name)
    }
}

// MARK: - 皮肤工具类
@MainActor
class SkinHelper {
    
    /// 检查播放器皮肤是否已拥有
    static func isPlayerSkinOwned(_ skinName: String, storeManager: StoreManager) -> Bool {
        let skin = PlayerSkin.playerSkin(named: skinName)
        return skin?.isFreeDefaultSkin() == true || storeManager.ownsPlayerSkin(skinName)
    }
    
    /// 检查磁带皮肤是否已拥有
    static func isCassetteSkinOwned(_ skinName: String, storeManager: StoreManager) -> Bool {
        let skin = CassetteSkin.cassetteSkin(named: skinName)
        return skin?.isFreeDefaultSkin() == true || storeManager.ownsCassetteSkin(skinName)
    }
    
    /// 获取播放器皮肤价格
    static func getPlayerSkinPrice(_ skinName: String, storeManager: StoreManager) -> String {
        let skin = PlayerSkin.playerSkin(named: skinName)
        if skin?.isFreeDefaultSkin() == true {
            return "免费"
        }
        
        let productID = getPlayerSkinProductID(skinName)
        return storeManager.getProductPrice(for: productID)
    }
    
    /// 获取磁带皮肤价格
    static func getCassetteSkinPrice(_ skinName: String, storeManager: StoreManager) -> String {
        let skin = CassetteSkin.cassetteSkin(named: skinName)
        if skin?.isFreeDefaultSkin() == true {
            return "免费"
        }
        
        let productID = getCassetteSkinProductID(skinName)
        return storeManager.getProductPrice(for: productID)
    }
    
    /// 根据播放器皮肤名称获取产品ID
    static func getPlayerSkinProductID(_ skinName: String) -> String {
        switch skinName {
        case "CF-DT1": return StoreManager.ProductIDs.cfDT1
        case "CF-D6C": return StoreManager.ProductIDs.cfD6C
        case "CF-L2": return StoreManager.ProductIDs.cfL2
        case "CF-22": return StoreManager.ProductIDs.cf22
        case "CF-504": return StoreManager.ProductIDs.cf504
        default: return ""
        }
    }
    
    /// 根据磁带皮肤名称获取产品ID
    static func getCassetteSkinProductID(_ skinName: String) -> String {
        switch skinName {
        case "CFT-C60": return StoreManager.ProductIDs.cftC60
        case "CFT-TRA": return StoreManager.ProductIDs.cftTRA
        default: return ""
        }
    }
}
