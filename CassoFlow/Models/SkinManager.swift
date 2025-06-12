import SwiftUI

// 创建一个新的皮肤模型文件
struct PlayerSkin: Identifiable {
    let id = UUID()
    let name: String
    let year: String
    let description: String
    let coverImage: String
    let price: Int
    var isOwned: Bool
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
            price: 12,
            isOwned: true,
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
            price: 12,
            isOwned: false,
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
            description: "1987",
            coverImage: "cover-CF-22",
            price: 12,
            isOwned: false,
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
            description: "1987",
            coverImage: "CF-101",
            price: 12,
            isOwned: false,
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
            price: 12,
            isOwned: true,
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
            price: 12,
            isOwned: true,
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
        // 添加更多播放器皮肤...
    ]
    
    // 根据名称获取播放器皮肤
    static func playerSkin(named name: String) -> PlayerSkin? {
        return playerSkins.first(where: { $0.name == name })
    }
}

struct CassetteSkin: Identifiable {
    let id = UUID()
    let name: String
    let year: String
    let description: String
    let coverImage: String
    let price: Int
    var isOwned: Bool
    let cassetteImage: String
    let cassetteHole: String


// 播放器皮肤集合
static let cassetteSkins: [CassetteSkin] = [
    
    CassetteSkin(
        name: "CFT-DEMO",  // 名称作为唯一标识
        year: "2025",
        description: "1988",
        coverImage: "CF-001",
        price: 12,
        isOwned: true,
        cassetteImage: "CFT-DEMO",
        cassetteHole: "hole"
    ),
    CassetteSkin(
        name: "CFT-TRA",  // 名称作为唯一标识
        year: "1988",
        description: "1988",
        coverImage: "CF-001",
        price: 12,
        isOwned: true,
        cassetteImage: "CFT-TRA",
        cassetteHole: "holeDark"
    ),
    CassetteSkin(
        name: "CFT-C60",  // 名称作为唯一标识
        year: "1988",
        description: "1988",
        coverImage: "CF-001",
        price: 12,
        isOwned: true,
        cassetteImage: "CFT-C60",
        cassetteHole: "holeDark"
    )
    
]

    // 根据名称获取磁带皮肤
    static func casetteSkin(named name: String) -> CassetteSkin? {
        return cassetteSkins.first(where: { $0.name == name })
    }
}

