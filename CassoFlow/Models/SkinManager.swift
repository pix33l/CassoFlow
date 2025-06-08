import SwiftUI

// 创建一个新的皮肤模型文件
struct PlayerSkin: Identifiable {
    let id = UUID()
    let name: String
    let year: String
    let description: String
    let imageName: String
    let price: Int
    var isOwned: Bool
    let backgroundColor: Color
    let buttonColor: Color
    let buttonTextColor: Color
    let buttonOutlineColor: Color
    let screenColor: Color
    let screenTextColor: Color
    let screenOutlineColor: Color
    let playerImage: String
    let cassetteImage: String
    let cassetteHole: String
    
    // 播放器皮肤集合
    static let playerSkins: [PlayerSkin] = [
        
        PlayerSkin(
            name: "CF-0",  // 名称作为唯一标识
            year: "1988",
            description: "1988",
            imageName: "CF-001",
            price: 12,
            isOwned: true,
            backgroundColor: Color("cassetteLight"),
            buttonColor: Color("cassetteLight"),
            buttonTextColor: Color("cassetteDark"),
            buttonOutlineColor: Color("cassetteDark"),
            screenColor: Color("cassetteLight"),
            screenTextColor: Color("cassetteDark"),
            screenOutlineColor: Color("cassetteDark"),
            playerImage: "cover-CF-001",
            cassetteImage: "cassette",
            cassetteHole: "hole"
        ),
        PlayerSkin(
            name: "CF-L2",  // 名称作为唯一标识
            year: "1985",
            description: "1985",
            imageName: "CF-L2",
            price: 12,
            isOwned: false,
            backgroundColor: Color("bg-CF-11"),
            buttonColor: Color("bg-button-CF-11"),
            buttonTextColor: Color("text-screen-CF-11"),
            buttonOutlineColor: Color("bg-button-CF-11"),
            screenColor: Color("bg-screen-orange"),
            screenTextColor: Color("text-screen-orange"),
            screenOutlineColor: Color("outline-screen-CF-11"),
            playerImage: "cover-CF-L2",
            cassetteImage: "cassetteDark",
            cassetteHole: "holeDark"
        ),
        PlayerSkin(
            name: "CF-22",  // 名称作为唯一标识
            year: "1984",
            description: "1987",
            imageName: "CF-101",
            price: 12,
            isOwned: false,
            backgroundColor: .black,
            buttonColor: .white.opacity(0.1),
            buttonTextColor: .white,
            buttonOutlineColor: .black,
            screenColor: Color("bg-screen-CF-11"),
            screenTextColor: Color("text-screen-CF-11"),
            screenOutlineColor: Color("outline-screen-CF-11"),
            playerImage: "cover-CF-22",
            cassetteImage: "cassetteDark",
            cassetteHole: "holeDark"
        ),
        PlayerSkin(
            name: "CF-504",  // 名称作为唯一标识
            year: "1987",
            description: "1987",
            imageName: "CF-101",
            price: 12,
            isOwned: false,
            backgroundColor: .black,
            buttonColor: .white.opacity(0.1),
            buttonTextColor: .white,
            buttonOutlineColor: .black,
            screenColor: Color("bg-screen-CF-11"),
            screenTextColor: Color("text-screen-CF-11"),
            screenOutlineColor: Color("outline-screen-CF-11"),
            playerImage: "cover-CF-504",
            cassetteImage: "cassetteDark",
            cassetteHole: "holeDark"
        ),
        PlayerSkin(
            name: "CF-DT1",  // 名称作为唯一标识
            year: "1993",
            description: "1993",
            imageName: "CF-101",
            price: 12,
            isOwned: true,
            backgroundColor: .black,
            buttonColor: .white.opacity(0.1),
            buttonTextColor: .white,
            buttonOutlineColor: .clear,
            screenColor: Color("bg-screen-CF-11"),
            screenTextColor: Color("text-screen-CF-11"),
            screenOutlineColor: .black,
            playerImage: "cover-CF-DT1",
            cassetteImage: "cassetteDark",
            cassetteHole: "holeDark"
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
    let imageName: String
    let price: Int
    var isOwned: Bool
    let cassetteImage: String
    let cassetteHole: String


// 播放器皮肤集合
static let cassetteSkins: [CassetteSkin] = [
    
    CassetteSkin(
        name: "CFH-60",  // 名称作为唯一标识
        year: "1988",
        description: "1988",
        imageName: "CF-001",
        price: 12,
        isOwned: true,
        cassetteImage: "cassette",
        cassetteHole: "hole"
    ),
    
]

    // 根据名称获取磁带皮肤
    static func casetteSkin(named name: String) -> CassetteSkin? {
        return cassetteSkins.first(where: { $0.name == name })
    }
}

