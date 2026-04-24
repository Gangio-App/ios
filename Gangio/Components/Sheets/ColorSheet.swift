//
//  ColourSheet.swift
//  Gangio
//
//  Created by Angelo on 27/05/2025.
//

import SwiftUI


struct ColorSheet: View {
    @Environment(\.self) var environment
    @EnvironmentObject var viewState: ViewState

    enum Selection {
        case linear, simple, variable
    }
    
    var initial: CssColor
    @State var pickerSelection: Selection
    @Binding var current: CssColor
    
    init(value: Binding<CssColor>) {
        switch value.wrappedValue {
            case .linear_gradiant:
                self.pickerSelection = .linear
            case .simple:
                self.pickerSelection = .simple
            case .variable:
                self.pickerSelection = .variable
        }
        
        self.initial = value.wrappedValue
        self._current = value
        
    }
    
    func convertSwiftUIColor(color: Color) -> ColorType {
        let resolved = color.resolve(in: environment)
        let v = ColorType.rgba(Int(resolved.red * 255), Int(resolved.green * 255), Int(resolved.blue * 255), Int(resolved.opacity * 255))
        return v
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Picker("Colour Style", selection: $pickerSelection) {
                    Text("Simple").tag(Selection.simple)
                    Text("Gradient").tag(Selection.linear)
                    Text("Variable").tag(Selection.variable)
                }
                .pickerStyle(.segmented)
                .onChange(of: pickerSelection) { oldValue, newValue in
                    switch (oldValue, newValue) {
                        case (.linear, .simple):
                            if case .linear_gradiant(let grad) = current, let first = grad.stops.first {
                                current = .simple(first.color)
                            }
                        case (.simple, .linear):
                            if case .simple(let colorType) = current {
                                current = .linear_gradiant(.init(stops: [.init(color: colorType)]))
                            }
                        case (_, .variable):
                            current = .variable("--accent")
                        case (.variable, .linear):
                            if case .variable(let string) = current {
                                current = .linear_gradiant(LinearGradiant(stops: [ColorStop(color: convertSwiftUIColor(color: resolveVariable(currentTheme: viewState.theme, name: string)))]))
                            }
                        case (.variable, .simple):
                            if case .variable(let string) = current {
                                current = .simple(convertSwiftUIColor(color: resolveVariable(currentTheme: viewState.theme, name: string)))
                            }
                        default:
                            ()
                    }
                }
                
                RoundedRectangle(cornerRadius: 16)
                    .frame(height: 100)
                    .foregroundStyle(convertCSSColorToShapeStyle(currentTheme: viewState.theme, input: current))
                
                switch current {
                    case .linear_gradiant(var linearGradiant):
                        VStack(spacing: 8) {
                            Picker("Angle Type", selection: Binding<String>(get: {
                                switch linearGradiant.angle {
                                    case .constant:
                                        return "constant"
                                    case .direction:
                                        return "direction"
                                    case nil:
                                        return "constant"
                                }
                            }, set: { value in
                                switch value {
                                    case "constant":
                                        linearGradiant.angle = .constant(0.0, .deg)
                                    case "direction":
                                        linearGradiant.angle = .direction(MultiDirectionType(a: .right))
                                    default:
                                        ()
                                }
                                
                                current = .linear_gradiant(linearGradiant)

                            })) {
                                Text("Constant")
                                    .tag("constant")
                                Text("Direction")
                                    .tag("direction")
                            }
                            .pickerStyle(.segmented)
                            
                            switch linearGradiant.angle {
                                case .constant(let double, let constantType):
                                    HStack {
                                        TextField("Angle", value: Binding(get: {
                                            double
                                        }, set: { double in
                                            linearGradiant.angle = .constant(double, constantType)
                                            current = .linear_gradiant(linearGradiant)
                                        }), format: .number)

                                        Picker("Constant Type", selection: Binding(get: {
                                            return constantType
                                        }, set: { constantType in
                                            linearGradiant.angle = .constant(double, constantType)
                                            current = .linear_gradiant(linearGradiant)
                                        })) {
                                            Text("Deg").tag(ConstantType.deg)
                                            Text("Grad").tag(ConstantType.grad)
                                            Text("Rad").tag(ConstantType.rad)
                                            Text("Turn").tag(ConstantType.turn)
                                        }
                                    }
                                case .direction(let direction):
                                    Picker("Direction", selection: Binding(get: {
                                        return direction
                                    }, set: { direction in
                                        linearGradiant.angle = .direction(direction)
                                        current = .linear_gradiant(linearGradiant)
                                    })) {
                                        Text("Top Left").tag(MultiDirectionType(a: .top, b: .left))
                                        Text("Top").tag(MultiDirectionType(a: .top, b: nil))
                                        Text("Top Right").tag(MultiDirectionType(a: .top, b: .right))
                                        Text("Right").tag(MultiDirectionType(a: .right, b: nil))
                                        Text("Bottom Right").tag(MultiDirectionType(a: .bottom, b: .right))
                                        Text("Bottom").tag(MultiDirectionType(a: .bottom, b: nil))
                                        Text("Bottom Left").tag(MultiDirectionType(a: .bottom, b: .left))
                                        Text("Left").tag(MultiDirectionType(a: .left, b: nil))
                                    }
                                case nil:
                                    HStack {
                                        TextField("Angle", value: Binding(get: {
                                            90.0
                                        }, set: { double in
                                            linearGradiant.angle = .constant(double, .deg)
                                            current = .linear_gradiant(linearGradiant)
                                        }), format: .number)
                                        
                                        Picker("Constant Type", selection: Binding(get: {
                                            return ConstantType.deg
                                        }, set: { constantType in
                                            linearGradiant.angle = .constant(0.0, constantType)
                                            current = .linear_gradiant(linearGradiant)
                                        })) {
                                            Text("Deg").tag(ConstantType.deg)
                                            Text("Grad").tag(ConstantType.grad)
                                            Text("Rad").tag(ConstantType.rad)
                                            Text("Turn").tag(ConstantType.turn)
                                        }
                                    }
                            }
                            
                            HStack {
                                Text("Colours")
                                    .foregroundStyle(viewState.theme.foreground2)
                                
                                Spacer()
                                
                                Button {
                                    var grad = current.asLinearGradient()!
                                    grad.stops.append(.init(color: .name("")))
                                    current = .linear_gradiant(grad)
                                } label: {
                                    Image(systemName: "plus")
                                        .foregroundStyle(viewState.theme.success)
                                }
                            }
                            .padding(.leading, 8)
                            .padding(.top, 16)
                            
                            ForEach(Array(linearGradiant.stops.enumerated()), id: \.offset) { (i, stop) in
                                HStack {
                                    TextField("Stop \(i + 1)", text: Binding(get: {
                                        convertColorTypeToString(input: stop.color)
                                    }, set: { value in
                                        var grad = current.asLinearGradient()!
                                        var before = grad.stops[i]
                                        before.color = convertCSSColorToColorType(input: value)
                                        grad.stops[i] = before
                                        current = .linear_gradiant(grad)
                                    }))
                                    .padding(16)
                                    .background(viewState.theme.background3, in: RoundedRectangle(cornerRadius: 8))
                                    
                                    TextField("Percentage", value: Binding(get: {
                                        stop.percentage?.amount ?? 0
                                    }, set: { value in
                                            
                                    }), format: .number)
                                    .padding(16)
                                    .frame(width: 64)
                                    .background(viewState.theme.background3, in: RoundedRectangle(cornerRadius: 8))
                                    
                                    Picker("Percentage Type", selection: Binding(get: {
                                        switch stop.percentage {
                                            case .length:
                                                return "px"
                                            case .percentage, nil:
                                                return "%"
                                        }
                                    }, set: { value in
                                        var grad = current.asLinearGradient()!
                                        var before = grad.stops[i]

                                        switch value {
                                            case "%":
                                                before.percentage = .percentage(0)
                                            case "px":
                                                before.percentage = .length(.init(amount: 0, type: .px))
                                            default:
                                                ()
                                        }
                                        
                                        grad.stops[i] = before
                                        current = .linear_gradiant(grad)
                                    })) {
                                        Text("%").tag("%")
                                        Text("px").tag("px")
                                    }
                                    .pickerStyle(.menu)
                                    
                                    Button {
                                        var grad = current.asLinearGradient()!
                                        grad.stops.remove(at: i)
                                        current = .linear_gradiant(grad)
                                    } label: {
                                        Image(systemName: "xmark")
                                            .foregroundStyle(viewState.theme.error)
                                    }
                                }
                            }
                        }
                    case .simple(let colorType):
                        ColorPicker("Select Colour", selection: Binding(get: {
                            resolveColor(color: colorType)
                        }, set: { value in
                            current = .simple(convertSwiftUIColor(color: value))
                        }))
                    case .variable(let string):
                        TextField("Colour", text: Binding(get: {
                            string
                        }, set: { value in
                            current = .variable(value)
                        }))
                }
                
                Button("Reset") {
                    current = initial
                    
                    switch current {
                        case .linear_gradiant:
                            pickerSelection = .linear
                        case .simple:
                            pickerSelection = .simple
                        case .variable:
                            pickerSelection = .variable
                    }
                }
                .padding(8)
                .foregroundStyle(viewState.theme.accent)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 8).foregroundStyle(viewState.theme.background2))
            }
            .padding(16)
        }
        .scrollBounceBehavior(.basedOnSize, axes: [.vertical])
        .presentationDetents([.large])
        .presentationBackground(viewState.theme.background)
    }
}
