import Foundation
import CoreGraphics

/// Maps virtual keycodes (Carbon/macOS) to characters and key types.
public struct KeyCodeMap: Sendable {
    // Virtual keycodes
    public static let kVK_ANSI_A: CGKeyCode = 0x00
    public static let kVK_ANSI_S: CGKeyCode = 0x01
    public static let kVK_ANSI_D: CGKeyCode = 0x02
    public static let kVK_ANSI_F: CGKeyCode = 0x03
    public static let kVK_ANSI_H: CGKeyCode = 0x04
    public static let kVK_ANSI_G: CGKeyCode = 0x05
    public static let kVK_ANSI_Z: CGKeyCode = 0x06
    public static let kVK_ANSI_X: CGKeyCode = 0x07
    public static let kVK_ANSI_C: CGKeyCode = 0x08
    public static let kVK_ANSI_V: CGKeyCode = 0x09
    public static let kVK_ANSI_B: CGKeyCode = 0x0B
    public static let kVK_ANSI_Q: CGKeyCode = 0x0C
    public static let kVK_ANSI_W: CGKeyCode = 0x0D
    public static let kVK_ANSI_E: CGKeyCode = 0x0E
    public static let kVK_ANSI_R: CGKeyCode = 0x0F
    public static let kVK_ANSI_Y: CGKeyCode = 0x10
    public static let kVK_ANSI_T: CGKeyCode = 0x11
    public static let kVK_ANSI_1: CGKeyCode = 0x12
    public static let kVK_ANSI_2: CGKeyCode = 0x13
    public static let kVK_ANSI_3: CGKeyCode = 0x14
    public static let kVK_ANSI_4: CGKeyCode = 0x15
    public static let kVK_ANSI_6: CGKeyCode = 0x16
    public static let kVK_ANSI_5: CGKeyCode = 0x17
    public static let kVK_ANSI_Equal: CGKeyCode = 0x18
    public static let kVK_ANSI_9: CGKeyCode = 0x19
    public static let kVK_ANSI_7: CGKeyCode = 0x1A
    public static let kVK_ANSI_Minus: CGKeyCode = 0x1B
    public static let kVK_ANSI_8: CGKeyCode = 0x1C
    public static let kVK_ANSI_0: CGKeyCode = 0x1D
    public static let kVK_ANSI_RightBracket: CGKeyCode = 0x1E
    public static let kVK_ANSI_O: CGKeyCode = 0x1F
    public static let kVK_ANSI_U: CGKeyCode = 0x20
    public static let kVK_ANSI_LeftBracket: CGKeyCode = 0x21
    public static let kVK_ANSI_I: CGKeyCode = 0x22
    public static let kVK_ANSI_P: CGKeyCode = 0x23
    public static let kVK_ANSI_L: CGKeyCode = 0x25
    public static let kVK_ANSI_J: CGKeyCode = 0x26
    public static let kVK_ANSI_Quote: CGKeyCode = 0x27
    public static let kVK_ANSI_K: CGKeyCode = 0x28
    public static let kVK_ANSI_Semicolon: CGKeyCode = 0x29
    public static let kVK_ANSI_Backslash: CGKeyCode = 0x2A
    public static let kVK_ANSI_Comma: CGKeyCode = 0x2B
    public static let kVK_ANSI_Slash: CGKeyCode = 0x2C
    public static let kVK_ANSI_N: CGKeyCode = 0x2D
    public static let kVK_ANSI_M: CGKeyCode = 0x2E
    public static let kVK_ANSI_Period: CGKeyCode = 0x2F

    public static let kVK_Return: CGKeyCode = 0x24
    public static let kVK_Tab: CGKeyCode = 0x30
    public static let kVK_Space: CGKeyCode = 0x31
    public static let kVK_ANSI_Grave: CGKeyCode = 0x32
    public static let kVK_Delete: CGKeyCode = 0x33 // Backspace
    public static let kVK_Escape: CGKeyCode = 0x35
    public static let kVK_Command: CGKeyCode = 0x37
    public static let kVK_Shift: CGKeyCode = 0x38
    public static let kVK_Option: CGKeyCode = 0x3A
    public static let kVK_Control: CGKeyCode = 0x3B
    public static let kVK_Function: CGKeyCode = 0x3F

    private static let keycodeToChar: [CGKeyCode: (lower: Character, upper: Character)] = [
        kVK_ANSI_A: ("a", "A"),
        kVK_ANSI_B: ("b", "B"),
        kVK_ANSI_C: ("c", "C"),
        kVK_ANSI_D: ("d", "D"),
        kVK_ANSI_E: ("e", "E"),
        kVK_ANSI_F: ("f", "F"),
        kVK_ANSI_G: ("g", "G"),
        kVK_ANSI_H: ("h", "H"),
        kVK_ANSI_I: ("i", "I"),
        kVK_ANSI_J: ("j", "J"),
        kVK_ANSI_K: ("k", "K"),
        kVK_ANSI_L: ("l", "L"),
        kVK_ANSI_M: ("m", "M"),
        kVK_ANSI_N: ("n", "N"),
        kVK_ANSI_O: ("o", "O"),
        kVK_ANSI_P: ("p", "P"),
        kVK_ANSI_Q: ("q", "Q"),
        kVK_ANSI_R: ("r", "R"),
        kVK_ANSI_S: ("s", "S"),
        kVK_ANSI_T: ("t", "T"),
        kVK_ANSI_U: ("u", "U"),
        kVK_ANSI_V: ("v", "V"),
        kVK_ANSI_W: ("w", "W"),
        kVK_ANSI_X: ("x", "X"),
        kVK_ANSI_Y: ("y", "Y"),
        kVK_ANSI_Z: ("z", "Z"),
        kVK_ANSI_1: ("1", "!"),
        kVK_ANSI_2: ("2", "@"),
        kVK_ANSI_3: ("3", "#"),
        kVK_ANSI_4: ("4", "$"),
        kVK_ANSI_5: ("5", "%"),
        kVK_ANSI_6: ("6", "^"),
        kVK_ANSI_7: ("7", "&"),
        kVK_ANSI_8: ("8", "*"),
        kVK_ANSI_9: ("9", "("),
        kVK_ANSI_0: ("0", ")"),
        kVK_Space: (" ", " "),
        kVK_ANSI_Grave: ("`", "~"),
        kVK_ANSI_Minus: ("-", "_"),
        kVK_ANSI_Equal: ("=", "+"),
        kVK_ANSI_LeftBracket: ("[", "{"),
        kVK_ANSI_RightBracket: ("]", "}"),
        kVK_ANSI_Backslash: ("\\", "|"),
        kVK_ANSI_Semicolon: (";", ":"),
        kVK_ANSI_Quote: ("'", "\""),
        kVK_ANSI_Comma: (",", "<"),
        kVK_ANSI_Period: (".", ">"),
        kVK_ANSI_Slash: ("/", "?")
    ]

    /// Translates a keycode and shift modifier state into a Character.
    public static func character(for keycode: CGKeyCode, shift: Bool) -> Character? {
        guard let pair = keycodeToChar[keycode] else { return nil }
        return shift ? pair.upper : pair.lower
    }
}
