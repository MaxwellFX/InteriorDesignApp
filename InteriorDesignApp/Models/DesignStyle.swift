import Foundation
import SwiftUI

struct DesignStyle: Identifiable, Equatable {
    let id: String
    let name: String
    let prompt: String
    let iconName: String
    let color: Color

    // Implement Equatable by comparing IDs
    static func == (lhs: DesignStyle, rhs: DesignStyle) -> Bool {
        return lhs.id == rhs.id
    }
    
    static let styles: [DesignStyle] = [
        DesignStyle(
            id: "scandinavian",
            name: "北欧风格",
            prompt: "将房间装饰为北欧风格，使用浅色木材，白色墙壁，简约家具和绿植",
            iconName: "house",
            color: Color.blue
        ),
        DesignStyle(
            id: "modern",
            name: "现代风格",
            prompt: "将这个房间改造成现代设计风格，具有干净的线条，中性色调和独特的照明",
            iconName: "sparkles",
            color: Color.indigo
        ),
        DesignStyle(
            id: "bohemian",
            name: "波西米亚风格",
            prompt: "用波西米亚装饰风格装饰这个房间，具有层次感的纺织品，植物和不拘一格的家具",
            iconName: "leaf",
            color: Color.green
        ),
        DesignStyle(
            id: "industrial",
            name: "工业风格",
            prompt: "创建一个工业风格的房间，有裸露的砖墙，金属装置和皮革家具",
            iconName: "gear",
            color: Color.gray
        ),
        DesignStyle(
            id: "minimalist",
            name: "极简风格",
            prompt: "以极简主义风格设计这个房间，只有必要的家具，干净的表面和单色调色板",
            iconName: "square",
            color: Color.black
        ),
        DesignStyle(
            id: "farmhouse",
            name: "乡村风格",
            prompt: "将这个房间改造成乡村风格，使用回收木材，复古配饰和舒适的家具，房间内部要做精装修",
            iconName: "house.fill",
            color: Color.brown
        )
    ]
} 
