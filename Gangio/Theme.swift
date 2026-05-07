//
//  Theme.swift
//  Gangio
//
//  Created & Design by github.com/benyigit on 21/04/2026.
//

import Foundation
import SwiftUI
import CodableWrapper
import Parsing
import Types
import Sentry
import OSLog

let themeLogger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "Theme")

func parseHex(hex: String) -> (Double, Double, Double, Double) {
    let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var int: UInt64 = 0
    Scanner(string: hex).scanHexInt64(&int)
    let r, g, b, a: UInt64
    switch hex.count {
        case 3: // RGB (12-bit)
            (r, g, b, a) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17, 255)
        case 6: // RGB (24-bit)
            (r, g, b, a) = (int >> 16, int >> 8 & 0xFF, int & 0xFF, 255)
        case 8: // RGBA (32-bit)
            (r, g, b, a) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b, a) = (1, 1, 1, 0)
    }
    
    return (
        Double(r) / 255,
        Double(g) / 255,
        Double(b) / 255,
        Double(a) / 255
    )
}

enum ConstantType: String, Hashable, Equatable {
    case deg, grad, rad, turn
}

let angleParser = Parse(input: Substring.self) {
    Double.parser()
    OneOf {
        "deg".map { ConstantType.deg }
        "grad".map { ConstantType.grad }
        "rad".map { ConstantType.rad }
        "turn".map { ConstantType.turn }
    }
}

enum DirectionType: String, Hashable, Equatable {
    case left, right, top, bottom
}

let directionParser = Parse(input: Substring.self) {
    OneOf {
        "left".map { DirectionType.left }
        "right".map { DirectionType.right }
        "top".map { DirectionType.top }
        "bottom".map { DirectionType.bottom }
    }
}

enum ColorType: Hashable, Equatable {
    case name(String)
    case hex(String)
    case rgba(Int, Int, Int, Int)
}

let colorParser = Parse(input: Substring.self) {
    Skip { Many { " " } }
    
    OneOf {
        Parse {
            "#"
            CharacterSet(charactersIn: "ABCDEFabcdef1234567890")
        }.map { ColorType.hex(String($0)) }

        Parse {
            "rgb("
            Many(3) {
                Int.parser()
            } separator: {
                Many { " " }
                ","
                Many { " " }
            }
            ")"
        }.map { cs in ColorType.rgba(cs[0], cs[1], cs[2], 255) }
        
        CharacterSet.alphanumerics
            .map { ColorType.name(String($0)) }
    }
    
    Skip { Many { " " } }
}

struct Length: Hashable, Equatable {
    enum LengthType {
        case px
    }
    
    var amount: Int
    var type: LengthType
}

let lengthParser = Parse(input: Substring.self) {
    Length(amount: $0, type: $1)
} with: {
    Digits()
    OneOf {
        "px".map { Length.LengthType.px }
    }
}

let percentageParser = Parse(input: Substring.self) {
    Digits()
    "%"
}

enum PercentageType: Hashable, Equatable {
    case length(Length)
    case percentage(Int)
    
    var toPercentage: Int? {
        switch self {
            case .length:
                return nil
            case .percentage(let p):
                return p
        }
    }
    
    var amount: Int {
        switch self {
            case .length(let length):
                return length.amount
            case .percentage(let int):
                return int
        }
    }
}

struct ColorStop: Hashable, Equatable {
    var color: ColorType
    var percentage: PercentageType?
}

struct MultiDirectionType: Hashable, Equatable {
    var a: DirectionType
    var b: DirectionType?
}

enum AngleType: Hashable, Equatable {
    case constant(Double, ConstantType)
    case direction(MultiDirectionType)
    
    var isDirection: Bool {
        switch self {
            case .constant:
                return false
            case .direction:
                return true
        }
    }
}

struct LinearGradiant: Hashable, Equatable {
    var angle: AngleType?
    var stops: [ColorStop]
}

let linearGradiantParser = Parse(input: Substring.self) { inp in
    LinearGradiant(angle: inp.0, stops: inp.1)
} with: {
    "linear-gradient("
    
    Optionally {
        Skip { Many { " " } }
        
        OneOf {
            angleParser.map { AngleType.constant($0.0, $0.1) }
            Parse {
                "to"
                
                Skip { Many { " " } }
                
                directionParser
                
                Skip { Many { " " } }
                
                Optionally {
                    directionParser
                }
            }.map { AngleType.direction(MultiDirectionType(a: $0.0, b: $0.1)) }
        }
        
        Skip { Many { " " } }
        
        ","
    }

    Skip { Many { " " } }
    
    Many(2...) {
        Parse {
            colorParser
            Skip { Many { " " } }
            Optionally {
                OneOf {
                    lengthParser.map(PercentageType.length)
                    percentageParser.map(PercentageType.percentage)
                }
            }
        }.map { (c, p) in ColorStop(color: c, percentage: p) }
    } separator: {
        Many { " " }
        ","
        Many { " " }
    }
    
    Skip { Many { " " } }
    
    ")"
}

let variableColorParser = Parse(input: Substring.self) {
    "var("
    Prefix(1...) { c in c != ")" }.map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
    ")"
}

enum CssColor: Hashable, Equatable {
    case linear_gradiant(LinearGradiant)
    case simple(ColorType)
    case variable(String)
    
    func asLinearGradient() -> LinearGradiant? {
        switch self {
            case .linear_gradiant(let linearGradiant):
                return linearGradiant
            default:
                return nil
        }
    }
}

let CSSColorParser = Parse(input: Substring.self) {
    OneOf {
        variableColorParser.map { CssColor.variable(String($0)) }
        linearGradiantParser.map(CssColor.linear_gradiant)
        colorParser.map(CssColor.simple)
    }
}

func resolveColor(color: ColorType) -> Color {
    switch color {
        case .name(let name):
            switch name.lowercased() {
                case "red":
                    return .red
                case "green":
                    return .green
                case "blue":
                    return .blue
                case "purple":
                    return Color(red: 128.0 / 255.0, green: 0, blue: 128.0 / 255.0)
                case "orange":
                    return Color(red: 1, green: 165.0 / 255, blue: 0)
                default:
                    return .black
            }
            
        case .hex(let hex):
            let (r, g, b, a) = parseHex(hex: String(hex))
            return Color(red: r, green: g, blue: b, opacity: a)
            
        case .rgba(let r, let g, let b, let a):
            return Color(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

func resolveVariable(currentTheme: Theme, name: String) -> Color {
    switch name {
        case "--accent":
            return currentTheme.accent.color
        case "--foreground":
            return currentTheme.foreground.color
        case "--background":
            return currentTheme.background.color
        default:
            return .black
    }
}

func unitSquareIntersectionPoint(angle: Double) -> UnitPoint {
    var angle = angle
    
    while angle > 360.0 {
        angle -= 360.0
    }
    
    while angle < 0.0 {
        angle += 360.0
    }
    
    if angle < 45.0 || angle >= 315 {
        var degreeToConsider = angle
        
        if degreeToConsider < 45.0 {
            degreeToConsider = angle +  360.0
        }
        
        let degreeProportion = (degreeToConsider - 315.0) / 90.0
        
        return UnitPoint(x: 1.0, y: 1.0 - degreeProportion)
    } else if angle < 135.0 {
        
        let degreeProportion = (angle - 45.0) / 90.0
        
        return UnitPoint(x: 1.0 - degreeProportion, y: 0.0)
    } else if angle < 225.0 {
        let degreeProportion = (angle - 135) / 90.0
        
        return UnitPoint(x: 0.0, y: degreeProportion)
    } else if angle < 315.0 {
        
        let degreeProportion = (angle - 225) / 90.0
        
        return UnitPoint(x: degreeProportion, y: 1.0)
    }
    
    return .zero
}

func directionToUnits(direction: MultiDirectionType) -> (UnitPoint, UnitPoint) {
    switch (direction.a, direction.b) {
        case (.left, .top), (.top, .left):
            return (.bottomTrailing, .topLeading)
        case (.left, .bottom), (.bottom, .left):
            return (.topTrailing, .bottomLeading)
        case (.right, .top), (.top, .right):
            return (.bottomLeading, .topTrailing)
        case (.right, .bottom), (.bottom, .right):
            return (.topLeading, .bottomTrailing, )
        case (.left, nil):
            return (.trailing, .leading)
        case (.right, nil):
            return (.leading, .trailing)
        case (.top, nil):
            return (.bottom, .top)
        case (.bottom, nil):
            return (.top, .bottom)
        default:
            return directionToUnits(direction: MultiDirectionType(a: direction.a, b: nil))
    }
}

func parseCSSColorToShapeStyle(currentTheme theme: Theme, input: String) -> AnyShapeStyle {
    let output = parseCSSColor(input: input)
    
    return convertCSSColorToShapeStyle(currentTheme: theme, input: output)
}

func parseCSSColor(input: String, default d: CssColor? = nil) -> CssColor {
    do {
        return try CSSColorParser.parse(input)
    } catch let e {
        SentrySDK.capture(error: e)
        themeLogger.error("CSS Parser error: \(e)")
        return d ?? CssColor.simple(.hex("0xFFFFFFFF"))
    }
}

func convertCSSColorToShapeStyle(currentTheme theme: Theme, input: CssColor) -> AnyShapeStyle {
    switch input {
        case .simple(let color):
            return AnyShapeStyle(resolveColor(color: color))
            
        case .variable(let name):
            return AnyShapeStyle(resolveVariable(currentTheme: theme, name: name))
            
        case .linear_gradiant(let grad):
            var start: UnitPoint
            var end: UnitPoint
            
            switch grad.angle {
                case .direction(let direction):
                    (start, end) = directionToUnits(direction: direction)
                    
                case .constant(let value, let ty):
                    switch ty {
                        case .deg:
                            start = unitSquareIntersectionPoint(angle: value + 90.0)
                            end = unitSquareIntersectionPoint(angle: value - 90.0)
                        case .grad:
                            start = unitSquareIntersectionPoint(angle: (value * 0.9) + 90.0)
                            end = unitSquareIntersectionPoint(angle: (value * 0.9) - 90.0)
                            
                        case .rad:
                            start = unitSquareIntersectionPoint(angle: (value * (180/Double.pi)) + 90.0)
                            end = unitSquareIntersectionPoint(angle: (value * (180/Double.pi)) - 90.0)
                            
                        case .turn:
                            start = unitSquareIntersectionPoint(angle: (value * 360.0) + 90.0)
                            end = unitSquareIntersectionPoint(angle: (value * 360.0) - 90.0)
                    }
                case nil:
                    start = .top
                    end = .bottom
            }
            
            if grad.stops.allSatisfy({ $0.percentage?.toPercentage != nil }) {
                let stops: [Gradient.Stop] = grad.stops.map { stop in Gradient.Stop(color: resolveColor(color: stop.color), location: CGFloat(Double(stop.percentage!.toPercentage!) / 100.0)) }
                return AnyShapeStyle(LinearGradient(stops: stops, startPoint: start, endPoint: end))
            } else {
                let colors = grad.stops.map { resolveColor(color: $0.color) }
                
                return AnyShapeStyle(LinearGradient(colors: colors, startPoint: start, endPoint: end))
            }
    }
}

func convertCSSColorToString(input: CssColor) -> String {
    var parts: [String] = []
    
    switch input {
        case .linear_gradiant(let linearGradiant):
            parts.append("linear-gradient(")
            
            if let angle = linearGradiant.angle {
                switch angle {
                    case .constant(let double, let constantType):
                        parts.append("\(Int(double))\(constantType)")
                        
                    case .direction(let direction):
                        parts.append("to")
                        parts.append(direction.a.rawValue)
                        
                        if let b = direction.b {
                            parts.append(b.rawValue)
                        }
                }
                
                parts.append(",")
            }
            
            for stop in linearGradiant.stops {
                parts.append(convertColorTypeToString(input: stop.color))
                
                if let percentage = stop.percentage {
                    switch percentage {
                        case .length(let length):
                            parts.append("\(Int(length.amount))\(length.type)")
                        case .percentage(let int):
                            parts.append("\(int)%")
                    }
                }
                
                parts.append(",")
            }
            
            _ = parts.popLast()
            
            parts.append(")")
            
        case .simple(let colorType):
            parts.append(convertColorTypeToString(input: colorType))
        case .variable(let string):
            parts.append(contentsOf: ["var(", string, ")"])
    }
    
    return parts.joined(separator: " ")
}

func convertCSSColorToColorType(input: String) -> ColorType {
    do {
        return try colorParser.parse(input)
    } catch {
        print(error)
        
        return .hex("FFFFFFFF")
    }
}

func convertColorTypeToString(input: ColorType) -> String {
    switch input {
        case .name(let string):
            return string
        case .hex(let string):
            return "#\(string)"
        case .rgba(let r, let g, let b, let a):
            let r = String(r, radix: 16, uppercase: true).padding(toLength: 2, withPad: "0", startingAt: 0)
            let g = String(g, radix: 16, uppercase: true).padding(toLength: 2, withPad: "0", startingAt: 0)
            let b = String(b, radix: 16, uppercase: true).padding(toLength: 2, withPad: "0", startingAt: 0)
            let a = String(a, radix: 16, uppercase: true).padding(toLength: 2, withPad: "0", startingAt: 0)
            
            return "#\(r)\(g)\(b)\(a)"
    }
}

@Codable
public struct ThemeColor: Equatable, ShapeStyle, View {
    public var r: Double
    public var g: Double
    public var b: Double
    public var a: Double

    public init(hex: String) {
        (r, g, b, a) = parseHex(hex: hex)
    }

    public mutating func set(with: Color.Resolved) {
        self.r = Double(with.red)

        if self.r == Double.infinity {
            self.r = 1.0
        }

        self.g = Double(with.green)

        if self.g == Double.infinity {
            self.g = 1.0
        }

        self.b = Double(with.blue)

        if self.b == Double.infinity {
            self.b = 1.0
        }

        self.a = Double(with.opacity)

        if self.a == Double.infinity {
            self.a = 1.0
        }

    }

    public func resolve(in environment: EnvironmentValues) -> Color.Resolved {
        color.resolve(in: environment)
    }

    public var color: Color {
        Color(red: r, green: g, blue: b, opacity: a)
    }
    
    public var uiColor: UIColor {
        UIColor(color)
    }
    
    public var hex: String {
        let r = String(Int(self.r * 255), radix: 16, uppercase: true)
        let g = String(Int(self.g * 255), radix: 16, uppercase: true)
        let b = String(Int(self.b * 255), radix: 16, uppercase: true)
        let a = String(Int(self.a * 255), radix: 16, uppercase: true)
        
        return "#\(r)\(g)\(b)\(a)"
    }

    public static var white: ThemeColor = ThemeColor(hex: "#FFFFFFFF")
    public static var black: ThemeColor = ThemeColor(hex: "#000000FF")
}

@Codable
public struct Theme: Codable, Equatable {
    public var accent: ThemeColor = ThemeColor(hex: "#FD6671FF")
    public var background: ThemeColor = ThemeColor(hex: "#F6F6F6FF")
    public var background2: ThemeColor = ThemeColor(hex: "#FFFFFFFF")
    public var background3: ThemeColor = ThemeColor(hex: "#F1F1F1FF")
    public var background4: ThemeColor = ThemeColor(hex: "#4D4D4DFF")
    public var foreground: ThemeColor = ThemeColor(hex: "#000000FF")
    public var foreground2: ThemeColor = ThemeColor(hex: "#1F1F1FFF")
    public var foreground3: ThemeColor = ThemeColor(hex: "#3A3A3AFF")
    public var messageBox: ThemeColor = ThemeColor(hex: "#F1F1F1FF")
    public var topBar: ThemeColor = ThemeColor(hex: "#FFFFFFEE")
    public var error: ThemeColor = ThemeColor(hex: "#ED4245")
    public var success: ThemeColor = ThemeColor(hex: "#91b362")
    public var mention: ThemeColor = ThemeColor(hex: "#FBFF000F")
    public var shouldFollowiOSTheme: Bool = false

    public static var light: Theme {
        Theme(
            accent: ThemeColor(hex: "#5865F2FF"),
            background: ThemeColor(hex: "#FFFFFFFF"),
            background2: ThemeColor(hex: "#F2F3F5FF"),
            background3: ThemeColor(hex: "#E3E5E8FF"),
            background4: ThemeColor(hex: "#EBEDEF"),
            foreground: ThemeColor(hex: "#060607FF"),
            foreground2: ThemeColor(hex: "#4E5058FF"),
            foreground3: ThemeColor(hex: "#80848EFF"),
            messageBox: ThemeColor(hex: "#EBEDEEFF"),
            topBar: ThemeColor(hex: "#FFFFFFEE"),
            error: ThemeColor(hex: "#ED4245"),
            success: ThemeColor(hex: "#23A559"),
            mention: ThemeColor(hex: "#5865F20F"),
            shouldFollowiOSTheme: false
        )
    }

    public static var dark: Theme {
        Theme(
            accent: ThemeColor(hex: "#5865F2FF"),
            background: ThemeColor(hex: "#1E1F22FF"),
            background2: ThemeColor(hex: "#2B2D31FF"),
            background3: ThemeColor(hex: "#232428FF"),
            background4: ThemeColor(hex: "#383A40FF"),
            foreground: ThemeColor(hex: "#F2F3F5FF"),
            foreground2: ThemeColor(hex: "#B5BAC1FF"),
            foreground3: ThemeColor(hex: "#6D6F78FF"),
            messageBox: ThemeColor(hex: "#313338FF"),
            topBar: ThemeColor(hex: "#2B2D31EE"),
            error: ThemeColor(hex: "#ED4245"),
            success: ThemeColor(hex: "#23A559"),
            mention: ThemeColor(hex: "#5865F20F"),
            shouldFollowiOSTheme: false
        )
    }
}

extension Theme {
    /// This function takes a ThemeColor and determines if it is "light" or "dark", via a true/false flag.
    /// True means "light", and False means "dark".
    static func isLightOrDark(_ color: ThemeColor) -> Bool {
        let (r, g, b) = (color.r * 255, color.g * 255, color.b * 255)
        
        // https://alienryderflex.com/hsp.html
        // basically percieved brightness > sqrt((1*255^2) / 4)
        let hsp = sqrt((0.299 * (r * r)) + (0.587 * (g * g)) + (0.114 * (b * b)))
        return hsp > 127.5
    }
}
